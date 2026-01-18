"""Prometheus instrumentation wrappers for HRAS backend.

Provides wrapper functions to instrument LLM calls and vector searches
with Prometheus metrics. Kept separate from AILogger (structlog-based logging).
"""

import time
from typing import Any

from langchain_core.messages import BaseMessage

from src.app.core.config import get_settings
from src.app.core.metrics import (
    EMBEDDINGS_GENERATED_TOTAL,
    MODEL_INFERENCE_DURATION_SECONDS,
    MODEL_INFERENCE_TOTAL,
    MODEL_TOKENS_TOTAL,
    VECTOR_SEARCH_DURATION_SECONDS,
    VECTOR_SEARCH_RESULTS,
    VECTOR_SEARCH_TOTAL,
)


def extract_token_usage(response: BaseMessage) -> dict[str, int]:
    """Extract token usage from LLM response metadata.

    Ollama provides token counts in response_metadata or usage_metadata.

    Args:
        response: The LLM response message.

    Returns:
        Dictionary with input_tokens, output_tokens, and total_tokens.
    """
    usage: dict[str, int] = {}

    # Try usage_metadata first (LangChain standard)
    if hasattr(response, "usage_metadata") and response.usage_metadata:
        usage = {
            "input_tokens": response.usage_metadata.get("input_tokens", 0),
            "output_tokens": response.usage_metadata.get("output_tokens", 0),
            "total_tokens": response.usage_metadata.get("total_tokens", 0),
        }
    # Fallback to response_metadata (Ollama-specific)
    elif hasattr(response, "response_metadata") and response.response_metadata:
        meta = response.response_metadata
        input_tokens = meta.get("prompt_eval_count", 0)
        output_tokens = meta.get("eval_count", 0)
        usage = {
            "input_tokens": input_tokens,
            "output_tokens": output_tokens,
            "total_tokens": input_tokens + output_tokens,
        }

    return usage


def extract_model_name(response: BaseMessage, fallback: str) -> str:
    """Extract actual model name from response metadata.

    Args:
        response: The LLM response message.
        fallback: Fallback model name if not found in response.

    Returns:
        The model name string.
    """
    if hasattr(response, "response_metadata") and response.response_metadata:
        return response.response_metadata.get("model", fallback)
    return fallback


def record_llm_metrics(
    model: str,
    duration: float,
    success: bool,
    response: BaseMessage | None = None,
) -> None:
    """Record Prometheus metrics for an LLM inference call.

    Args:
        model: Model name for labeling.
        duration: Request duration in seconds.
        success: Whether the call succeeded.
        response: Optional LLM response for token extraction.
    """
    status = "success" if success else "error"

    MODEL_INFERENCE_TOTAL.labels(model=model, status=status).inc()
    MODEL_INFERENCE_DURATION_SECONDS.labels(model=model).observe(duration)

    if response and success:
        usage = extract_token_usage(response)
        if usage.get("input_tokens"):
            MODEL_TOKENS_TOTAL.labels(model=model, type="input").inc(usage["input_tokens"])
        if usage.get("output_tokens"):
            MODEL_TOKENS_TOTAL.labels(model=model, type="output").inc(usage["output_tokens"])


def record_vector_search_metrics(
    duration: float,
    success: bool,
    num_results: int = 0,
) -> None:
    """Record Prometheus metrics for a vector search operation.

    Args:
        duration: Search duration in seconds.
        success: Whether the search succeeded.
        num_results: Number of results returned.
    """
    status = "success" if success else "error"

    VECTOR_SEARCH_TOTAL.labels(status=status).inc()
    VECTOR_SEARCH_DURATION_SECONDS.observe(duration)

    if success:
        VECTOR_SEARCH_RESULTS.observe(num_results)


def record_embeddings_generated(count: int = 1) -> None:
    """Record embeddings generation metric.

    Args:
        count: Number of embeddings generated.
    """
    EMBEDDINGS_GENERATED_TOTAL.inc(count)


async def instrumented_llm_invoke(
    llm: Any,
    messages: list[BaseMessage],
    model_name: str | None = None,
) -> BaseMessage:
    """Invoke LLM with automatic Prometheus metrics recording.

    Args:
        llm: The LangChain LLM instance.
        messages: Messages to send to the LLM.
        model_name: Optional model name override (defaults to settings).

    Returns:
        The LLM response message.

    Raises:
        Exception: Re-raises any exception from the LLM call after recording metrics.
    """
    settings = get_settings()
    fallback_model = model_name or settings.ollama_model

    start_time = time.perf_counter()
    try:
        response = await llm.ainvoke(messages)
        duration = time.perf_counter() - start_time

        # Try to get actual model name from response
        actual_model = extract_model_name(response, fallback_model)
        record_llm_metrics(actual_model, duration, success=True, response=response)

        return response
    except Exception:
        duration = time.perf_counter() - start_time
        record_llm_metrics(fallback_model, duration, success=False)
        raise
