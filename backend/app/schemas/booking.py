from typing import Any

from pydantic import BaseModel


class ProviderOut(BaseModel):
    id: str
    name: str
    category: str
    area: str | None
    address: str | None
    phone: str | None
    rating: float | None


class BookingOut(BaseModel):
    id: str
    status: str
    service_type: str
    location_text: str
    scheduled_at: str
    created_at: str
    provider: ProviderOut
    agent_trace_id: str | None = None


class BookingDetailOut(BookingOut):
    reasoning: str | None = None
    trace_steps: list[dict[str, Any]] | None = None
    notifications: list[dict[str, Any]] | None = None
