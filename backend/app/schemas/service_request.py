from typing import Any, Literal

from pydantic import BaseModel, Field


CategoryLiteral = Literal[
    "ac_technician", "plumber", "electrician", "tutor", "beautician"
]


class ServiceRequestIn(BaseModel):
    text: str = Field(min_length=1)
    conversation_id: str | None = None
    demo_offset_seconds: int | None = Field(
        default=None,
        description="If set, schedule the reminder this many seconds from now (demo only).",
    )


class IntentParsed(BaseModel):
    intent_type: Literal["book", "inquiry"] = "book"
    service_type: CategoryLiteral | None = None
    area: str | None = None
    scheduled_at: str | None = None
    selected_provider: str | None = None
    confidence: float = 0.0
    language: str | None = None


class ProviderBrief(BaseModel):
    id: str
    name: str
    category: str
    area: str | None
    rating: float | None = None
    distance_km: float | None = None


class BookingBrief(BaseModel):
    id: str
    status: str
    scheduled_at: str
    provider_id: str


class FollowupBrief(BaseModel):
    notification_id: str
    reminder_at: str


class AgentRunOut(BaseModel):
    status: Literal["completed", "needs_clarification", "abandoned"]
    conversation_id: str
    # completed:
    intent: IntentParsed | None = None
    selected_provider: ProviderBrief | None = None
    reasoning: str | None = None
    formatted_message: str | None = None         # NEW: polished user-facing text
    suggestions: list[str] | None = None          # NEW: follow-up action chips
    booking: BookingBrief | None = None
    followup: FollowupBrief | None = None
    trace_id: str | None = None
    trace_steps: list[dict[str, Any]] | None = None
    # needs_clarification:
    question: str | None = None
    partial_intent: IntentParsed | None = None
    # abandoned:
    reason: str | None = None
