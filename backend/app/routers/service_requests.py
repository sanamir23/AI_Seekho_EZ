from __future__ import annotations

import logging
import uuid

from fastapi import APIRouter, Depends, HTTPException, status, UploadFile, File
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
    ProviderBrief,
    ServiceRequestIn,
)

log = logging.getLogger("agent")

router = APIRouter(prefix="/service-requests", tags=["agent"])


def _build_response(state: dict, conversation_id: str) -> AgentRunOut:
    status_ = state.get("status")
    log.info("─── _build_response ───")
    log.info("  status=%s  question=%s", status_, (state.get("question") or "")[:80])

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
            intent=IntentParsed(**(state.get("intent") or {})),
            selected_provider=provider_brief,
            reasoning=state.get("reasoning"),
            formatted_message=state.get("formatted_response"),
            suggestions=state.get("suggestions"),
            booking=booking_brief,
            followup=FollowupBrief(**followup) if followup else None,
            trace_id=state.get("trace_id"),
            trace_steps=state.get("trace_steps"),
        )
    if status_ == "abandoned":
        return AgentRunOut(
            status="abandoned",
            conversation_id=conversation_id,
            reason=state.get("reason"),
            partial_intent=IntentParsed(**(state.get("intent") or {})),
        )
    # Paused for clarification.
    return AgentRunOut(
        status="needs_clarification",
        conversation_id=conversation_id,
        question=state.get("question"),
        partial_intent=IntentParsed(**(state.get("intent") or {})),
    )


def _extract_state(result: dict, graph, config) -> dict:
    """Extract state from the graph result, including interrupt payloads.

    LangGraph stores interrupt values in the checkpoint's tasks, NOT in the
    invoke() return dict. We read the graph snapshot to get the question.
    """
    # First: check if graph completed normally (has status=completed)
    if result.get("status") == "completed":
        return result

    # Graph may have been interrupted — check the checkpoint for the question.
    try:
        snapshot = graph.get_state(config)
        if snapshot and snapshot.values:
            # Merge checkpoint values into result so we get the latest state.
            merged = {**result, **snapshot.values}

            # Extract question from interrupt payload in tasks.
            question = None
            for task in (snapshot.tasks or []):
                for intr in getattr(task, "interrupts", ()):
                    val = getattr(intr, "value", None)
                    if isinstance(val, dict) and val.get("question"):
                        question = val["question"]
                        break
                if question:
                    break

            if question:
                merged["question"] = question
                log.info("  extracted question from interrupt: %s", question[:100])
            else:
                log.warning("  no question found in interrupt tasks")

            return merged
    except Exception as e:
        log.warning("  checkpoint read failed: %s", e)

    return result


@router.post("", response_model=AgentRunOut)
def run_service_request(
    body: ServiceRequestIn,
    user: CurrentUser = Depends(get_current_user),
) -> AgentRunOut:
    graph = build_graph()

    if body.conversation_id:
        # Resume an existing paused conversation.
        cid = body.conversation_id
        config = {"configurable": {"thread_id": cid}}
        state_before = graph.get_state(config)
        if not state_before or not state_before.values:
            raise HTTPException(status.HTTP_404_NOT_FOUND, "Conversation not found")
        if state_before.values.get("user_id") != user.id:
            raise HTTPException(status.HTTP_403_FORBIDDEN, "Not your conversation")

        result = graph.invoke(
            Command(resume={"user_reply": body.text}),
            config=config,
        )
    else:
        cid = str(uuid.uuid4())
        config = {"configurable": {"thread_id": cid}}
        T.upsert_conversation.invoke(
            {"conversation_id": cid, "user_id": user.id, "status": "active"}
        )
        initial: dict = {
            "user_id": user.id,
            "conversation_id": cid,
            "input_text": body.text,
            "trace_steps": [],
            "clarify_rounds": 0,
            "clarification_context": [],
            "demo_offset_seconds": body.demo_offset_seconds,
        }
        result = graph.invoke(initial, config=config)

    state = _extract_state(result, graph, config)

    if state.get("status") == "completed":
        T.upsert_conversation.invoke(
            {"conversation_id": cid, "user_id": user.id, "status": "completed"}
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
        model = genai.GenerativeModel(settings.gemini_model)
        response = model.generate_content([
            "Transcribe the following audio accurately in its original language (e.g., Roman Urdu, Urdu, or English). Do not add any extra text, markdown formatting, or translation, just the raw transcription. If the audio is empty or you cannot hear anything, return nothing.",
            {"mime_type": file.content_type, "data": content}
        ])
        text = response.text.strip()
        log.info("Transcribed audio for user %s: %s", user.id, text)
        return {"text": text}
    except Exception as e:
        log.error("Audio transcription failed: %s", e)
        raise HTTPException(status.HTTP_500_INTERNAL_SERVER_ERROR, "Failed to transcribe audio")

