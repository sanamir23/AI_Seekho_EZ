from __future__ import annotations

import asyncio
import logging
import re
import time
import uuid
from collections import deque

from fastapi import APIRouter, Depends, HTTPException, Request, status, UploadFile, File
from langgraph.types import Command
import google.generativeai as genai

from app.agents.graph import build_graph
from app.agents import tools as T
from app.deps import CurrentUser, get_current_user
from app.schemas.service_request import (
    AgentRunOut,
    BookingBrief,
    FollowupBrief,
    IntentParsed,
    PriceRange,
    ProviderBrief,
    ServiceRequestIn,
    SlotOption,
    ThinkingStep,
)

log = logging.getLogger("agent")

router = APIRouter(prefix="/service-requests", tags=["agent"])

# Pinned transcription model — intentionally NOT read from settings/.env.
# The gemini-2.0-* models return quota limit:0 on the current key; this alias
# has quota and supports audio input.
_TRANSCRIBE_MODEL = "gemini-flash-latest"

# Per-user in-memory rate limit: 30 requests / 60 seconds. Good enough for a
# hackathon demo without bringing in slowapi/redis.
_RATE_WINDOW_S = 60
_RATE_MAX = 30
_rate_buckets: dict[str, deque[float]] = {}


def _check_rate(user_id: str) -> None:
    now = time.time()
    bucket = _rate_buckets.setdefault(user_id, deque())
    while bucket and now - bucket[0] > _RATE_WINDOW_S:
        bucket.popleft()
    if len(bucket) >= _RATE_MAX:
        raise HTTPException(
            status.HTTP_429_TOO_MANY_REQUESTS,
            "Slow down — try again in a few seconds.",
        )
    bucket.append(now)


# Prompt-injection sanitisation: strip the most common "ignore previous" tricks
# and cap length. We don't try to be exhaustive — Gemini's structured output is
# the real defence; this is a cheap first line.
_INJECTION_PATTERNS = [
    re.compile(r"ignore\s+(all\s+)?(previous|prior|above)\s+instructions?", re.I),
    re.compile(r"system\s+prompt", re.I),
    re.compile(r"</?(system|assistant)>", re.I),
]

_THINKING_LABELS: dict[str, tuple[str, str]] = {
    "intent_parser": ("Understanding request", "Reading service, area, time, and language."),
    "provider_caller": ("Preparing provider search", "Choosing the right provider lookup."),
    "tool_executor": ("Searching providers", "Checking verified providers in the database."),
    "no_results_handler": ("Checking nearby coverage", "Looking for useful alternatives."),
    "ranking": ("Ranking matches", "Comparing distance, rating, and availability."),
    "slot_picker": ("Checking free slots", "Finding the earliest suitable appointment."),
    "decision_and_format": ("Preparing answer", "Turning the match into a clear reply."),
    "booking_step": ("Confirming booking", "Securing the selected provider and time."),
    "followup_step": ("Setting reminder", "Scheduling the follow-up notification."),
    "clarifier": ("Checking details", "Asking only for the missing information."),
    "inquiry_formatter": ("Preparing options", "Summarizing available providers."),
    "cancel_handler": ("Cancelling booking", "Finding and cancelling the matching appointment."),
    "reschedule_handler": ("Rescheduling booking", "Finding the booking and applying the new time."),
    "give_up": ("Stopping safely", "Pausing until the request is clearer."),
}

_DEFAULT_THINKING_BY_STATUS: dict[str, list[str]] = {
    "completed": ["intent_parser", "provider_caller", "ranking", "decision_and_format"],
    "needs_clarification": ["intent_parser", "clarifier"],
    "abandoned": ["intent_parser", "give_up"],
}


def _sanitize_input(text: str) -> str:
    text = (text or "").strip()
    for pat in _INJECTION_PATTERNS:
        text = pat.sub("[redacted]", text)
    return text[:2000]


def _build_thinking_steps(state: dict) -> list[ThinkingStep]:
    status_ = state.get("status") or "needs_clarification"
    nodes: list[tuple[str, int | None]] = []
    seen: set[str] = set()

    for step in state.get("trace_steps") or []:
        if not isinstance(step, dict):
            continue
        key = str(step.get("node") or "").strip()
        if not key or key in seen:
            continue
        seen.add(key)
        ms_raw = step.get("ms")
        ms = int(ms_raw) if isinstance(ms_raw, (int, float)) else None
        nodes.append((key, ms))

    if not nodes:
        nodes = [
            (key, None)
            for key in _DEFAULT_THINKING_BY_STATUS.get(status_, ["intent_parser"])
        ]

    safe_steps: list[ThinkingStep] = []
    for index, (key, ms) in enumerate(nodes):
        title, detail = _THINKING_LABELS.get(
            key,
            ("Working on request", "Advancing the service request safely."),
        )
        step_status = "done"
        if status_ == "needs_clarification" and index == len(nodes) - 1:
            step_status = "waiting"
        elif status_ == "abandoned" and index == len(nodes) - 1:
            step_status = "stopped"
        safe_steps.append(
            ThinkingStep(
                key=key,
                title=title,
                detail=detail,
                status=step_status,
                ms=ms,
            )
        )
    return safe_steps


def _build_response(state: dict, conversation_id: str) -> AgentRunOut:
    status_ = state.get("status")
    log.info("─── _build_response status=%s ───", status_)
    thinking_steps = _build_thinking_steps(state)

    price_range = None
    pr = state.get("price_range")
    if pr:
        try:
            price_range = PriceRange(**pr)
        except Exception:
            price_range = None

    if status_ == "completed":
        selected = state.get("selected")
        booking = state.get("booking")
        followup = state.get("followup")

        provider_brief = None
        if selected:
            provider_brief = ProviderBrief(
                id=selected["id"],
                name=selected["name"],
                category=selected["category"],
                area=selected.get("area"),
                rating=selected.get("rating"),
                distance_km=selected.get("distance_km"),
                score=selected.get("score"),
                score_breakdown=selected.get("score_breakdown"),
            )
        booking_brief = None
        if booking:
            booking_brief = BookingBrief(
                id=booking["id"],
                status=booking["status"],
                scheduled_at=booking["scheduled_at"],
                provider_id=booking["provider_id"],
            )
        return AgentRunOut(
            status="completed",
            conversation_id=conversation_id,
            thinking_steps=thinking_steps,
            intent=IntentParsed(**(state.get("intent") or {})),
            selected_provider=provider_brief,
            reasoning=state.get("reasoning"),
            formatted_message=state.get("formatted_response"),
            suggestions=state.get("suggestions"),
            booking=booking_brief,
            followup=FollowupBrief(**followup) if followup else None,
            trace_id=state.get("trace_id"),
            trace_steps=state.get("trace_steps"),
            price_range=price_range,
        )
    if status_ == "abandoned":
        return AgentRunOut(
            status="abandoned",
            conversation_id=conversation_id,
            thinking_steps=thinking_steps,
            reason=state.get("reason"),
            partial_intent=IntentParsed(**(state.get("intent") or {})),
        )

    # needs_clarification — may carry slot chips or alternative providers.
    slot_opts = None
    if state.get("free_slots"):
        try:
            slot_opts = [SlotOption(**s) for s in state["free_slots"]]
        except Exception:
            slot_opts = None
    alternatives = None
    if state.get("alternatives"):
        try:
            alternatives = [
                ProviderBrief(
                    id=p["id"], name=p["name"], category=p.get("category", ""),
                    area=p.get("area"), rating=p.get("rating"),
                    distance_km=p.get("distance_km"),
                    score=p.get("score"), score_breakdown=p.get("score_breakdown"),
                )
                for p in state["alternatives"]
            ]
        except Exception:
            alternatives = None

    return AgentRunOut(
        status="needs_clarification",
        conversation_id=conversation_id,
        thinking_steps=thinking_steps,
        question=state.get("question"),
        partial_intent=IntentParsed(**(state.get("intent") or {})),
        free_slots=slot_opts,
        alternatives=alternatives,
        suggestions=state.get("suggestions"),
    )


def _extract_state(result: dict, graph, config) -> dict:
    if result.get("status") == "completed":
        return result
    try:
        snapshot = graph.get_state(config)
        if snapshot and snapshot.values:
            merged = {**result, **snapshot.values}
            question = None
            slots = None
            for task in (snapshot.tasks or []):
                for intr in getattr(task, "interrupts", ()):
                    val = getattr(intr, "value", None)
                    if isinstance(val, dict):
                        question = val.get("question") or question
                        slots = val.get("slots") or slots
                if question:
                    break
            if question:
                merged["question"] = question
            if slots:
                merged["free_slots"] = slots
            return merged
    except Exception as e:
        log.warning("checkpoint read failed: %s", e)
    return result


def _idempotency_replay(user_id: str, key: str) -> AgentRunOut | None:
    row = T.find_trace_by_idempotency(user_id, key)
    if not row:
        return None
    log.info("idempotency hit for %s", key)
    return AgentRunOut(
        status="completed",
        conversation_id=row.get("conversation_id") or "",
        thinking_steps=_build_thinking_steps(
            {"status": "completed", "trace_steps": row.get("steps") or []}
        ),
        intent=IntentParsed(**(row.get("parsed_intent") or {})),
        reasoning=row.get("reasoning"),
        trace_id=row["id"],
        trace_steps=row.get("steps"),
        formatted_message=row.get("reasoning"),
    )


@router.post("", response_model=AgentRunOut)
async def run_service_request(
    body: ServiceRequestIn,
    request: Request,
    user: CurrentUser = Depends(get_current_user),
) -> AgentRunOut:
    _check_rate(user.id)

    # Idempotency: header beats body, but accept either.
    idemp = request.headers.get("Idempotency-Key") or body.idempotency_key
    if idemp:
        replay = _idempotency_replay(user.id, idemp)
        if replay:
            return replay

    body_text = _sanitize_input(body.text)
    if not body_text:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Empty message")

    graph = build_graph()

    if body.conversation_id:
        cid = body.conversation_id
        config = {"configurable": {"thread_id": cid}}
        state_before = graph.get_state(config)
        if not state_before or not state_before.values:
            # Checkpoint was evicted — start a fresh conversation rather than 404,
            # keeping the user's text as the new initial input.
            log.warning("conversation %s missing, restarting", cid)
            cid = str(uuid.uuid4())
            config = {"configurable": {"thread_id": cid}}
            await asyncio.to_thread(
                T.upsert_conversation.invoke,
                {"conversation_id": cid, "user_id": user.id, "status": "active"},
            )
            initial: dict = {
                "user_id": user.id,
                "conversation_id": cid,
                "input_text": body_text,
                "trace_steps": [],
                "clarify_rounds": 0,
                "clarification_context": [],
                "demo_offset_seconds": body.demo_offset_seconds,
                "idempotency_key": idemp,
            }
            result = await asyncio.to_thread(graph.invoke, initial, config)
        else:
            if state_before.values.get("user_id") != user.id:
                raise HTTPException(status.HTTP_403_FORBIDDEN, "Not your conversation")
            result = await asyncio.to_thread(
                graph.invoke,
                Command(resume={"user_reply": body_text}),
                config,
            )
    else:
        cid = str(uuid.uuid4())
        config = {"configurable": {"thread_id": cid}}
        await asyncio.to_thread(
            T.upsert_conversation.invoke,
            {"conversation_id": cid, "user_id": user.id, "status": "active"},
        )
        initial = {
            "user_id": user.id,
            "conversation_id": cid,
            "input_text": body_text,
            "trace_steps": [],
            "clarify_rounds": 0,
            "clarification_context": [],
            "demo_offset_seconds": body.demo_offset_seconds,
            "idempotency_key": idemp,
        }
        result = await asyncio.to_thread(graph.invoke, initial, config)

    state = _extract_state(result, graph, config)

    if state.get("status") == "completed":
        await asyncio.to_thread(
            T.upsert_conversation.invoke,
            {"conversation_id": cid, "user_id": user.id, "status": "completed"},
        )

    return _build_response(state, cid)


@router.post("/transcribe")
async def transcribe_audio(
    file: UploadFile = File(...),
    user: CurrentUser = Depends(get_current_user),
):
    try:
        from app.config import get_settings
        settings = get_settings()
        genai.configure(api_key=settings.gemini_api_key)

        content = await file.read()

        # Normalize the upload MIME. Flutter sends AAC-in-m4a; Gemini is flaky
        # with "audio/mp4" but reliable with "audio/m4a"/"audio/aac". Anything
        # missing or mp4-ish is coerced to a type Gemini handles cleanly.
        mime = (file.content_type or "").lower()
        if mime in ("", "application/octet-stream", "audio/mp4", "video/mp4"):
            mime = "audio/m4a"

        # Model is pinned to the latest flash alias on purpose — it has quota on
        # this key and supports audio, unlike the gemini-2.0-* models. Do NOT
        # read this from settings/.env.
        model = genai.GenerativeModel(_TRANSCRIBE_MODEL)
        response = model.generate_content([
            "Transcribe the following audio accurately in its original language "
            "(e.g., Roman Urdu, Urdu, or English). Do not add any extra text, "
            "markdown formatting, or translation, just the raw transcription. "
            "If the audio is empty or you cannot hear anything, return nothing.",
            {"mime_type": mime, "data": content},
        ])

        # `response.text` raises ValueError when the model returns no parts
        # (silence, too-short clip, or a safety block). Treat that as "no
        # transcription" and return an empty string instead of a 500.
        text = ""
        try:
            text = (response.text or "").strip()
        except (ValueError, AttributeError):
            try:
                parts = response.candidates[0].content.parts
                text = "".join(getattr(p, "text", "") or "" for p in parts).strip()
            except Exception:
                text = ""

        log.info("Transcribed for user %s: %r", user.id, text)
        return {"text": text}
    except Exception as e:
        log.error("Audio transcription failed: %s", e)
        raise HTTPException(status.HTTP_500_INTERNAL_SERVER_ERROR, "Failed to transcribe audio")
