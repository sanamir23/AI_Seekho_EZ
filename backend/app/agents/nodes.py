"""All LangGraph nodes for the service-matching agent.

Each node is a `(state) -> partial-state` function; LangGraph merges the
returned dict onto the running state. The `@traced` decorator wraps each
node with latency capture so the agent_traces table stays consistent.
"""
from __future__ import annotations

import functools
import json
import logging
import re
import time
import uuid
from datetime import datetime, timedelta, timezone
from typing import Any, Callable, Literal

log = logging.getLogger("agent")

from langchain_core.messages import AIMessage, ToolMessage
from langgraph.types import interrupt
from pydantic import BaseModel, Field

from app.agents import tools as T
from app.agents.tools import BookingConflictError
from app.agents.llm import get_llm
from app.agents.prompts import (
    CLARIFIER_SYSTEM,
    DECISION_AND_FORMAT_SYSTEM,
    INTENT_SYSTEM,
)
from app.agents.state import AgentState
from app.scheduler.runtime import schedule_reminder

ALLOWED_CATEGORIES = ("ac_technician", "plumber", "electrician", "tutor", "beautician")
_PKT = timezone(timedelta(hours=5))
_CATEGORY_HINTS = {
    "ac_technician": ("ac", "a/c", "air conditioner", "air conditioning"),
    "plumber": ("plumber", "plumbing", "pipe", "nalka", "paani"),
    "electrician": ("electrician", "electric", "bijli", "light", "switch"),
    "tutor": ("tutor", "teacher", "tuition", "parhai", "study"),
    "beautician": ("beautician", "beauty", "makeup", "salon", "mehndi"),
}

# Belt-and-braces — the prompt now tells the LLM not to use these, this catches
# the cases where it does anyway.
_ROBOTIC_PATTERNS = [
    re.compile(r"^(Sure!?\s*|Of course!?\s*|Absolutely!?\s*|I['']d be happy to\s*)", re.I),
    re.compile(r"^[\"']|[\"']$"),
]

MAX_CLARIFY_ROUNDS = 3
INTENT_CACHE_SIZE = 256


def _sanitize_llm_text(text: str) -> str:
    text = (text or "").strip()
    for pat in _ROBOTIC_PATTERNS:
        text = pat.sub("", text).strip()
    return re.sub(r"\s{2,}", " ", text).strip()


def _extract_area(text: str) -> str | None:
    m = re.search(r"\b([A-I])\s*[- ]?\s*(\d{1,2})\b", text, re.I)
    if not m:
        return None
    return f"{m.group(1).upper()}-{m.group(2)}"


def _parse_common_time(text: str) -> str | None:
    lower = (text or "").lower()
    now = datetime.now(_PKT)

    has_short_time = re.search(r"\b\d{1,2}(?::\d{2})?\s*(am|pm|baje|bjy|bj|bje)\b", lower)
    has_day_time = re.search(r"\b(tomorrow|today|kal|aaj)\b", lower)
    has_period = re.search(r"\b(subah|morning|dopahar|afternoon|sham|evening|raat|night)\b", lower)
    if re.search(r"\b(abhi|now|asap|urgent|jaldi)\b", lower) and not (has_short_time or has_day_time):
        return None
    if not (has_short_time or has_period):
        return None

    day = None
    if re.search(r"\b(tomorrow|kal)\b", lower):
        day = now.date() + timedelta(days=1)
    elif re.search(r"\b(today|aaj)\b", lower):
        day = now.date()
    if not day:
        day = now.date()

    m = re.search(
        r"\b(?:tomorrow|today|kal|aaj)\b(?:\s+(?:at|ko))?\s*(\d{1,2})(?::(\d{2}))?\s*(am|pm|baje)?\b",
        lower,
    )
    if m:
        hour = int(m.group(1))
        minute = int(m.group(2) or 0)
        meridiem = m.group(3)
    else:
        m = re.search(r"\b(\d{1,2})(?::(\d{2}))?\s*(am|pm|baje|bjy|bj|bje)\b", lower)
        if m:
            hour = int(m.group(1))
            minute = int(m.group(2) or 0)
            meridiem = m.group(3)
        else:
            hour = minute = None

    if hour is not None:
        if meridiem == "pm" and hour < 12:
            hour += 12
        elif meridiem == "am" and hour == 12:
            hour = 0
        elif meridiem in ("baje", "bjy", "bj", "bje") and 1 <= hour <= 7:
            hour += 12
    elif re.search(r"\b(subah|morning)\b", lower):
        hour, minute = 9, 0
    elif re.search(r"\b(dopahar|afternoon)\b", lower):
        hour, minute = 13, 0
    elif re.search(r"\b(sham|evening)\b", lower):
        hour, minute = 18, 0
    elif re.search(r"\b(raat|night)\b", lower):
        hour, minute = 21, 0
    else:
        hour, minute = 9, 0

    candidate = datetime(day.year, day.month, day.day, hour, minute, tzinfo=_PKT)
    if candidate <= now:
        candidate = candidate + timedelta(days=1)
    return candidate.isoformat()


def _service_label(service_type: str | None) -> str:
    return {
        "ac_technician": "AC technician",
        "plumber": "plumber",
        "electrician": "electrician",
        "tutor": "tutor",
        "beautician": "beautician",
    }.get(service_type or "", "provider")


def _infer_intent_fallback(text: str) -> dict:
    raw = text or ""
    lower = raw.lower()
    inferred: dict[str, Any] = {}

    for category, hints in _CATEGORY_HINTS.items():
        if any(re.search(rf"\b{re.escape(h)}\b", lower) for h in hints):
            inferred["service_type"] = category
            break

    area = _extract_area(raw)
    if area:
        inferred["area"] = area

    scheduled_at = _parse_common_time(raw)
    if scheduled_at:
        inferred["scheduled_at"] = scheduled_at
    if re.search(r"\b(abhi|now|asap|urgent|jaldi)\b", lower):
        inferred["preferred_time_text"] = "abhi" if "abhi" in lower else "now"
    if re.search(r"\b(1|first|1st|pehla|pehli|phly|pehle)\b", lower):
        inferred["selected_provider"] = "first"
    elif re.search(r"\b(2|second|2nd|dosra|doosra|dusra|dusri)\b", lower):
        inferred["selected_provider"] = "second"
    elif re.search(r"\b(3|third|3rd|teesra|tisra|tisri)\b", lower):
        inferred["selected_provider"] = "third"
    inferred["language"] = "roman_ur" if re.search(r"\b(mein|chahiye|abhi|kal|kardo)\b", lower) else None

    if inferred:
        inferred.setdefault("intent_type", "book")
        inferred["confidence"] = 0.75
    return inferred


# ---------------------------------------------------------------------------
# Tracing decorator — replaces the per-node t0/_append_step boilerplate.
# Each node returns its own keys; the decorator appends a trace step with
# `node`, `ms`, and a short output summary if the node didn't already.
# ---------------------------------------------------------------------------
def _append_step(state: AgentState, **entry) -> list[dict]:
    return list(state.get("trace_steps") or []) + [entry]


def traced(name: str) -> Callable:
    def deco(fn: Callable) -> Callable:
        @functools.wraps(fn)
        def wrapper(state: AgentState) -> dict:
            t0 = time.time()
            log.info("─── %s ───", name)
            out = fn(state) or {}
            if "trace_steps" not in out:
                summary: dict[str, Any] = {}
                for k in ("intent", "ranked", "selected", "booking", "free_slots"):
                    if k in out:
                        v = out[k]
                        if isinstance(v, list):
                            summary[k] = len(v)
                        elif isinstance(v, dict):
                            summary[k] = v.get("id") or v.get("name") or list(v.keys())[:3]
                        else:
                            summary[k] = v
                out["trace_steps"] = _append_step(
                    state, node=name, ms=int((time.time() - t0) * 1000), output=summary
                )
            log.info("  %s took %d ms", name, int((time.time() - t0) * 1000))
            return out
        return wrapper
    return deco


def _missing_slots(intent: dict | None) -> list[str]:
    if not intent:
        return ["service_type", "area", "scheduled_at", "selected_provider"]
    intent_type = intent.get("intent_type", "book")
    if intent_type in ("cancel", "reschedule"):
        # Different requirements — handled by their own routes.
        return []
    required = ["service_type", "area"]
    if intent_type == "book":
        required += ["scheduled_at", "selected_provider"]
    return [f for f in required if not intent.get(f)]


def _resolve_provider(selected_name: str | None, ranked: list[dict]) -> dict | None:
    if not selected_name or not ranked:
        return None
    s = selected_name.lower()
    if any(w in s for w in ["first", "1st", "pehla", "pehli", "phly", "pehle"]):
        return ranked[0]
    if any(w in s for w in ["second", "2nd", "dosra", "doosra", "dusra", "dusri"]):
        if len(ranked) >= 2: return ranked[1]
    if any(w in s for w in ["third", "3rd", "teesra", "tisra", "tisri"]):
        if len(ranked) >= 3: return ranked[2]
    if any(w in s for w in ["last", "aakhri"]):
        return ranked[min(2, len(ranked) - 1)]
    for p in ranked[:3]:
        if s in p["name"].lower() or p["name"].lower() in s:
            return p
    return None


def _provider_brief(p: dict) -> dict:
    return {
        "id": p["id"],
        "name": p["name"],
        "rating": p.get("rating"),
        "distance_km": p.get("distance_km"),
        "area": p.get("area"),
        "score": p.get("score"),
        "score_breakdown": p.get("score_breakdown"),
    }


# ===========================================================================
# 1. intent_parser
# ===========================================================================
class _IntentSchema(BaseModel):
    intent_type: Literal["book", "inquiry", "cancel", "reschedule"] = "book"
    service_type: Literal[
        "ac_technician", "plumber", "electrician", "tutor", "beautician", "unknown"
    ] = Field(description="Service category, or 'unknown'.")
    area: str | None = None
    scheduled_at: str | None = None
    selected_provider: str | None = None
    confidence: float = Field(ge=0.0, le=1.0)
    language: str = Field(description="'en' | 'ur' | 'roman_ur'")


# Small in-process cache for repeat phrasings ("plumber chahiye" typed 5x).
@functools.lru_cache(maxsize=INTENT_CACHE_SIZE)
def _cached_intent(user_text: str, now_bucket: str) -> dict:
    llm = get_llm(temperature=0.0).with_structured_output(_IntentSchema)
    parsed: _IntentSchema = llm.invoke(
        [
            ("system", INTENT_SYSTEM.format(now=now_bucket)),
            ("human", user_text),
        ]
    )
    return parsed.model_dump()


@traced("intent_parser")
def intent_parser(state: AgentState) -> dict:
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
            user_text += "Follow-up replies from user: " + " | ".join(replies)

    # Cache by user_text + a 1-minute bucket so relative dates still resolve sanely.
    now = datetime.now(timezone.utc)
    bucket = now.replace(second=0, microsecond=0).isoformat()
    fallback: dict[str, Any] = {}
    used_fallback = False
    try:
        parsed = _cached_intent(user_text, bucket)
    except Exception as e:
        log.warning("intent LLM failed: %s — falling back to local parser", e)
        fallback = _infer_intent_fallback(user_text)
        parsed = {
            "intent_type": fallback.get("intent_type", "book"),
            "service_type": fallback.get("service_type", "unknown"),
            "area": fallback.get("area"),
            "scheduled_at": fallback.get("scheduled_at"),
            "selected_provider": fallback.get("selected_provider"),
            "confidence": fallback.get("confidence", 0.0),
            "language": fallback.get("language") or "en",
        }
        used_fallback = True

    new = {
        "intent_type": parsed.get("intent_type", "book"),
        "service_type": (
            parsed["service_type"] if parsed.get("service_type") in ALLOWED_CATEGORIES else None
        ),
        "area": parsed.get("area"),
        "scheduled_at": parsed.get("scheduled_at"),
        "selected_provider": parsed.get("selected_provider"),
        "confidence": parsed.get("confidence", 0.0),
        "language": parsed.get("language") or "en",
    }

    if used_fallback and fallback.get("preferred_time_text") and not new.get("scheduled_at"):
        new["preferred_time_text"] = fallback["preferred_time_text"]

    prior = state.get("intent") or {}
    merged = {**prior, **{k: v for k, v in new.items() if v is not None}}
    if new.get("area") and new["area"] != prior.get("area"):
        merged["selected_provider"] = None
    if new.get("service_type") and new["service_type"] != prior.get("service_type"):
        merged["selected_provider"] = None
    merged["confidence"] = new["confidence"]
    merged["language"] = new["language"] or prior.get("language")
    merged["intent_type"] = new["intent_type"] or prior.get("intent_type", "book")

    ranked = state.get("ranked") or []
    if merged.get("selected_provider") and ranked:
        resolved = _resolve_provider(merged["selected_provider"], ranked)
        if resolved:
            merged["selected_provider"] = resolved["name"]
        else:
            merged["selected_provider"] = None

    log.info(
        "  parsed → type=%s svc=%s area=%s time=%s conf=%.2f",
        merged.get("intent_type"), merged.get("service_type"),
        merged.get("area"), merged.get("scheduled_at"), merged.get("confidence", 0),
    )
    return {"intent": merged}


def route_after_intent(state: AgentState) -> str:
    intent = state.get("intent") or {}
    itype = intent.get("intent_type", "book")
    if itype == "cancel":
        return "cancel_handler"
    if itype == "reschedule":
        return "reschedule_handler"

    rounds = int(state.get("clarify_rounds") or 0)
    if rounds >= MAX_CLARIFY_ROUNDS:
        return "give_up"

    missing_for_search = [f for f in ("service_type", "area") if not intent.get(f)]
    needs_clarify = (
        missing_for_search
        or (intent.get("confidence") or 0.0) < 0.6
        or intent.get("service_type") not in ALLOWED_CATEGORIES
    )
    route = "clarifier" if needs_clarify else "provider_caller"
    log.info("  route_after_intent → %s", route)
    return route


# ===========================================================================
# 2. provider_caller → tool_executor (ToolNode, wired in graph.py)
# ===========================================================================
@traced("provider_caller")
def provider_caller(state: AgentState) -> dict:
    intent = state["intent"] or {}
    args: dict[str, Any] = {"category": intent.get("service_type")}
    if intent.get("area"):
        args["area"] = intent["area"]
    if intent.get("scheduled_at"):
        args["scheduled_at"] = intent["scheduled_at"]

    ai_msg = AIMessage(
        content="",
        tool_calls=[
            {"name": "find_providers", "args": args, "id": f"call_{uuid.uuid4().hex[:8]}"}
        ],
    )
    return {"messages": [ai_msg]}


def _parse_tool_message(state: AgentState) -> list[dict]:
    for msg in reversed(state.get("messages") or []):
        if isinstance(msg, ToolMessage):
            if isinstance(msg.content, list):
                return msg.content
            try:
                data = json.loads(msg.content)
                if isinstance(data, list):
                    return data
            except (json.JSONDecodeError, TypeError):
                pass
    return []


def route_after_tool_executor(state: AgentState) -> str:
    return "ranking" if _parse_tool_message(state) else "no_results_handler"


# ===========================================================================
# 3. ranking
# ===========================================================================
@traced("ranking")
def ranking(state: AgentState) -> dict:
    intent = state["intent"] or {}
    candidates = _parse_tool_message(state)
    log.info("  candidates: %d", len(candidates))

    ranked = T.rank_providers.invoke(
        {
            "candidates": candidates,
            "area": intent.get("area"),
            "scheduled_at": intent.get("scheduled_at"),
        }
    )

    new_intent = dict(intent)
    if len(ranked) == 1 and not new_intent.get("selected_provider"):
        new_intent["selected_provider"] = ranked[0]["name"]

    return {"ranked": ranked, "intent": new_intent}


def route_after_ranking(state: AgentState) -> str:
    intent = state.get("intent") or {}
    if intent.get("intent_type") == "inquiry":
        return "inquiry_formatter"

    has_provider = bool(intent.get("selected_provider"))
    has_time = bool(intent.get("scheduled_at"))

    if has_provider and not has_time:
        return "slot_picker"
    if not has_provider:
        return "clarifier"
    return "decision_and_format"


# ===========================================================================
# 4. slot_picker — interrupts with a list of clickable time chips
# ===========================================================================
@traced("slot_picker")
def slot_picker(state: AgentState) -> dict:
    intent = state.get("intent") or {}
    ranked = state.get("ranked") or []
    selected = _resolve_provider(intent.get("selected_provider"), ranked) or (
        ranked[0] if ranked else None
    )
    if not selected:
        return {}  # nothing to pick from; the clarifier will catch it

    slots = T.get_provider_free_slots.invoke({"provider_id": selected["id"]})
    if not slots:
        # Fall back to a generic time prompt via the clarifier.
        return {"free_slots": []}

    language = intent.get("language") or "en"
    if language == "roman_ur":
        question = f"{selected['name']} kab chahiye? Yeh available slots hain:"
    elif language == "ur":
        question = f"{selected['name']} کب چاہیے؟ یہ دستیاب اوقات ہیں:"
    else:
        question = f"When do you want {selected['name']}? Pick a free slot:"

    T.upsert_conversation.invoke(
        {
            "conversation_id": state["conversation_id"],
            "user_id": state["user_id"],
            "status": "awaiting_user",
            "last_question": question,
        }
    )

    reply = interrupt({"question": question, "slots": slots})

    # User clicked a chip (or typed). Accept ISO directly or look up by label.
    picked_iso: str | None = None
    if isinstance(reply, dict):
        picked = str(reply.get("user_reply") or reply.get("text") or "").strip()
    else:
        picked = str(reply).strip() if reply else ""

    for s in slots:
        if picked == s["iso"] or picked.lower() == s["label"].lower():
            picked_iso = s["iso"]
            break
    if not picked_iso and picked.startswith(("20", "21")):  # crude ISO check
        picked_iso = picked

    new_intent = {**intent}
    if picked_iso:
        new_intent["scheduled_at"] = picked_iso
        extra = list(state.get("clarification_context") or []) + [picked_iso]
    else:
        extra = list(state.get("clarification_context") or []) + [picked]

    return {
        "intent": new_intent,
        "clarification_context": extra,
        "free_slots": slots,
        "question": question,
    }


# ===========================================================================
# 5. decision_and_format — uses the FAST model
# ===========================================================================
class _DecisionAndFormatSchema(BaseModel):
    reasoning: str = Field(description="ONE sentence explaining provider choice.")
    message: str = Field(description="ONE user-facing confirmation, max 18 words. Start with Done!/Booked!/Hogaya!/All set!/Pakka!")
    suggestions: list[str] = Field(
        default_factory=lambda: ["Book another service", "View my bookings"],
    )


@traced("decision_and_format")
def decision_and_format(state: AgentState) -> dict:
    ranked = state.get("ranked") or []
    intent = state.get("intent") or {}
    language = intent.get("language") or "en"

    selected = ranked[0] if ranked else None
    resolved = _resolve_provider(intent.get("selected_provider"), ranked)
    if resolved:
        selected = resolved

    if not selected:
        return {"reason": "no provider", "status": "abandoned"}

    # Price range — fetch in the same node for a one-shot.
    try:
        price_range = T.get_price_range.invoke({"category": intent.get("service_type", "")})
    except Exception:
        price_range = None

    top3 = [_provider_brief(p) for p in ranked[:3]]
    context = (
        f"Provider: {selected['name']}, {selected.get('distance_km', '?')} km, "
        f"rated {selected.get('rating', '?')}★\n"
        f"Service: {intent.get('service_type', '')}\n"
        f"Time: {intent.get('scheduled_at', 'not specified')}\n"
        f"Area: {intent.get('area', '?')}\n"
        f"Language: {language}\n"
        + (f"Price: PKR {price_range['min_pkr']}–{price_range['max_pkr']}\n" if price_range else "")
        + f"Top-3 for context: {json.dumps(top3)}"
    )

    message = "Booked!"
    reasoning = message
    suggestions = ["Book another service", "View my bookings"]

    try:
        llm = get_llm(temperature=0.3, fast=True).with_structured_output(_DecisionAndFormatSchema)
        out: _DecisionAndFormatSchema = llm.invoke(
            [("system", DECISION_AND_FORMAT_SYSTEM), ("human", context)]
        )
        reasoning = _sanitize_llm_text(out.reasoning)
        message = _sanitize_llm_text(out.message)
        suggestions = out.suggestions or suggestions
    except Exception as e:
        log.warning("decision LLM failed: %s", e)

    if suggestions == ["Book another service", "View my bookings"]:
        if language == "roman_ur":
            suggestions = ["Aur koi service chahiye?", "Meri bookings dekhein"]
        elif language == "ur":
            suggestions = ["اور کوئی سروس؟", "میری بکنگز دیکھیں"]

    return {
        "selected": selected,
        "reasoning": reasoning,
        "formatted_response": message,
        "suggestions": suggestions,
        "price_range": price_range,
    }


# ===========================================================================
# 6. inquiry_formatter
# ===========================================================================
@traced("inquiry_formatter")
def inquiry_formatter(state: AgentState) -> dict:
    intent = state.get("intent") or {}
    language = intent.get("language") or "en"
    ranked = state.get("ranked") or []

    if not ranked:
        return {
            "status": "completed",
            "formatted_response": "Sorry, I couldn't find any providers.",
            "suggestions": ["Try a different area"],
        }

    top3 = [_provider_brief(p) for p in ranked[:3]]
    context = (
        f"Providers Found: {json.dumps(top3)}\n"
        f"Service: {intent.get('service_type', '?')}\n"
        f"Area: {intent.get('area', '?')}\n"
        f"Language: {language}"
    )
    from app.agents.prompts import INQUIRY_FORMATTER_SYSTEM

    try:
        llm = get_llm(temperature=0.3, fast=True)
        resp = llm.invoke([("system", INQUIRY_FORMATTER_SYSTEM), ("human", context)])
        message = _sanitize_llm_text(
            resp.content if isinstance(resp.content, str) else str(resp.content)
        )
    except Exception as e:
        log.warning("  inquiry LLM failed: %s", e)
        message = f"Found {len(ranked)} providers in {intent.get('area')}!"

    if language == "roman_ur":
        suggestions = ["Yes, book the first one", "Koi aur area check karein?"]
    elif language == "ur":
        suggestions = ["پہلے والے کو بک کریں", "کوئی اور علاقہ دیکھیں؟"]
    else:
        suggestions = ["Book the top provider", "Check another area"]

    return {
        "status": "completed",
        "formatted_response": message,
        "suggestions": suggestions,
    }


# ===========================================================================
# 7. no_results_handler — waitlist + suggest other areas
# ===========================================================================
@traced("no_results_handler")
def no_results_handler(state: AgentState) -> dict:
    intent = state.get("intent") or {}
    category = intent.get("service_type")
    area = intent.get("area")
    available = []
    if category:
        try:
            available = T.find_available_areas.invoke({"category": category})
        except Exception:
            pass

    area_has_providers = bool(
        area and any(str(a).lower() == str(area).lower() for a in available)
    )

    # Add to waitlist only when no providers serve that area at all.
    if category and area and not area_has_providers:
        try:
            T.add_to_waitlist.invoke(
                {"user_id": state["user_id"], "category": category, "area": area}
            )
        except Exception as e:
            log.warning("  waitlist insert failed: %s", e)

    # Now route to clarifier so it can suggest the available areas.
    return {}


# ===========================================================================
# 8. booking_step
# ===========================================================================
@traced("booking_step")
def booking_step(state: AgentState) -> dict:
    intent = state["intent"] or {}
    selected = state["selected"]
    ranked = state.get("ranked") or []
    candidate_snapshot = [_provider_brief(p) for p in ranked[:5]]
    scheduled_at = intent.get("scheduled_at")

    if not T.is_provider_open_at(selected, scheduled_at):
        target_date = None
        try:
            target_date = datetime.fromisoformat(
                scheduled_at.replace("Z", "+00:00")
            ).date().isoformat()
        except Exception:
            pass
        alternatives = [
            _provider_brief(p)
            for p in ranked
            if p["id"] != selected["id"] and T.is_provider_open_at(p, scheduled_at)
        ][:3]
        try:
            other_slots = T.get_provider_free_slots.invoke(
                {"provider_id": selected["id"], "target_date": target_date}
            )
        except Exception:
            other_slots = []
        updated_intent = {**intent, "scheduled_at": None}
        return {
            "intent": updated_intent,
            "alternatives": alternatives,
            "free_slots": other_slots,
            "question": (
                f"{selected.get('name', 'That provider')} is not available at that time. "
                "Pick another time or another provider."
            ),
            "status": None,
        }

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
            "idempotency_key": state.get("idempotency_key"),
        }
    )

    try:
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
    except (BookingConflictError, Exception) as exc:
        if not isinstance(exc, BookingConflictError) and "already booked" not in str(exc).lower():
            raise
        # Auto-suggest: next 3 ranked providers + this provider's other free slots.
        alternatives = [_provider_brief(p) for p in ranked if p["id"] != selected["id"]][:3]
        try:
            other_slots = T.get_provider_free_slots.invoke({"provider_id": selected["id"]})
        except Exception:
            other_slots = []
        updated_intent = {**(intent or {}), "scheduled_at": None}
        return {
            "intent": updated_intent,
            "alternatives": alternatives,
            "free_slots": other_slots,
            "question": (
                f"{selected.get('name', 'That provider')} is already booked at that time. "
                "Pick another time or another provider."
            ),
            "status": None,
        }

    # Update user_profile for personalisation.
    try:
        T.upsert_user_profile.invoke(
            {
                "user_id": state["user_id"],
                "preferred_area": intent.get("area"),
                "last_category": intent.get("service_type"),
                "increment_count": True,
            }
        )
    except Exception as e:
        log.warning("  user_profile upsert failed: %s", e)

    return {"booking": booking, "trace_id": trace_id}


# ===========================================================================
# 9. followup_step
# ===========================================================================
@traced("followup_step")
def followup_step(state: AgentState) -> dict:
    booking = state["booking"]
    if state.get("demo_offset_seconds"):
        remind_at = datetime.now(timezone.utc) + timedelta(
            seconds=int(state["demo_offset_seconds"])
        )
    else:
        sched = datetime.fromisoformat(booking["scheduled_at"].replace("Z", "+00:00"))
        remind_at = sched - timedelta(hours=1)

    payload = {
        "message": (
            f"Reminder: your {state['intent']['service_type']} appointment is in 1 hour."
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
    try:
        schedule_reminder(notification_id=notification["id"], run_at=remind_at)
    except Exception as e:
        log.warning("  schedule_reminder failed: %s — recoverable on restart", e)

    return {
        "followup": {
            "notification_id": notification["id"],
            "reminder_at": remind_at.isoformat(),
        },
        "status": "completed",
    }


# ===========================================================================
# 10. clarifier — confidence-aware
# ===========================================================================
def _fallback_clarifier_question(
    intent: dict,
    missing: list[str],
    no_results: bool,
    available_areas: list[str],
    ranked: list[dict],
    is_area_inquiry: bool = False,
) -> str:
    language = intent.get("language") or "en"
    service = _service_label(intent.get("service_type"))
    area = intent.get("area")
    areas_str = ", ".join(available_areas[:3])

    if no_results:
        if intent.get("scheduled_at"):
            if language == "roman_ur":
                return (
                    f"{area} mein {service} us time available nahi. "
                    f"{areas_str} try karein ya koi aur time dein."
                )
            return (
                f"No {service} is free in {area} at that time. "
                f"Try {areas_str or 'another area'} or choose another time."
            )
        if language == "roman_ur":
            return (
                f"{area} mein {service} abhi available nahi. "
                f"{areas_str or 'koi aur area'} try karein?"
            )
        return f"No {service} is available in {area}. Try {areas_str or 'another area'}?"

    if is_area_inquiry:
        if language == "roman_ur":
            return f"{service} {areas_str or 'Islamabad'} mein available hain. Kis area mein book karna hai?"
        return f"{service} is available in {areas_str or 'Islamabad'}. Which area should I check?"

    if ranked and "selected_provider" in missing:
        names = ", ".join(
            f"{i}. {p.get('name')} ({p.get('rating', '?')}*)"
            for i, p in enumerate(ranked[:3], start=1)
        )
        needs_time = "scheduled_at" in missing
        if language == "roman_ur":
            if needs_time:
                return f"{names}. Kisko book karna hai aur kis time?"
            return f"{names}. Kisko book karna hai aur kis time?"
        if needs_time:
            return f"{names}. Which provider should I book, and what time?"
        return f"{names}. Which provider should I book, and what time?"

    if "scheduled_at" in missing:
        return "Kab chahiye - aaj, kal subah, ya specific time?" if language == "roman_ur" else "What time do you need - today, tomorrow morning, or a specific time?"
    if "area" in missing:
        return "Kis sector mein - G-13, F-10, I-8?" if language == "roman_ur" else "Which sector - G-13, F-10, or I-8?"
    if "service_type" in missing:
        return "Kya service chahiye - AC technician, plumber, electrician, tutor, ya beautician?" if language == "roman_ur" else "What service do you need - AC tech, plumber, electrician, tutor, or beautician?"
    return "Kya details confirm hain?" if language == "roman_ur" else "Can you confirm the details?"


def _build_clarifier_question(
    intent: dict,
    missing: list[str],
    no_results: bool,
    available_areas: list[str],
    ranked: list[dict],
    input_text: str,
    is_area_inquiry: bool = False,
) -> str:
    language = intent.get("language") or "en"
    conf = float(intent.get("confidence") or 0.0)

    if ranked and "selected_provider" in missing:
        return _fallback_clarifier_question(
            intent, missing, no_results, available_areas, ranked, is_area_inquiry
        )

    if no_results:
        areas_str = ", ".join(available_areas) if available_areas else "other sectors"
        focus = (
            f"There are ZERO providers in '{intent.get('area')}' for '{intent.get('service_type')}'.\n"
            f"Tell the user none are available there. Suggest these areas: {areas_str}.\n"
            f"Mention we've added them to a waitlist for that area."
        )
    elif is_area_inquiry:
        areas_str = ", ".join(available_areas) if available_areas else "Islamabad"
        focus = (
            f"User asked where '{intent.get('service_type')}' is available.\n"
            f"Available areas: {areas_str}. Ask which one they want."
        )
    elif not missing or len(missing) >= 3:
        focus = (
            "User's message has no service info — they may have said hello.\n"
            "Greet them and ask which service: AC technician, plumber, electrician, tutor, beautician."
        )
    elif 0.4 < conf < 0.6 and not missing:
        # Confidence-aware: yes/no confirm instead of slot-filling.
        focus = (
            f"You're not sure but think the user wants: {intent}.\n"
            "Ask a single yes/no confirmation in one short sentence."
        )
    else:
        known = {k: v for k, v in intent.items() if k in ("service_type", "area", "scheduled_at", "selected_provider") and v}
        focus = (
            f"Known: {known}. Missing: {missing}.\n"
            "Ask for ALL missing fields in ONE short reply with examples."
        )
        if ranked and "selected_provider" in missing:
            top3 = [_provider_brief(p) for p in ranked[:3]]
            focus += (
                f"\nProviders Found: {json.dumps(top3)} (Total: {len(ranked)})\n"
                "List the top providers by name + rating; ask which one to book."
            )

    try:
        llm = get_llm(temperature=0.4, fast=True)
        resp = llm.invoke(
            [
                ("system", CLARIFIER_SYSTEM),
                ("human", f'User said: "{input_text}"\nLanguage: {language}\n{focus}\nWrite the reply.'),
            ]
        )
        text = resp.content if isinstance(resp.content, str) else str(resp.content)
        text = _sanitize_llm_text((text or "").strip().strip('"').strip("'"))
    except Exception as e:
        log.warning("  clarifier LLM failed: %s", e)
        text = ""

    if not text:
        text = _fallback_clarifier_question(
            intent, missing, no_results, available_areas, ranked, is_area_inquiry
        )
    return text


@traced("clarifier")
def clarifier(state: AgentState) -> dict:
    intent = state.get("intent") or {}
    rounds = int(state.get("clarify_rounds") or 0)
    log.info("  clarifier round %d", rounds + 1)

    missing = _missing_slots(intent)
    tried_search = bool(intent.get("service_type") and intent.get("area"))
    no_results = tried_search and not _parse_tool_message(state) and not state.get("ranked")
    is_area_inquiry = (
        intent.get("intent_type") == "inquiry"
        and intent.get("service_type")
        and not intent.get("area")
    )

    available_areas: list[str] = []
    if (no_results or is_area_inquiry) and intent.get("service_type"):
        available_areas = T.find_available_areas.invoke({"category": intent["service_type"]})

    replies = state.get("clarification_context") or []
    latest_input = replies[-1] if replies else state.get("input_text", "")
    question = _build_clarifier_question(
        intent, missing, no_results, available_areas, state.get("ranked") or [],
        latest_input, is_area_inquiry,
    )

    T.upsert_conversation.invoke(
        {
            "conversation_id": state["conversation_id"],
            "user_id": state["user_id"],
            "status": "awaiting_user",
            "last_question": question,
        }
    )

    reply = interrupt({"question": question})

    extra = list(state.get("clarification_context") or [])
    if reply:
        if isinstance(reply, dict):
            extra.append(str(reply.get("user_reply") or reply.get("text") or reply))
        else:
            extra.append(str(reply))

    return {
        "clarify_rounds": rounds + 1,
        "clarification_context": extra,
        "question": question,
    }


def route_after_clarifier(state: AgentState) -> str:
    if int(state.get("clarify_rounds") or 0) >= MAX_CLARIFY_ROUNDS:
        return "give_up"
    return "intent_parser"


# ===========================================================================
# 11. cancel_handler / reschedule_handler — NL cancel / reschedule
# ===========================================================================
@traced("cancel_handler")
def cancel_handler(state: AgentState) -> dict:
    intent = state.get("intent") or {}
    language = intent.get("language") or "en"
    bookings = T.find_user_bookings.invoke(
        {
            "user_id": state["user_id"],
            "service_type": intent.get("service_type"),
            "upcoming_only": True,
            "limit": 5,
        }
    )
    if not bookings:
        msg = {
            "en": "You don't have any upcoming bookings to cancel.",
            "roman_ur": "Aapki koi upcoming booking nahi hai cancel karne ke liye.",
            "ur": "آپ کی کوئی آنے والی بکنگ نہیں جو cancel کی جا سکے۔",
        }.get(language, "No upcoming bookings to cancel.")
        return {
            "status": "completed",
            "formatted_response": msg,
            "suggestions": ["Book a service", "View my bookings"],
        }

    # Cancel the soonest match.
    target = bookings[0]
    cancelled = T.cancel_booking.invoke(
        {"user_id": state["user_id"], "booking_id": target["id"]}
    )
    pname = (target.get("providers") or {}).get("name", "Provider")
    msg = {
        "en": f"Cancelled your {intent.get('service_type','')} booking with {pname}.",
        "roman_ur": f"Hogaya — {pname} wali booking cancel kardi.",
        "ur": f"ہوگیا — {pname} والی بکنگ منسوخ کر دی۔",
    }.get(language, f"Cancelled booking with {pname}.")
    return {
        "status": "completed",
        "booking": cancelled,
        "formatted_response": msg,
        "suggestions": ["Book again", "View my bookings"],
    }


@traced("reschedule_handler")
def reschedule_handler(state: AgentState) -> dict:
    intent = state.get("intent") or {}
    language = intent.get("language") or "en"
    new_time = intent.get("scheduled_at")
    if not new_time:
        msg = {
            "en": "What's the new time?",
            "roman_ur": "Naya time kya rakhna hai?",
            "ur": "نیا وقت کیا رکھنا ہے؟",
        }.get(language, "What's the new time?")
        return {"status": "needs_clarification", "question": msg}

    bookings = T.find_user_bookings.invoke(
        {
            "user_id": state["user_id"],
            "service_type": intent.get("service_type"),
            "upcoming_only": True,
            "limit": 5,
        }
    )
    if not bookings:
        msg = {
            "en": "You don't have any upcoming bookings to reschedule.",
            "roman_ur": "Aapki koi booking nahi hai reschedule karne ke liye.",
            "ur": "آپ کی کوئی بکنگ نہیں ہے۔",
        }.get(language, "No upcoming bookings to reschedule.")
        return {"status": "completed", "formatted_response": msg}

    target = bookings[0]
    updated = T.reschedule_booking.invoke(
        {
            "user_id": state["user_id"],
            "booking_id": target["id"],
            "new_scheduled_at": new_time,
        }
    )
    pname = (target.get("providers") or {}).get("name", "Provider")
    msg = {
        "en": f"Rescheduled your {pname} booking to {new_time}.",
        "roman_ur": f"Hogaya — {pname} ki booking new time pe set kardi.",
        "ur": f"ہوگیا — {pname} کی بکنگ نئے وقت پر۔",
    }.get(language, f"Rescheduled to {new_time}.")
    return {
        "status": "completed",
        "booking": updated,
        "formatted_response": msg,
        "suggestions": ["Book a service", "View my bookings"],
    }


# ===========================================================================
# 12. give_up
# ===========================================================================
@traced("give_up")
def give_up(state: AgentState) -> dict:
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
        "reason": "Could not understand your request after several tries.",
    }
