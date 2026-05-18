"""All LangGraph nodes for the service-matching agent.

A "node" is a callable `(state: AgentState) -> AgentState` that the graph
invokes. By convention every node here:

  1. Records `t0 = time.time()` so it can emit a latency-tagged trace entry.
  2. Reads what it needs from the incoming state (never mutates it in place).
  3. Either:
       a) Calls tools via `.invoke({...})` directly (ranking, booking, etc.), or
       b) Returns an AIMessage with tool_calls so ToolNode can execute them
          (provider_caller — this is the llm.bind_tools / ToolNode pattern).
  4. Appends a structured entry to `trace_steps` with node name, latency,
     and a small `output` summary. The trace ends up in `agent_traces.steps`
     and is rendered in the booking-detail UI as a vertical timeline.
  5. Returns a *new* state dict (TypedDict updates are functional — LangGraph
     merges keys onto the running state).

Tool-calling pattern (provider_caller → tool_executor):
  provider_caller binds find_providers to the LLM with `llm.bind_tools(...)`.
  The LLM emits an AIMessage whose `tool_calls` field specifies find_providers
  arguments. ToolNode (graph.py) intercepts that message, calls the tool, and
  appends a ToolMessage with the results to state.messages. ranking then reads
  the candidates from the ToolMessage.

The graph wiring lives in `app.agents.graph`; the routing functions
(`route_after_*`) also live here because they're intrinsically tied to a
node's output shape.
"""
from __future__ import annotations

import json
import logging
import re
import time
import uuid
from datetime import datetime, timedelta, timezone
from typing import Literal

log = logging.getLogger("agent")

from langchain_core.messages import AIMessage, ToolMessage
from langgraph.types import interrupt
from pydantic import BaseModel, Field

from app.agents import tools as T
from app.agents.llm import get_llm
from app.agents.prompts import (
    CLARIFIER_SYSTEM,
    DECISION_SYSTEM,
    INTENT_SYSTEM,
    PROVIDER_SYSTEM,
    RESPONSE_FORMATTER_SYSTEM,
)
from app.agents.state import AgentState
from app.scheduler.runtime import schedule_reminder

# Categories we actually support. The intent parser may return 'unknown';
# anything outside this set routes to the clarifier.
ALLOWED_CATEGORIES = ("ac_technician", "plumber", "electrician", "tutor", "beautician")

# Patterns to strip from LLM output to prevent robotic-sounding text.
_ROBOTIC_PATTERNS = [
    re.compile(r"^(Sure!?\s*|Of course!?\s*|Absolutely!?\s*|I['']d be happy to\s*)", re.I),
    re.compile(r"\b(let me know|could you please|I have found|based on your request)\b", re.I),
    re.compile(r"^[\"']|[\"']$"),  # strip wrapping quotes
]


def _sanitize_llm_text(text: str) -> str:
    """Clean up robotic patterns from LLM output."""
    text = (text or "").strip()
    for pat in _ROBOTIC_PATTERNS:
        text = pat.sub("", text).strip()
    # Collapse multiple spaces and re-strip.
    text = re.sub(r"\s{2,}", " ", text).strip()
    return text


# ---------------------------------------------------------------------------
# Small helpers (used by multiple nodes)
# ---------------------------------------------------------------------------
def _append_step(state: AgentState, **entry) -> list[dict]:
    """Return trace_steps with one new entry appended. Pure / non-mutating."""
    return list(state.get("trace_steps") or []) + [entry]


def _missing_slots(intent: dict | None) -> list[str]:
    """Which required intent fields are still null?
    If intent_type is 'inquiry', we don't strictly require scheduled_at.
    """
    if not intent:
        return ["service_type", "area", "scheduled_at", "selected_provider"]
    
    intent_type = intent.get("intent_type", "book")
    required = ["service_type", "area"]
    if intent_type == "book":
        required.append("scheduled_at")
        required.append("selected_provider")
        
    return [f for f in required if not intent.get(f)]


def _resolve_provider(selected_name: str | None, ranked: list[dict]) -> dict | None:
    """Deterministically map a name or positional word to a provider object."""
    if not selected_name or not ranked:
        return None
    s_name = selected_name.lower()
    
    # Positional matching
    if any(w in s_name for w in ["first", "1st", "pehla", "pehli", "phly", "pehle"]):
        return ranked[0]
    if any(w in s_name for w in ["second", "2nd", "dosra", "doosra", "dusra", "dusri"]):
        if len(ranked) >= 2: return ranked[1]
    if any(w in s_name for w in ["third", "3rd", "teesra", "tisra", "tisri"]):
        if len(ranked) >= 3: return ranked[2]
    if any(w in s_name for w in ["last", "aakhri"]):
        return ranked[min(2, len(ranked) - 1)]
        
    for p in ranked[:3]:
        if s_name in p["name"].lower() or p["name"].lower() in s_name:
            return p
            
    return None


# ===========================================================================
# 1. intent_parser
# ===========================================================================
class _IntentSchema(BaseModel):
    """Structured output schema for the Gemini intent call.

    Pydantic models become a JSON-Schema that Gemini follows; the LLM is
    forced to return exactly these fields and types.
    """
    
    intent_type: Literal["book", "inquiry"] = Field(
        default="book",
        description="'book' if they want to schedule a service, 'inquiry' if they are just asking for info/availability."
    )
    service_type: Literal[
        "ac_technician", "plumber", "electrician", "tutor", "beautician", "unknown"
    ] = Field(description="Service category, or 'unknown'.")
    area: str | None = Field(
        default=None, description="Sector code like 'G-13'. Null if not stated."
    )
    scheduled_at: str | None = Field(
        default=None, description="ISO 8601 timestamp with timezone. Null if not stated."
    )
    selected_provider: str | None = Field(
        default=None, description="The name of the provider the user selected. Null if not stated."
    )
    confidence: float = Field(ge=0.0, le=1.0)
    language: str = Field(description="'en' | 'ur' | 'roman_ur'")


def intent_parser(state: AgentState) -> AgentState:
    """Parse the user's natural language into slots (service_type, area, time).

    Merges with any prior partial intent so a multi-turn clarification loop
    accumulates slots rather than overwriting them.
    """
    t0 = time.time()
    log.info("─── intent_parser ───")
    log.info("  input_text: %s", state.get("input_text", "")[:100])

    # If we're resuming from the clarifier, fold the user's replies into the
    # text we send to the LLM. The system prompt instructs the LLM to use
    # follow-up replies to fill missing slots.
    user_text = state["input_text"]
    replies = state.get("clarification_context") or []
    
    last_agent_msg = ""
    for msg in reversed(state.get("messages") or []):
        if isinstance(msg, AIMessage) and msg.content:
            last_agent_msg = msg.content
            break

    if replies or last_agent_msg:
        user_text = f"Original request: {user_text}\n"
        if last_agent_msg:
            user_text += f"Agent's last question: {last_agent_msg}\n"
        if replies:
            user_text += f"Follow-up replies from user: " + " | ".join(replies)

    # Force structured output — no free-form parsing, no JSON-mode regex.
    llm = get_llm(temperature=0.0).with_structured_output(_IntentSchema)
    parsed: _IntentSchema = llm.invoke(
        [
            ("system", INTENT_SYSTEM.format(now=datetime.now(timezone.utc).isoformat())),
            ("human", user_text),
        ]
    )

    # Normalize: drop 'unknown' (we treat it as missing), keep nulls as nulls.
    new = {
        "intent_type": parsed.intent_type,
        "service_type": (
            parsed.service_type if parsed.service_type in ALLOWED_CATEGORIES else None
        ),
        "area": parsed.area,
        "scheduled_at": parsed.scheduled_at,
        "selected_provider": parsed.selected_provider,
        "confidence": parsed.confidence,
        "language": parsed.language,
    }
    # Merge with prior intent — later replies fill missing slots without
    # clobbering ones we already had.
    prior = state.get("intent") or {}
    merged = {**prior, **{k: v for k, v in new.items() if v is not None}}
    
    # If the user changed the area or service type mid-conversation, clear the old provider selection
    if new.get("area") and new["area"] != prior.get("area"):
        merged["selected_provider"] = None
    if new.get("service_type") and new["service_type"] != prior.get("service_type"):
        merged["selected_provider"] = None
    merged["confidence"] = new["confidence"]
    merged["language"] = new["language"] or prior.get("language")

    # Instantly resolve any raw referents (like "first one") to the EXACT provider name.
    # This guarantees downstream nodes (clarifier, decision) work flawlessly.
    ranked = state.get("ranked") or []
    if merged.get("selected_provider") and ranked:
        resolved = _resolve_provider(merged["selected_provider"], ranked)
        if resolved:
            merged["selected_provider"] = resolved["name"]
        else:
            merged["selected_provider"] = None  # Invalid selection

    log.info("  parsed → service=%s  area=%s  time=%s  conf=%.2f  lang=%s",
             merged.get("service_type"), merged.get("area"),
             merged.get("scheduled_at"), merged.get("confidence", 0),
             merged.get("language"))
    log.info("  took %d ms", int((time.time() - t0) * 1000))

    return {
        "intent": merged,
        "trace_steps": _append_step(
            state,
            node="intent_parser",
            ms=int((time.time() - t0) * 1000),
            output=merged,
        ),
    }


def route_after_intent(state: AgentState) -> str:
    """Conditional edge: go to provider_caller if we have enough info to search the DB
    (service_type and area). We defer asking for time until after we verify providers exist."""
    intent = state.get("intent") or {}
    missing_for_search = [f for f in ("service_type", "area") if not intent.get(f)]
    needs_clarify = (
        missing_for_search
        or (intent.get("confidence") or 0.0) < 0.6
        or intent.get("service_type") not in ALLOWED_CATEGORIES
    )
    route = "clarifier" if needs_clarify else "provider_caller"
    log.info("  route_after_intent → %s  (missing_for_search=%s, conf=%.2f)",
             route, missing_for_search, intent.get("confidence", 0))
    return route


# ===========================================================================
# 2. provider_caller  →  tool_executor (ToolNode, wired in graph.py)
#
# This is the llm.bind_tools + ToolNode pattern:
#   a) provider_caller asks the LLM (with tools bound) to decide what to fetch.
#      The LLM emits an AIMessage with a `find_providers` tool call in it.
#   b) ToolNode in the graph intercepts that message, executes find_providers,
#      and appends a ToolMessage containing the results to state.messages.
#   c) route_after_tool_executor reads the ToolMessage to decide the next step.
#   d) ranking extracts the candidates from that ToolMessage.
# ===========================================================================
def provider_caller(state: AgentState) -> dict:
    """Manually constructs an AIMessage with a tool call to bypass the LLM step,
    ensuring 'area' is not dropped while still satisfying the ToolNode pattern."""
    t0 = time.time()
    intent = state["intent"] or {}
    log.info("─── provider_caller ───")
    log.info("  category=%s  area=%s", intent.get("service_type"), intent.get("area"))

    args = {"category": intent.get("service_type")}
    if intent.get("area"):
        args["area"] = intent.get("area")
        
    ai_msg = AIMessage(
        content="",
        tool_calls=[
            {
                "name": "find_providers",
                "args": args,
                "id": f"call_{uuid.uuid4().hex[:8]}",
            }
        ]
    )

    # The AIMessage carries ai_msg.tool_calls — ToolNode will pick these up.
    return {
        "messages": [ai_msg],
        "trace_steps": _append_step(
            state,
            node="provider_caller",
            ms=int((time.time() - t0) * 1000),
            output={
                "tool_calls": [tc["name"] for tc in (ai_msg.tool_calls or [])]
            },
        ),
    }


def _parse_tool_message(state: AgentState) -> list[dict]:
    """Extract the list[dict] result from the last ToolMessage in state.messages.

    ToolNode serialises list/dict return values to a JSON string inside the
    ToolMessage.content field.  We recover the original Python structure here.
    """
    for msg in reversed(state.get("messages") or []):
        if isinstance(msg, ToolMessage):
            # If LangGraph kept it as a Python list, return it immediately.
            if isinstance(msg.content, list):
                return msg.content
            # If it was serialized to a JSON string, try to parse it.
            try:
                data = json.loads(msg.content)
                if isinstance(data, list):
                    return data
            except (json.JSONDecodeError, TypeError):
                pass
    return []


def route_after_tool_executor(state: AgentState) -> str:
    """After ToolNode runs find_providers: route to ranking if we got results,
    or back to clarifier to ask the user to try a different area / category."""
    return "ranking" if _parse_tool_message(state) else "clarifier"


# ===========================================================================
# 3. ranking
# ===========================================================================
def ranking(state: AgentState) -> AgentState:
    """Score candidates by distance × rating × availability.

    Candidates are read from the ToolMessage that ToolNode wrote after
    executing find_providers (the llm.bind_tools → ToolNode chain).
    rank_providers is still called via .invoke() — it's deterministic pure-
    Python scoring that doesn't benefit from LLM direction.
    """
    t0 = time.time()
    intent = state["intent"] or {}
    log.info("─── ranking ───")

    # Pull the raw list[dict] that ToolNode stored in the last ToolMessage.
    candidates = _parse_tool_message(state)
    log.info("  candidates from tool: %d", len(candidates))

    ranked = T.rank_providers.invoke(
        {
            "candidates": candidates,
            "area": intent.get("area"),
            "scheduled_at": intent.get("scheduled_at"),
        }
    )

    top = ranked[0] if ranked else None
    
    # Auto-select if there is exactly 1 candidate and the user hasn't selected one
    if len(ranked) == 1 and not intent.get("selected_provider"):
        intent["selected_provider"] = top["name"]
        
    log.info("  ranked %d providers — top: %s (score=%.3f)",
             len(ranked), top.get("name") if top else "none",
             top.get("score", 0) if top else 0)
    log.info("  took %d ms", int((time.time() - t0) * 1000))
    return {
        "ranked": ranked,
        "intent": intent,  # Write the modified intent back to state
        "trace_steps": _append_step(
            state,
            node="ranking",
            ms=int((time.time() - t0) * 1000),
            output={
                "ranked_count": len(ranked),
                "top_provider": top["id"] if top else None,
            },
        ),
    }


def route_after_ranking(state: AgentState) -> str:
    """If this is just an inquiry, go to inquiry_formatter.
    If it's a booking, check if we need a time slot OR a provider selection. 
    If either is missing, route to clarifier.
    Otherwise, go to decision (to process the booking)."""
    intent = state.get("intent") or {}
    if intent.get("intent_type") == "inquiry":
        return "inquiry_formatter"
    
    if not intent.get("scheduled_at") or not intent.get("selected_provider"):
        return "clarifier"
        
    return "decision"


# ===========================================================================
# 4a. decision (booking intent only)
# ===============================================================================================================================================
def _provider_brief(p: dict) -> dict:
    """Small dict for the decision LLM — keeps the prompt short and cheap."""
    return {
        "id": p["id"],
        "name": p["name"],
        "rating": p.get("rating"),
        "distance_km": p.get("distance_km"),
        "area": p.get("area"),
        "score": p.get("score"),
    }


def decision(state: AgentState) -> AgentState:
    """Pick the user's selected provider and generate a short human reasoning string."""
    t0 = time.time()
    ranked = state.get("ranked") or []
    log.info("─── decision ───")
    
    intent = state.get("intent") or {}
    selected = ranked[0]
    resolved = _resolve_provider(intent.get("selected_provider"), ranked)
    if resolved:
        selected = resolved

    top3 = [_provider_brief(p) for p in ranked[:3]]
    language = intent.get("language") or "en"

    # Temperature 0.3 for slight variation without going off-rails.
    llm = get_llm(temperature=0.3)
    resp = llm.invoke(
        [
            ("system", DECISION_SYSTEM),
            (
                "human",
                f"Provider: {selected['name']}, {selected.get('distance_km', '?')} km, "
                f"rated {selected.get('rating', '?')}★\n"
                f"Service: {intent.get('service_type', '')}\n"
                f"Time: {intent.get('scheduled_at', 'not specified')}\n"
                f"Language: {language}\n"
                "Write ONE sentence.",
            ),
        ]
    )
    reasoning = resp.content if isinstance(resp.content, str) else str(resp.content)
    reasoning = _sanitize_llm_text(reasoning)
    log.info("  reasoning: %s", reasoning[:120])
    log.info("  took %d ms", int((time.time() - t0) * 1000))

    return {
        "selected": selected,
        "reasoning": reasoning,
        "trace_steps": _append_step(
            state,
            node="decision",
            ms=int((time.time() - t0) * 1000),
            output={"selected": selected["id"], "reasoning": reasoning},
        ),
    }


# ===========================================================================
# 4b. response_formatter (NEW — sits between decision and booking)
# ===========================================================================
class _FormattedResponseSchema(BaseModel):
    """Structured output for the response formatter."""
    message: str = Field(description="ONE short confirmation sentence, max 15 words.")
    suggestions: list[str] = Field(
        description="2-3 follow-up action suggestions for the user.",
        default_factory=lambda: ["Book another service", "View my bookings"],
    )


def response_formatter(state: AgentState) -> AgentState:
    log.info("─── response_formatter ───")
    """Generate the final polished user-facing message.

    This replaces dumping raw `reasoning` into the chat. The structured
    output ensures consistency — the `message` is the chat bubble, and
    `suggestions` become clickable chips in the UI.
    """
    t0 = time.time()
    selected = state.get("selected") or {}
    intent = state.get("intent") or {}
    language = intent.get("language") or "en"

    # Build a concise context string for the formatter.
    context = (
        f"Provider: {selected.get('name', '?')}\n"
        f"Distance: {selected.get('distance_km', '?')} km\n"
        f"Rating: {selected.get('rating', '?')}\n"
        f"Service: {intent.get('service_type', '?')}\n"
        f"Time: {intent.get('scheduled_at', '?')}\n"
        f"Area: {intent.get('area', '?')}\n"
        f"Language: {language}"
    )

    try:
        llm = get_llm(temperature=0.2).with_structured_output(_FormattedResponseSchema)
        formatted: _FormattedResponseSchema = llm.invoke(
            [
                ("system", RESPONSE_FORMATTER_SYSTEM),
                ("human", context),
            ]
        )
        message = _sanitize_llm_text(formatted.message)
        suggestions = formatted.suggestions or []
    except Exception:
        # Fallback if structured output fails — use the reasoning directly.
        message = state.get("reasoning") or "Booked!"
        suggestions = ["Book another service", "View my bookings"]

    # Language-appropriate suggestions.
    if language == "roman_ur" and suggestions == ["Book another service", "View my bookings"]:
        suggestions = ["Aur koi service chahiye?", "Meri bookings dekhein"]
    elif language == "ur" and suggestions == ["Book another service", "View my bookings"]:
        suggestions = ["اور کوئی سروس؟", "میری بکنگز دیکھیں"]

    log.info("  formatted: %s", message[:120])
    log.info("  suggestions: %s", suggestions)
    log.info("  took %d ms", int((time.time() - t0) * 1000))

    return {
        "formatted_response": message,
        "suggestions": suggestions,
        "trace_steps": _append_step(
            state,
            node="response_formatter",
            ms=int((time.time() - t0) * 1000),
            output={"message": message, "suggestions": suggestions},
        ),
    }


# ===========================================================================
# 4c. inquiry_formatter (inquiry intent only)
# ===========================================================================
def inquiry_formatter(state: AgentState) -> AgentState:
    """Format a response listing the available providers without booking."""
    log.info("─── inquiry_formatter ───")
    t0 = time.time()
    
    intent = state.get("intent") or {}
    language = intent.get("language") or "en"
    ranked = state.get("ranked") or []
    
    if not ranked:
        # We shouldn't really hit this because route_after_tool_executor routes to clarifier if no results.
        message = "Sorry, I couldn't find any providers."
        suggestions = ["Try a different area"]
    else:
        top3 = [_provider_brief(p) for p in ranked[:3]]
        
        context = (
            f"Providers Found: {json.dumps(top3)}\n"
            f"Service: {intent.get('service_type', '?')}\n"
            f"Area: {intent.get('area', '?')}\n"
            f"Language: {language}"
        )

        from app.agents.prompts import INQUIRY_FORMATTER_SYSTEM
        try:
            llm = get_llm(temperature=0.3)
            resp = llm.invoke(
                [
                    ("system", INQUIRY_FORMATTER_SYSTEM),
                    ("human", context),
                ]
            )
            message = resp.content if isinstance(resp.content, str) else str(resp.content)
            message = _sanitize_llm_text(message)
        except Exception as e:
            log.warning("  inquiry_formatter LLM failed: %s", e)
            message = f"Found {len(ranked)} providers in {intent.get('area')}!"
            
        # Language-appropriate suggestions.
        if language == "roman_ur":
            suggestions = ["Yes, book the first one", "Koi aur area check karein?"]
        elif language == "ur":
            suggestions = ["پہلے والے کو بک کریں", "کوئی اور علاقہ دیکھیں؟"]
        else:
            suggestions = ["Book the top provider", "Check another area"]

    log.info("  formatted: %s", message[:120])
    log.info("  suggestions: %s", suggestions)
    log.info("  took %d ms", int((time.time() - t0) * 1000))

    return {
        "status": "completed",
        "formatted_response": message,
        "suggestions": suggestions,
        "trace_steps": _append_step(
            state,
            node="inquiry_formatter",
            ms=int((time.time() - t0) * 1000),
            output={"message": message, "suggestions": suggestions},
        ),
    }


# ===========================================================================
# 5. booking_step  (node name suffixed: 'booking' would collide with state key)
# ===========================================================================
def booking_step(state: AgentState) -> AgentState:
    log.info("─── booking_step ───")
    """Write the agent_traces row, then create the booking that references it."""
    t0 = time.time()
    intent = state["intent"] or {}
    selected = state["selected"]
    ranked = state.get("ranked") or []

    # Snapshot the top candidates so the trace is self-contained even if
    # providers table changes later.
    candidate_snapshot = [_provider_brief(p) for p in ranked[:5]]

    trace_id = T.insert_agent_trace.invoke(
        {
            "user_id": state["user_id"],
            "conversation_id": state.get("conversation_id"),
            "input_text": state["input_text"],
            "parsed_intent": intent,
            "candidate_providers": candidate_snapshot,
            "selected_provider_id": selected["id"],
            "reasoning": state.get("reasoning"),
            "steps": state.get("trace_steps") or [],
        }
    )
    booking = T.insert_booking.invoke(
        {
            "user_id": state["user_id"],
            "provider_id": selected["id"],
            "service_type": intent["service_type"],
            "location_text": intent.get("area") or "",
            "scheduled_at": intent["scheduled_at"],
            "agent_trace_id": trace_id,
        }
    )

    return {
        "booking": booking,
        "trace_id": trace_id,
        "trace_steps": _append_step(
            state,
            node="booking_step",
            ms=int((time.time() - t0) * 1000),
            output={"booking_id": booking["id"], "trace_id": trace_id},
        ),
    }


# ===========================================================================
# 6. followup_step
# ===========================================================================
def followup_step(state: AgentState) -> AgentState:
    log.info("─── followup_step ───")
    """Schedule the reminder: write a `notifications` row + register APScheduler job."""
    t0 = time.time()
    booking = state["booking"]

    # Demo affordance: judges can pass `demo_offset_seconds=30` to see the
    # reminder fire in real time, instead of waiting until 1h before the
    # actual scheduled time.
    if state.get("demo_offset_seconds"):
        remind_at = datetime.now(timezone.utc) + timedelta(
            seconds=int(state["demo_offset_seconds"])
        )
    else:
        sched = datetime.fromisoformat(booking["scheduled_at"].replace("Z", "+00:00"))
        remind_at = sched - timedelta(hours=1)

    payload = {
        "message": (
            f"Reminder: your {state['intent']['service_type']} appointment "
            "is in 1 hour."
        ),
        "booking_id": booking["id"],
    }
    notification = T.insert_notification.invoke(
        {
            "booking_id": booking["id"],
            "kind": "reminder",
            "scheduled_at": remind_at.isoformat(),
            "payload": payload,
        }
    )

    # APScheduler registration is NOT a @tool — it's process-local side effect
    # and the scheduler isn't part of the agent's tool surface.
    schedule_reminder(notification_id=notification["id"], run_at=remind_at)

    followup = {
        "notification_id": notification["id"],
        "reminder_at": remind_at.isoformat(),
    }
    return {
        "followup": followup,
        "status": "completed",
        "trace_steps": _append_step(
            state,
            node="followup_step",
            ms=int((time.time() - t0) * 1000),
            output=followup,
        ),
    }


# ===========================================================================
# 7. clarifier  (pauses the graph via interrupt() until the user replies)
# ===========================================================================
def _build_clarifier_question(
    intent: dict,
    missing: list[str],
    no_results: bool,
    available_areas: list[str],
    ranked: list[dict],
    input_text: str,
    is_area_inquiry: bool = False,
) -> str:
    """Ask the LLM to generate the clarification question.

    The LLM handles everything — greetings, partial requests, no-results.
    Only falls back to a generic string if the LLM literally crashes.
    """
    language = intent.get("language") or "en"

    if no_results:
        areas_str = ", ".join(available_areas) if available_areas else "other sectors"
        focus = (
            f"CRITICAL INSTRUCTION: There are ZERO providers found in '{intent.get('area')}' for '{intent.get('service_type')}'.\n"
            f"You MUST tell the user none are available in that area.\n"
            f"Providers ARE available in these areas: {areas_str}.\n"
            f"Ask the user if they'd like to try one of those areas instead, or if they want a different service.\n"
            f"DO NOT MENTION ANY SPECIFIC PROVIDER NAMES. DO NOT SAY YOU FOUND PROVIDERS IN {intent.get('area')}!"
        )
    elif is_area_inquiry:
        areas_str = ", ".join(available_areas) if available_areas else "Islamabad"
        focus = (
            f"The user is asking where '{intent.get('service_type')}' is available.\n"
            f"Providers ARE available in these areas: {areas_str}.\n"
            f"List the available areas and ask them which one they want."
        )
    elif not missing or len(missing) == 3:
        # ALL slots missing — user probably said "hello", "hi", or something
        # completely unrelated. Greet them warmly and ask what service they need.
        known = {k: v for k, v in intent.items()
                 if k in ("service_type", "area", "scheduled_at") and v}
        focus = (
            f"The user's message has NO service request info at all — "
            f"they might have just said hello or something casual.\n"
            f"Greet them back warmly and ask what service they need.\n"
            f"Mention the available services: AC technician, plumber, "
            f"electrician, tutor, beautician."
        )
    else:
        known = {k: v for k, v in intent.items() if k in ("service_type", "area", "scheduled_at", "selected_provider") and v}
        focus = (
            f"Known: {known}.\n"
            f"Missing: {missing}.\n"
            f"Ask for ALL missing fields in ONE short reply with examples."
        )
        if ranked and "selected_provider" in missing:
            top3 = [_provider_brief(p) for p in ranked[:3]]
            focus += (
                f"\nProviders Found: {json.dumps(top3)} (Total: {len(ranked)})\n"
                f"List ALL of the top providers found by name and rating (up to 3). "
                f"Then explicitly ask the user WHICH provider they want to book AND ask for any other missing details (like time)."
            )
        elif ranked and "scheduled_at" in missing and "selected_provider" not in missing:
            selected_p = _resolve_provider(intent["selected_provider"], ranked)
            if selected_p:
                focus += f"\nThe provider is {selected_p['name']} (Rating: {selected_p.get('rating', 'N/A')}★).\n"
                if selected_p.get("available_hours"):
                    import datetime as dt
                    today_name = dt.datetime.now(dt.timezone.utc).strftime('%a').lower()
                    hours = selected_p["available_hours"]
                    focus += (
                        f"Their schedule: {json.dumps(hours)}.\n"
                        f"CRITICAL: Explicitly tell the user that these are the provider's available slots (e.g., 'Inki availability kal 9am se 1pm hai...'). Read their schedule (today is {today_name}) and present their ACTUAL available time slots to the user.\n"
                    )
                focus += "Briefly mention the provider's name and rating so the user knows who it is, and ask them to pick a time from the available slots."

    llm = get_llm(temperature=0.4)
    try:
        resp = llm.invoke(
            [
                ("system", CLARIFIER_SYSTEM),
                (
                    "human",
                    f"User said: \"{input_text}\"\n"
                    f"Language: {language}\n"
                    f"{focus}\n"
                    "Write the reply.",
                ),
            ]
        )
        text = resp.content if isinstance(resp.content, str) else str(resp.content)
        text = (text or "").strip().strip('"').strip("'").strip()
        log.info("  LLM clarifier raw: %s", text[:150])
    except Exception as e:
        log.warning("  clarifier LLM failed: %s", e)
        text = ""

    # Only fall back if the LLM returned absolutely nothing.
    if not text:
        text = ("Hi! What service do you need?" if language == "en"
                else "Hello! Kya service chahiye?")

    return text


def clarifier(state: AgentState) -> AgentState:
    """Ask the user a question, pause the graph, resume on reply.

    Flow:
      1. Decide what's missing.
      2. Ask Gemini to phrase the question in the user's language.
      3. Persist the question on `conversations.last_question` (for UI display).
      4. `interrupt()` — graph pauses; API returns the question.
      5. When the user POSTs back, the router calls `Command(resume={...})`,
         which causes execution to continue from inside this node — `reply`
         picks up the value passed to `resume=`.
      6. Append the reply to `clarification_context` and bump the round counter.
         The conditional edge after this node either loops back to
         `intent_parser` (re-parse with new context) or routes to `give_up`
         if we've hit the round cap.
    """
    t0 = time.time()
    intent = state.get("intent") or {}
    rounds = int(state.get("clarify_rounds") or 0)
    log.info("─── clarifier (round %d) ───", rounds + 1)

    missing = _missing_slots(intent)
    log.info("  missing slots: %s", missing)

    # Check if we landed here because tool_executor found nothing in the requested area.
    # route_after_tool_executor routes here if _parse_tool_message(state) is empty.
    # We only want to trigger 'no_results' logic if we actually tried to search
    # (meaning we had service_type and area) but found nothing.
    tried_search = bool(intent.get("service_type") and intent.get("area"))
    no_results = tried_search and not _parse_tool_message(state)
    
    log.info("  clarifier state: tried_search=%s, no_results=%s", tried_search, no_results)
    
    is_area_inquiry = intent.get("intent_type") == "inquiry" and intent.get("service_type") and not intent.get("area")
    
    available_areas = []
    if (no_results or is_area_inquiry) and intent.get("service_type"):
        # The user asked for a service in an area, but the DB had none, OR they are explicitly asking where it's available.
        available_areas = T.find_available_areas.invoke({"category": intent["service_type"]})
        log.info("  fetched Available areas for %s: %s", 
                 intent["service_type"], available_areas)

    replies = state.get("clarification_context") or []
    latest_input = replies[-1] if replies else state.get("input_text", "")

    question = _build_clarifier_question(
        intent, missing, no_results, available_areas, state.get("ranked") or [], latest_input, is_area_inquiry
    )
    log.info("  question: %s", question[:120])

    # Show the question in the UI / conversation listing.
    T.upsert_conversation.invoke(
        {
            "conversation_id": state["conversation_id"],
            "user_id": state["user_id"],
            "status": "awaiting_user",
            "last_question": question,
        }
    )

    # First half of the trace (before pause).
    pre_pause_steps = _append_step(
        state,
        node="clarifier",
        ms=int((time.time() - t0) * 1000),
        output={"question": question, "round": rounds + 1},
    )

    # ----- PAUSE -----
    # The graph's PostgresSaver checkpoints state here. The HTTP request that
    # triggered this node returns the question to the caller. When the user
    # POSTs back with `conversation_id + text`, the router calls
    # `graph.invoke(Command(resume={"user_reply": text}))` and execution
    # picks up RIGHT HERE with `reply` bound to that dict.
    reply = interrupt({"question": question})
    # ----- RESUME -----

    # Coerce the resume payload into a string and stash it for the next
    # intent_parser pass.
    extra = list(state.get("clarification_context") or [])
    if reply:
        if isinstance(reply, dict):
            extra.append(str(reply.get("user_reply") or reply.get("text") or reply))
        else:
            extra.append(str(reply))

    post_resume_steps = pre_pause_steps + [
        {"node": "user_reply", "output": {"text": extra[-1] if extra else ""}}
    ]
    return {
        "clarify_rounds": rounds + 1,
        "clarification_context": extra,
        "question": question,
        "trace_steps": post_resume_steps,
    }


def route_after_clarifier(state: AgentState) -> str:
    """After a clarification round, always go back to intent_parser to re-parse.
    The agent keeps trying as long as the user keeps replying."""
    return "intent_parser"


# ===========================================================================
# 8. give_up  (terminal — too many failed clarifications)
# ===========================================================================
def give_up(state: AgentState) -> AgentState:
    """Surrender gracefully and mark the conversation abandoned."""
    T.upsert_conversation.invoke(
        {
            "conversation_id": state["conversation_id"],
            "user_id": state["user_id"],
            "status": "abandoned",
            "last_question": state.get("question"),
        }
    )
    return {
        "status": "abandoned",
        "reason": "Could not understand your request after 2 clarifications.",
        "trace_steps": _append_step(
            state, node="give_up", output={"reason": "max clarification rounds"}
        ),
    }
