from typing import Any, Literal

from pydantic import BaseModel, Field


CategoryLiteral = Literal[
    "ac_technician", "plumber", "electrician", "tutor", "beautician"
]


class ServiceRequestIn(BaseModel):
    text: str = Field(min_length=1, max_length=2000)
    conversation_id: str | None = None
    demo_offset_seconds: int | None = Field(
        default=None,
        description="If set, schedule the reminder this many seconds from now (demo only).",
    )
    idempotency_key: str | None = Field(
        default=None,
        description="Client-supplied dedupe key; replays return the original response.",
    )


class IntentParsed(BaseModel):
    intent_type: Literal["book", "inquiry", "cancel", "reschedule"] = "book"
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
    score: float | None = None
    score_breakdown: dict[str, float] | None = None


class BookingBrief(BaseModel):
    id: str
    status: str
    scheduled_at: str
    provider_id: str


class FollowupBrief(BaseModel):
    notification_id: str
    reminder_at: str


class SlotOption(BaseModel):
    label: str
    iso: str


class PriceRange(BaseModel):
    min_pkr: int
    max_pkr: int


class ThinkingStep(BaseModel):
    key: str
    title: str
    detail: str
    status: Literal["done", "waiting", "stopped"]
    ms: int | None = None


class AgentRunOut(BaseModel):
    status: Literal["completed", "needs_clarification", "abandoned"]
    conversation_id: str
    thinking_steps: list[ThinkingStep] | None = None
    # completed:
    intent: IntentParsed | None = None
    selected_provider: ProviderBrief | None = None
    reasoning: str | None = None
    formatted_message: str | None = None
    suggestions: list[str] | None = None
    booking: BookingBrief | None = None
    followup: FollowupBrief | None = None
    trace_id: str | None = None
    trace_steps: list[dict[str, Any]] | None = None
    price_range: PriceRange | None = None
    # needs_clarification:
    question: str | None = None
    partial_intent: IntentParsed | None = None
    free_slots: list[SlotOption] | None = None
    alternatives: list[ProviderBrief] | None = None
    # abandoned:
    reason: str | None = None
