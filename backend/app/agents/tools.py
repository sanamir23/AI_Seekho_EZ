"""Agent tools.

Each tool is a `langchain_core.tools.@tool`-decorated function. That gives us:
  * A normalized JSON-schema'd signature (good for future ReAct branches).
  * A uniform call interface from nodes: `tool_name.invoke({"arg": value, ...})`.
  * A `.name`, `.description`, `.args_schema` triple so we could bind these to
    a chat model later (`llm.bind_tools([...])`) without changing the bodies.

Nodes call tools through `.invoke({...})` rather than importing the raw
function. The scheduler is allowed to call the raw underlying helpers directly
because it's not part of the agent graph.

Layout:
  1. Provider lookup + ranking helpers.
  2. Slot picker + soft holds.
  3. Conversation / trace / booking writes.
  4. Notification + reminder ops (used by followup node + scheduler).
  5. Waitlist + user_profile + price-range helpers.
"""
from __future__ import annotations

from datetime import date, datetime, timedelta, timezone
from typing import Any

from langchain_core.tools import tool

from app.agents.geo import haversine, sector_centroid
from app.db.supabase import get_service_client

# Day index → 3-letter key used in `providers.available_hours`.
_DAY_KEYS = ["mon", "tue", "wed", "thu", "fri", "sat", "sun"]

# Statuses that block a slot from being booked by someone else.
_BLOCKING_STATUSES = ["confirmed", "pending", "held"]

# How long a soft hold is valid before it auto-expires.
HOLD_TTL_MINUTES = 2


def _now_utc() -> datetime:
    return datetime.now(timezone.utc)


def _iso(dt: datetime) -> str:
    return dt.isoformat()


def _booked_provider_ids_in_window(
    svc, start: datetime, end: datetime
) -> set[str]:
    """Provider ids that are currently busy in [start, end), held holds expired."""
    now_iso = _iso(_now_utc())
    # confirmed/pending — always block.
    busy = (
        svc.table("bookings")
        .select("provider_id, status, held_until")
        .in_("status", _BLOCKING_STATUSES)
        .gte("scheduled_at", _iso(start))
        .lt("scheduled_at", _iso(end))
        .execute()
    ).data or []
    out: set[str] = set()
    for r in busy:
        if r["status"] == "held":
            hu = r.get("held_until")
            if not hu or hu < now_iso:
                continue  # expired hold, treat slot as free
        out.add(r["provider_id"])
    return out


def is_provider_open_at(provider: dict, scheduled_iso: str | None) -> bool:
    """True when the provider's available_hours covers the requested slot."""
    if not scheduled_iso:
        return True
    try:
        dt = datetime.fromisoformat(scheduled_iso.replace("Z", "+00:00"))
    except ValueError:
        return False
    hours = (provider.get("available_hours") or {}).get(_DAY_KEYS[dt.weekday()])
    if not hours:
        return False
    hhmm = dt.strftime("%H:%M")
    for window in hours:
        try:
            start, end = window.split("-")
        except ValueError:
            continue
        if start <= hhmm < end:
            return True
    return False


# ---------------------------------------------------------------------------
# 1. Provider lookup + ranking
# ---------------------------------------------------------------------------
@tool
def find_providers(
    category: str,
    area: str | None = None,
    scheduled_at: str | None = None,
    limit: int = 10,
) -> list[dict]:
    """Look up providers by category, optionally filtered by sector and time slot.

    When scheduled_at is given, providers already booked / on a live hold within
    that 60-minute window are filtered out before returning results. Returns
    [] if no providers are found — the clarifier suggests alternatives.
    """
    import logging
    logger = logging.getLogger("agent")
    logger.info(
        "find_providers category=%s area=%s scheduled_at=%s",
        category, area, scheduled_at,
    )

    svc = get_service_client()
    q = svc.table("providers").select("*").eq("category", category)
    if area:
        q = q.ilike("area", f"%{area}%")
    rows = (q.limit(limit * 3).execute()).data or []

    if scheduled_at and rows:
        rows = [r for r in rows if is_provider_open_at(r, scheduled_at)]
        try:
            dt = datetime.fromisoformat(scheduled_at.replace("Z", "+00:00"))
            window_end = dt + timedelta(hours=1)
            booked_ids = _booked_provider_ids_in_window(svc, dt, window_end)
            if booked_ids:
                logger.info("Filtering %d busy providers", len(booked_ids))
                rows = [r for r in rows if r["id"] not in booked_ids]
        except Exception as e:
            logger.warning("Conflict pre-filter failed: %s", e)

    rows = rows[:limit]
    logger.info("find_providers → %d rows", len(rows))
    return rows


@tool
def find_available_areas(category: str) -> list[str]:
    """Distinct areas where providers of a category exist. Used by the clarifier
    to suggest REAL areas to the user instead of guessing."""
    svc = get_service_client()
    rows = (
        svc.table("providers")
        .select("area")
        .eq("category", category)
        .execute()
    ).data or []
    return sorted({r["area"] for r in rows if r.get("area")})


def _availability_score(provider: dict, scheduled_iso: str | None) -> float:
    """1.0 if open at the requested slot, else 0.3. Plain helper (not a @tool)."""
    if not scheduled_iso:
        return 0.7
    if not is_provider_open_at(provider, scheduled_iso):
        return 0.3
    return 1.0


@tool
def rank_providers(
    candidates: list[dict],
    area: str | None,
    scheduled_at: str | None,
) -> list[dict]:
    """Rank candidates by 0.5*distance + 0.3*rating + 0.2*availability.

    Returns rows augmented with `distance_km`, `availability_score`, `score`,
    and a `score_breakdown` so the UI can explain "why this provider".
    """
    lat0, lng0 = sector_centroid(area)
    ranked: list[dict] = []
    for p in candidates:
        km = haversine(lat0, lng0, p["lat"], p["lng"])
        dist_score = max(0.0, 1 - km / 5.0)
        rate_score = (p.get("rating") or 3.5) / 5.0
        avail_score = _availability_score(p, scheduled_at)
        score = 0.5 * dist_score + 0.3 * rate_score + 0.2 * avail_score
        ranked.append(
            {
                **p,
                "distance_km": round(km, 2),
                "availability_score": avail_score,
                "score": round(score, 4),
                "score_breakdown": {
                    "distance": round(dist_score, 3),
                    "rating": round(rate_score, 3),
                    "availability": round(avail_score, 3),
                },
            }
        )
    ranked.sort(key=lambda r: r["score"], reverse=True)
    return ranked


# ---------------------------------------------------------------------------
# 2. Slot picker + soft holds
# ---------------------------------------------------------------------------
def _expand_hours_to_slots(hours: list[str], granularity_min: int) -> list[str]:
    """`["09:00-13:00"]`, 60 → `["09:00", "10:00", "11:00", "12:00"]`."""
    out: list[str] = []
    for window in hours or []:
        try:
            s, e = window.split("-")
            sh, sm = (int(x) for x in s.split(":"))
            eh, em = (int(x) for x in e.split(":"))
        except ValueError:
            continue
        cur = sh * 60 + sm
        end = eh * 60 + em
        while cur + granularity_min <= end:
            out.append(f"{cur // 60:02d}:{cur % 60:02d}")
            cur += granularity_min
    return out


@tool
def get_provider_free_slots(
    provider_id: str,
    target_date: str | None = None,
    granularity_min: int = 60,
    limit: int = 8,
) -> list[dict]:
    """Return free start-times for a provider on `target_date` (defaults: tomorrow).

    A slot is free if it falls inside `available_hours[<weekday>]` AND no
    confirmed/pending/held booking exists at that timestamp. Returned shape:
      [{"label": "Tomorrow 09:00", "iso": "2026-05-19T09:00:00+05:00"}, ...]
    """
    svc = get_service_client()
    prov = (
        svc.table("providers").select("*").eq("id", provider_id).limit(1).execute()
    ).data
    if not prov:
        return []
    p = prov[0]

    # Default to tomorrow in PKT.
    pkt = timezone(timedelta(hours=5))
    if target_date:
        try:
            d = date.fromisoformat(target_date)
        except ValueError:
            d = (datetime.now(pkt) + timedelta(days=1)).date()
    else:
        d = (datetime.now(pkt) + timedelta(days=1)).date()

    day_key = _DAY_KEYS[d.weekday()]
    hours = (p.get("available_hours") or {}).get(day_key) or []
    times = _expand_hours_to_slots(hours, granularity_min)
    if not times:
        return []

    # Pull all blocking bookings for that day in one query.
    day_start = datetime(d.year, d.month, d.day, tzinfo=pkt)
    day_end = day_start + timedelta(days=1)
    now_iso = _iso(_now_utc())
    rows = (
        svc.table("bookings")
        .select("scheduled_at, status, held_until")
        .eq("provider_id", provider_id)
        .in_("status", _BLOCKING_STATUSES)
        .gte("scheduled_at", _iso(day_start))
        .lt("scheduled_at", _iso(day_end))
        .execute()
    ).data or []

    busy: set[str] = set()
    for r in rows:
        if r["status"] == "held":
            hu = r.get("held_until")
            if not hu or hu < now_iso:
                continue
        # Normalize to HH:MM in PKT for comparison.
        try:
            ts = datetime.fromisoformat(r["scheduled_at"].replace("Z", "+00:00"))
            busy.add(ts.astimezone(pkt).strftime("%H:%M"))
        except Exception:
            pass

    out: list[dict] = []
    for hhmm in times:
        if hhmm in busy:
            continue
        h, m = (int(x) for x in hhmm.split(":"))
        iso = datetime(d.year, d.month, d.day, h, m, tzinfo=pkt).isoformat()
        rel = "Tomorrow" if d == (datetime.now(pkt).date() + timedelta(days=1)) else d.strftime("%a %d %b")
        out.append({"label": f"{rel} {hhmm}", "iso": iso})
        if len(out) >= limit:
            break
    return out


@tool
def hold_slot(
    user_id: str,
    provider_id: str,
    service_type: str,
    scheduled_at: str,
    location_text: str = "",
) -> dict | None:
    """Create a 'held' booking row that expires in HOLD_TTL_MINUTES.

    Returns the held row, or None if the slot was already taken.
    """
    svc = get_service_client()
    expire_old_holds()  # opportunistic cleanup
    held_until = _iso(_now_utc() + timedelta(minutes=HOLD_TTL_MINUTES))
    try:
        res = (
            svc.table("bookings")
            .insert(
                {
                    "user_id": user_id,
                    "provider_id": provider_id,
                    "service_type": service_type,
                    "location_text": location_text or "",
                    "scheduled_at": scheduled_at,
                    "status": "held",
                    "held_until": held_until,
                }
            )
            .execute()
        )
        return res.data[0] if res.data else None
    except Exception as exc:
        msg = str(exc)
        if "23505" in msg or "bookings_provider_unique_slot" in msg:
            return None
        raise


@tool
def confirm_held_booking(booking_id: str, agent_trace_id: str | None) -> dict | None:
    """Promote a 'held' row to 'confirmed'. Returns the updated row or None."""
    svc = get_service_client()
    res = (
        svc.table("bookings")
        .update({"status": "confirmed", "held_until": None, "agent_trace_id": agent_trace_id})
        .eq("id", booking_id)
        .execute()
    )
    return res.data[0] if res.data else None


def expire_old_holds() -> int:
    """Delete 'held' rows whose held_until has passed. Returns count."""
    svc = get_service_client()
    now_iso = _iso(_now_utc())
    res = (
        svc.table("bookings")
        .delete()
        .eq("status", "held")
        .lt("held_until", now_iso)
        .execute()
    )
    return len(res.data or [])


# ---------------------------------------------------------------------------
# 3. Conversation / trace / booking writes
# ---------------------------------------------------------------------------
@tool
def upsert_conversation(
    conversation_id: str,
    user_id: str,
    status: str,
    last_question: str | None = None,
) -> None:
    """Update (or insert) the app-facing conversation row."""
    get_service_client().table("conversations").upsert(
        {
            "id": conversation_id,
            "user_id": user_id,
            "status": status,
            "last_question": last_question,
            "updated_at": _iso(_now_utc()),
        },
        on_conflict="id",
    ).execute()


@tool
def insert_agent_trace(
    user_id: str,
    conversation_id: str | None,
    input_text: str,
    parsed_intent: dict | None,
    candidate_providers: list[dict] | None,
    selected_provider_id: str | None,
    reasoning: str | None,
    steps: list[dict],
    idempotency_key: str | None = None,
) -> str:
    """Persist the full agent trace. Returns the trace id."""
    res = (
        get_service_client()
        .table("agent_traces")
        .insert(
            {
                "user_id": user_id,
                "conversation_id": conversation_id,
                "input_text": input_text,
                "parsed_intent": parsed_intent,
                "candidate_providers": candidate_providers,
                "selected_provider_id": selected_provider_id,
                "reasoning": reasoning,
                "steps": steps,
                "idempotency_key": idempotency_key,
            }
        )
        .execute()
    )
    return res.data[0]["id"]


def find_trace_by_idempotency(user_id: str, idempotency_key: str) -> dict | None:
    """Look up a previous trace for the same idempotency key (response replay)."""
    svc = get_service_client()
    res = (
        svc.table("agent_traces")
        .select("*")
        .eq("user_id", user_id)
        .eq("idempotency_key", idempotency_key)
        .limit(1)
        .execute()
    )
    return res.data[0] if res.data else None


class BookingConflictError(Exception):
    """Raised when the provider is already booked in the requested time window."""


@tool
def insert_booking(
    user_id: str,
    provider_id: str,
    service_type: str,
    location_text: str,
    scheduled_at: str,
    agent_trace_id: str | None,
) -> dict:
    """Create the simulated booking. Status starts at 'confirmed'."""
    try:
        res = (
            get_service_client()
            .table("bookings")
            .insert(
                {
                    "user_id": user_id,
                    "provider_id": provider_id,
                    "service_type": service_type,
                    "location_text": location_text,
                    "scheduled_at": scheduled_at,
                    "status": "confirmed",
                    "agent_trace_id": agent_trace_id,
                }
            )
            .execute()
        )
        return res.data[0]
    except Exception as exc:
        msg = str(exc)
        if "23505" in msg or "bookings_provider_unique_slot" in msg:
            raise BookingConflictError("Provider already booked at that time.") from exc
        raise


@tool
def cancel_booking(user_id: str, booking_id: str) -> dict | None:
    """Soft-cancel a booking owned by the user. Returns the updated row or None."""
    res = (
        get_service_client()
        .table("bookings")
        .update({"status": "cancelled"})
        .eq("id", booking_id)
        .eq("user_id", user_id)
        .execute()
    )
    return res.data[0] if res.data else None


@tool
def find_user_bookings(
    user_id: str,
    service_type: str | None = None,
    upcoming_only: bool = True,
    limit: int = 5,
) -> list[dict]:
    """Look up a user's bookings — used by NL cancel / reschedule flows."""
    svc = get_service_client()
    q = svc.table("bookings").select("*, providers(name, area)").eq("user_id", user_id)
    if service_type:
        q = q.eq("service_type", service_type)
    if upcoming_only:
        q = q.gte("scheduled_at", _iso(_now_utc())).eq("status", "confirmed")
    q = q.order("scheduled_at").limit(limit)
    return (q.execute()).data or []


@tool
def reschedule_booking(
    user_id: str, booking_id: str, new_scheduled_at: str
) -> dict | None:
    """Move a booking to a new time. Caller must verify slot is free first."""
    svc = get_service_client()
    res = (
        svc.table("bookings")
        .update({"scheduled_at": new_scheduled_at})
        .eq("id", booking_id)
        .eq("user_id", user_id)
        .execute()
    )
    return res.data[0] if res.data else None


# ---------------------------------------------------------------------------
# 4. Notifications / reminders
# ---------------------------------------------------------------------------
@tool
def insert_notification(
    booking_id: str,
    kind: str,
    scheduled_at: str,
    payload: dict[str, Any],
) -> dict:
    """Insert a pending notification (sent_at = null). The scheduler fires it later."""
    res = (
        get_service_client()
        .table("notifications")
        .insert(
            {
                "booking_id": booking_id,
                "kind": kind,
                "scheduled_at": scheduled_at,
                "payload": payload,
            }
        )
        .execute()
    )
    return res.data[0]


# Plain helpers (no @tool) — called from the scheduler.
def mark_notification_sent(notification_id: str) -> None:
    get_service_client().table("notifications").update(
        {"sent_at": _iso(_now_utc())}
    ).eq("id", notification_id).execute()


def list_due_notifications() -> list[dict]:
    res = (
        get_service_client()
        .table("notifications")
        .select("*")
        .is_("sent_at", "null")
        .gt("scheduled_at", _iso(_now_utc()))
        .execute()
    )
    return res.data or []


# ---------------------------------------------------------------------------
# 5. Waitlist, user_profile, price ranges
# ---------------------------------------------------------------------------
@tool
def add_to_waitlist(
    user_id: str, category: str, area: str, note: str | None = None
) -> dict:
    """Record demand when no providers serve the requested area."""
    res = (
        get_service_client()
        .table("waitlist")
        .insert(
            {"user_id": user_id, "category": category, "area": area, "note": note}
        )
        .execute()
    )
    return res.data[0]


@tool
def get_user_profile(user_id: str) -> dict | None:
    """Return the user_profile row or None."""
    svc = get_service_client()
    res = (
        svc.table("user_profile").select("*").eq("user_id", user_id).limit(1).execute()
    )
    return res.data[0] if res.data else None


@tool
def upsert_user_profile(
    user_id: str,
    preferred_area: str | None = None,
    preferred_time: str | None = None,
    last_category: str | None = None,
    increment_count: bool = False,
) -> None:
    """Update personalisation hints after a successful booking."""
    svc = get_service_client()
    existing = (
        svc.table("user_profile").select("*").eq("user_id", user_id).limit(1).execute()
    ).data
    base = existing[0] if existing else {"bookings_count": 0}
    payload = {
        "user_id": user_id,
        "preferred_area": preferred_area or base.get("preferred_area"),
        "preferred_time": preferred_time or base.get("preferred_time"),
        "last_category": last_category or base.get("last_category"),
        "bookings_count": (base.get("bookings_count") or 0) + (1 if increment_count else 0),
        "updated_at": _iso(_now_utc()),
    }
    svc.table("user_profile").upsert(payload, on_conflict="user_id").execute()


@tool
def get_price_range(category: str) -> dict | None:
    """Return {'min_pkr': int, 'max_pkr': int} for the category, or None."""
    svc = get_service_client()
    res = (
        svc.table("price_ranges").select("*").eq("category", category).limit(1).execute()
    )
    return res.data[0] if res.data else None
