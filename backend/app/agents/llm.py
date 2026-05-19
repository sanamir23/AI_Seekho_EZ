"""Gemini chat client with timeouts, retries, and a fast-model variant.

`get_llm()` returns the default model. `get_llm(fast=True)` returns the
Flash variant — use it for short formatting / clarification calls where the
extra ms isn't worth the cost.
"""
from functools import lru_cache

from langchain_google_genai import ChatGoogleGenerativeAI

from app.config import get_settings

# Tenacity retry config: 3 attempts, 0.5/1.0s exponential backoff.
_RETRY_ATTEMPTS = 3
_TIMEOUT_S = 12.0


@lru_cache
def _build(model: str, temperature: float) -> ChatGoogleGenerativeAI:
    s = get_settings()
    return ChatGoogleGenerativeAI(
        model=model,
        google_api_key=s.gemini_api_key,
        temperature=temperature,
        timeout=_TIMEOUT_S,
        max_retries=_RETRY_ATTEMPTS,
    )


def get_llm(temperature: float = 0.2, fast: bool = False) -> ChatGoogleGenerativeAI:
    s = get_settings()
    model = (s.gemini_fast_model or s.gemini_model) if fast else s.gemini_model
    return _build(model, temperature)
