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
  2. Conversation / trace / booking writes.
  3. Notification + reminder ops (used by followup node + scheduler).
"""
from __future__ import annotations

from datetime import datetime, timezone
from typing import Any

from langchain_core.tools import tool

from app.agents.geo import haversine, sector_centroid
from app.db.supabase import get_service_client

# Day index → 3-letter key used in `providers.available_hours`.
_DAY_KEYS = ["mon", "tue", "wed", "thu", "fri", "sat", "sun"]


# ---------------------------------------------------------------------------
# 1. Provider lookup + ranking
# ---------------------------------------------------------------------------
@tool
def find_providers(category: str, area: str | None = None, limit: int = 10) -> list[dict]:
    """Look up service providers by category, optionally filtered by sector.

    If no providers are found in the sector, it returns empty. The clarifier
    will then automatically intercept and suggest alternative available areas.
    """
    import logging
    logger = logging.getLogger("agent")
    logger.info("Executing find_providers with category=%s, area=%s", category, area)
    
    svc = get_service_client()
    q = svc.table("providers").select("*").eq("category", category)
    if area:
        # Wrap area in % for partial matching just in case (e.g. "G-13/1")
        q = q.ilike("area", f"%{area}%")
    rows = (q.limit(limit).execute()).data or []
    
    logger.info("find_providers returned %d rows", len(rows))
    return rows


@tool
def find_available_areas(category: str) -> list[str]:
    """Return distinct areas where providers of a given category exist in the DB.

    Used by the clarifier to suggest REAL areas to the user instead of guessing.
    Example: find_available_areas("ac_technician") → ["G-12", "F-10", "I-8"]
    """
    svc = get_service_client()
    rows = (
        svc.table("providers")
        .select("area")
        .eq("category", category)
        .execute()
    ).data or []
    # Deduplicate and sort.
    areas = sorted({r["area"] for r in rows if r.get("area")})
    return areas


def _availability_score(provider: dict, scheduled_iso: str | None) -> float:
    """Return 1.0 if the provider is open at the requested slot, else 0.3.

    Implemented as a plain helper (not a @tool) because it's pure CPU and we
    call it inside a tight ranking loop — avoiding the LangChain dispatch
    overhead per candidate matters.
    """
    if not scheduled_iso:
        return 0.7
    try:
        dt = datetime.fromisoformat(scheduled_iso.replace("Z", "+00:00"))
    except ValueError:
        return 0.5
    hours = (provider.get("available_hours") or {}).get(_DAY_KEYS[dt.weekday()])
    if not hours:
        return 0.3
    hhmm = dt.strftime("%H:%M")
    for window in hours:
        try:
            start, end = window.split("-")
        except ValueError:
            continue
        if start <= hhmm <= end:
            return 1.0
    return 0.3


@tool
def rank_providers(
    candidates: list[dict],
    area: str | None,
    scheduled_at: str | None,
) -> list[dict]:
    """Rank candidates by 0.5*distance + 0.3*rating + 0.2*availability.

    Returns a new list, sorted descending by score. Each row is augmented with
    `distance_km`, `availability_score`, and `score` for trace visibility.
    """
    lat0, lng0 = sector_centroid(area)
    ranked: list[dict] = []
    for p in candidates:
        km = haversine(lat0, lng0, p["lat"], p["lng"])
        dist_score = max(0.0, 1 - km / 5.0)            # decays to 0 at 5 km
        rate_score = (p.get("rating") or 3.5) / 5.0    # default mid-rating
        avail_score = _availability_score(p, scheduled_at)
        score = 0.5 * dist_score + 0.3 * rate_score + 0.2 * avail_score
        ranked.append(
            {
                **p,
                "distance_km": round(km, 2),
                "availability_score": avail_score,
                "score": round(score, 4),
            }
        )
    ranked.sort(key=lambda r: r["score"], reverse=True)
    return ranked


# ---------------------------------------------------------------------------
# 2. Conversation / trace / booking writes
# ---------------------------------------------------------------------------
@tool
def upsert_conversation(
    conversation_id: str,
    user_id: str,
    status: str,
    last_question: str | None = None,
) -> None:
    """Update (or insert) the app-facing conversation row.

    Separate from LangGraph's checkpointer state — that one holds the binary
    graph state; this row is the human-readable projection for the UI.
    """
    get_service_client().table("conversations").upsert(
        {
            "id": conversation_id,
            "user_id": user_id,
            "status": status,
            "last_question": last_question,
            "updated_at": datetime.now(timezone.utc).isoformat(),
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
            }
        )
        .execute()
    )
    return res.data[0]["id"]


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


# ---------------------------------------------------------------------------
# 3. Notifications / reminders
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


# ----- Plain helpers (no @tool) — called from the scheduler, not from nodes.
# These don't need the LangChain Tool wrapper because they're not part of the
# agent's tool surface.
def mark_notification_sent(notification_id: str) -> None:
    get_service_client().table("notifications").update(
        {"sent_at": datetime.now(timezone.utc).isoformat()}
    ).eq("id", notification_id).execute()


def list_due_notifications() -> list[dict]:
    res = (
        get_service_client()
        .table("notifications")
        .select("*")
        .is_("sent_at", "null")
        .gt("scheduled_at", datetime.now(timezone.utc).isoformat())
        .execute()
    )
    return res.data or []
