from fastapi import APIRouter, Depends, HTTPException, status

from app.agents import tools as T
from app.db.supabase import get_service_client
from app.deps import CurrentUser, get_current_user
from app.schemas.booking import BookingDetailOut, BookingOut, ProviderOut
from app.scheduler.runtime import cancel_reminder

router = APIRouter(prefix="/bookings", tags=["bookings"])


def _to_booking_out(row: dict) -> BookingOut:
    p = row.get("providers") or {}
    return BookingOut(
        id=row["id"],
        status=row["status"],
        service_type=row["service_type"],
        location_text=row["location_text"],
        scheduled_at=row["scheduled_at"],
        created_at=row["created_at"],
        agent_trace_id=row.get("agent_trace_id"),
        provider=ProviderOut(
            id=p.get("id", row["provider_id"]),
            name=p.get("name", ""),
            category=p.get("category", row["service_type"]),
            area=p.get("area"),
            address=p.get("address"),
            phone=p.get("phone"),
            rating=p.get("rating"),
        ),
    )


@router.get("", response_model=list[BookingOut])
def list_bookings(user: CurrentUser = Depends(get_current_user)) -> list[BookingOut]:
    svc = get_service_client()
    res = (
        svc.table("bookings")
        .select(
            "id, status, service_type, location_text, scheduled_at, created_at, "
            "agent_trace_id, provider_id, "
            "providers(id, name, category, area, address, phone, rating)"
        )
        .eq("user_id", user.id)
        .order("scheduled_at", desc=True)
        .execute()
    )
    return [_to_booking_out(r) for r in (res.data or [])]


@router.get("/{booking_id}", response_model=BookingDetailOut)
def get_booking(
    booking_id: str, user: CurrentUser = Depends(get_current_user)
) -> BookingDetailOut:
    svc = get_service_client()
    res = (
        svc.table("bookings")
        .select(
            "id, status, service_type, location_text, scheduled_at, created_at, "
            "agent_trace_id, provider_id, "
            "providers(id, name, category, area, address, phone, rating)"
        )
        .eq("id", booking_id)
        .eq("user_id", user.id)
        .limit(1)
        .execute()
    )
    if not res.data:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Booking not found")
    row = res.data[0]
    base = _to_booking_out(row).model_dump()

    reasoning = None
    trace_steps = None
    if row.get("agent_trace_id"):
        tr = (
            svc.table("agent_traces")
            .select("reasoning, steps")
            .eq("id", row["agent_trace_id"])
            .limit(1)
            .execute()
        )
        if tr.data:
            reasoning = tr.data[0].get("reasoning")
            trace_steps = tr.data[0].get("steps")

    notif = (
        svc.table("notifications")
        .select("id, kind, scheduled_at, sent_at, payload")
        .eq("booking_id", booking_id)
        .order("scheduled_at")
        .execute()
    )

    return BookingDetailOut(
        **base, reasoning=reasoning, trace_steps=trace_steps, notifications=notif.data or []
    )


@router.post("/{booking_id}/cancel", response_model=BookingOut)
def cancel(
    booking_id: str, user: CurrentUser = Depends(get_current_user)
) -> BookingOut:
    row = T.cancel_booking.invoke({"user_id": user.id, "booking_id": booking_id})
    if not row:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Booking not found")

    # Cancel any pending reminders.
    svc = get_service_client()
    pending = (
        svc.table("notifications")
        .select("id")
        .eq("booking_id", booking_id)
        .is_("sent_at", "null")
        .execute()
    )
    for n in pending.data or []:
        cancel_reminder(n["id"])

    # Re-fetch with provider join for response.
    full = (
        svc.table("bookings")
        .select(
            "id, status, service_type, location_text, scheduled_at, created_at, "
            "agent_trace_id, provider_id, "
            "providers(id, name, category, area, address, phone, rating)"
        )
        .eq("id", booking_id)
        .limit(1)
        .execute()
    )
    return _to_booking_out(full.data[0])
