"""Build & cache the LangGraph state machine.

The compiled graph is wrapped in `@lru_cache` so we pay the construction
(and `PostgresSaver.setup()`) cost exactly once per process.

Graph shape:
                 ┌────────────► clarifier ◄────────────┐
                 │                  │                  │
   START ─► intent_parser ──┬───────┴───► provider_caller ─► tool_executor
                 │          │                                     │
                 ├──► cancel_handler ─► END         (no rows)─────┤
                 ├──► reschedule_handler ─► END                   │
                 │          ▼                            no_results_handler
                 │      give_up ─► END                            │
                 │                                                ▼
                 │                                            ranking
                 │                                                │
                 ├──◄── slot_picker ◄─── (provider known, no time)
                 │                                                │
                 │                                inquiry_formatter ─► END
                 │                                                │
                 └─────────────────────► decision_and_format ─► booking_step
                                                              │       │
                                            (conflict → clarifier)    ▼
                                                              followup_step ─► END
"""
from functools import lru_cache

from langgraph.graph import END, START, StateGraph
from langgraph.prebuilt import ToolNode

from app.agents import nodes as N
from app.agents import tools as T
from app.agents.checkpointer import get_checkpointer
from app.agents.state import AgentState


def _route_after_booking(state):
    # booking_step sets status=None when it returns a conflict (question + alternatives).
    return "clarifier" if state.get("question") and not state.get("booking") else "followup_step"


@lru_cache
def build_graph():
    g = StateGraph(AgentState)

    tool_executor = ToolNode([T.find_providers])

    # ---- nodes --------------------------------------------------------------
    g.add_node("intent_parser",         N.intent_parser)
    g.add_node("provider_caller",       N.provider_caller)
    g.add_node("tool_executor",         tool_executor)
    g.add_node("no_results_handler",    N.no_results_handler)
    g.add_node("ranking",               N.ranking)
    g.add_node("slot_picker",           N.slot_picker)
    g.add_node("decision_and_format",   N.decision_and_format)
    g.add_node("booking_step",          N.booking_step)
    g.add_node("followup_step",         N.followup_step)
    g.add_node("clarifier",             N.clarifier)
    g.add_node("inquiry_formatter",     N.inquiry_formatter)
    g.add_node("cancel_handler",        N.cancel_handler)
    g.add_node("reschedule_handler",    N.reschedule_handler)
    g.add_node("give_up",               N.give_up)

    # ---- edges --------------------------------------------------------------
    g.add_edge(START, "intent_parser")

    g.add_conditional_edges(
        "intent_parser",
        N.route_after_intent,
        {
            "clarifier":           "clarifier",
            "provider_caller":     "provider_caller",
            "cancel_handler":      "cancel_handler",
            "reschedule_handler":  "reschedule_handler",
            "give_up":             "give_up",
        },
    )

    g.add_edge("provider_caller", "tool_executor")

    g.add_conditional_edges(
        "tool_executor",
        N.route_after_tool_executor,
        {"ranking": "ranking", "no_results_handler": "no_results_handler"},
    )
    g.add_edge("no_results_handler", "clarifier")

    g.add_conditional_edges(
        "clarifier",
        N.route_after_clarifier,
        {"intent_parser": "intent_parser", "give_up": "give_up"},
    )

    g.add_conditional_edges(
        "ranking",
        N.route_after_ranking,
        {
            "inquiry_formatter":   "inquiry_formatter",
            "slot_picker":         "slot_picker",
            "clarifier":           "clarifier",
            "decision_and_format": "decision_and_format",
        },
    )

    # slot_picker loops back so intent_parser re-validates with the picked slot.
    g.add_edge("slot_picker", "intent_parser")

    g.add_edge("inquiry_formatter",  END)

    g.add_edge("decision_and_format", "booking_step")
    g.add_conditional_edges(
        "booking_step",
        _route_after_booking,
        {"clarifier": "clarifier", "followup_step": "followup_step"},
    )
    g.add_edge("followup_step",   END)
    g.add_edge("cancel_handler",  END)
    g.add_edge("reschedule_handler", END)
    g.add_edge("give_up", END)

    return g.compile(checkpointer=get_checkpointer())
