from typing import Annotated, Any, TypedDict

from langgraph.graph.message import add_messages


class AgentState(TypedDict, total=False):
    # LangChain message thread — required by ToolNode.
    # `add_messages` is a LangGraph reducer that appends new messages rather
    # than overwriting the list, so both the AIMessage (tool calls) and the
    # ToolMessage (results) accumulate correctly across nodes.
    messages: Annotated[list, add_messages]

    # Inputs
    user_id: str
    conversation_id: str
    input_text: str
    demo_offset_seconds: int | None

    # Intent slot-filling
    intent: dict[str, Any] | None
    clarification_context: list[str]  # accumulated user replies
    clarify_rounds: int

    # Provider pipeline
    # Note: raw candidates are not stored here — they live in state.messages as
    # a ToolMessage written by ToolNode after find_providers executes.
    ranked: list[dict]
    selected: dict | None
    reasoning: str | None

    # Response formatting (NEW)
    formatted_response: str | None       # concise user-facing message
    suggestions: list[str] | None        # follow-up action chips

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
