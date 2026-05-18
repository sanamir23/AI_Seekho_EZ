"""Build & cache the LangGraph state machine.

The compiled graph is wrapped in `@lru_cache` so we pay the construction
(and `PostgresSaver.setup()`) cost exactly once per process.

Tool-calling pattern
--------------------
provider_caller uses `llm.bind_tools([find_providers])` so the LLM emits a
structured tool call rather than free-form text.  The built-in `ToolNode`
from `langgraph.prebuilt` sits right after it: it reads the tool_calls from
the last AIMessage in state.messages, executes find_providers, and appends
the results as a ToolMessage.  route_after_tool_executor then reads that
ToolMessage to decide whether we have candidates (→ ranking) or not (→ clarifier).

Important LangGraph constraint: node names MUST NOT collide with AgentState
keys.  That's why `booking` / `followup` nodes are named `booking_step` /
`followup_step` here.
"""
from functools import lru_cache

from langgraph.graph import END, START, StateGraph
from langgraph.prebuilt import ToolNode

from app.agents import nodes as N
from app.agents import tools as T
from app.agents.checkpointer import get_checkpointer
from app.agents.state import AgentState


@lru_cache
def build_graph():
    g = StateGraph(AgentState)

    # ---- Tool executor (built-in ToolNode) ----------------------------------
    # ToolNode inspects the last AIMessage in state.messages, finds tool_calls,
    # looks up the matching @tool function from the list below, calls it, and
    # appends a ToolMessage with the serialised result back to state.messages.
    # No custom code needed — this is the "tool execution node which is builtin
    # in langgraph" the user requested.
    tool_executor = ToolNode([T.find_providers])

    # ---- nodes --------------------------------------------------------------
    g.add_node("intent_parser",       N.intent_parser)
    g.add_node("provider_caller",     N.provider_caller)   # llm.bind_tools call
    g.add_node("tool_executor",       tool_executor)        # ToolNode (builtin)
    g.add_node("ranking",             N.ranking)
    g.add_node("decision",            N.decision)
    g.add_node("response_formatter",  N.response_formatter) # NEW: polishes output
    g.add_node("booking_step",        N.booking_step)
    g.add_node("followup_step",       N.followup_step)
    g.add_node("clarifier",           N.clarifier)

    g.add_node("inquiry_formatter",   N.inquiry_formatter)
    
    # ---- edges --------------------------------------------------------------
    g.add_edge(START, "intent_parser")

    # intent_parser → clarifier       (missing slots / low confidence)
    # intent_parser → provider_caller  (intent complete & confident)
    g.add_conditional_edges(
        "intent_parser",
        N.route_after_intent,
        {
            "clarifier":       "clarifier",
            "provider_caller": "provider_caller",
        },
    )

    # provider_caller always feeds into ToolNode — the LLM must emit a tool call.
    g.add_edge("provider_caller", "tool_executor")

    # After ToolNode executes find_providers:
    #   → ranking   if ToolMessage contains ≥1 candidate
    #   → clarifier if ToolMessage is empty (ask user to broaden area/category)
    g.add_conditional_edges(
        "tool_executor",
        N.route_after_tool_executor,
        {"ranking": "ranking", "clarifier": "clarifier"},
    )

    g.add_edge("clarifier", "intent_parser")

    g.add_conditional_edges(
        "ranking",
        N.route_after_ranking,
        {
            "inquiry_formatter": "inquiry_formatter",
            "clarifier": "clarifier",
            "decision": "decision",
        }
    )
    g.add_edge("inquiry_formatter",  END)
    g.add_edge("decision",           "response_formatter")   # NEW edge
    g.add_edge("response_formatter", "booking_step")         # was decision → booking
    g.add_edge("booking_step",       "followup_step")
    g.add_edge("followup_step",      END)

    # Checkpointer enables `interrupt()`-based pause/resume across HTTP turns.
    return g.compile(checkpointer=get_checkpointer())
