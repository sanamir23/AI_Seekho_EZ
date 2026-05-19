from typing import Annotated, Any, TypedDict

from langgraph.graph.message import add_messages


class AgentState(TypedDict, total=False):
    # LangChain message thread — required by ToolNode.
    messages: Annotated[list, add_messages]

    # Inputs
    user_id: str
    conversation_id: str
    input_text: str
    demo_offset_seconds: int | None
    idempotency_key: str | None

    # Intent slot-filling
    intent: dict[str, Any] | None
    clarification_context: list[str]
    clarify_rounds: int

    # Provider pipeline
    ranked: list[dict]
    selected: dict | None
    reasoning: str | None

    # Slot picker
    free_slots: list[dict] | None      # [{"label": "Tomorrow 09:00", "iso": "..."}]
    held_booking: dict | None          # row from hold_slot
    alternatives: list[dict] | None    # alt providers when slot is taken

    # Pricing
    price_range: dict | None           # {"min_pkr": int, "max_pkr": int}

    # User profile
    user_profile: dict | None

    # Response formatting
    formatted_response: str | None
    suggestions: list[str] | None

    # Outputs
    booking: dict | None
    followup: dict | None
    trace_id: str | None

    # Audit
    trace_steps: list[dict[str, Any]]

    # Routing / terminal signalling
    status: str  # "completed" | "needs_clarification" | "abandoned"
    question: str | None
    reason: str | None
