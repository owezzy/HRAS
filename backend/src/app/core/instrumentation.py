"""Enhanced instrumentation wrappers for HRAS backend.

Combines Prometheus metrics collection with LangSmith tracing for comprehensive
observability. Maintains backward compatibility with existing metrics while
adding detailed trace visualization for multi-agent workflows.

Design Principles:
- Additive: LangSmith complements, doesn't replace Prometheus
- Graceful degradation: Works even if LangSmith is unavailable
- Performance: Minimal overhead with sampling-based tracing
- Privacy: Automatic sanitization of sensitive data
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

# Import LangSmith tracing (with graceful fallback)
try:
    from src.app.core.tracing import (
        TracingConfig,
        create_child_run,
        end_child_run,
        should_trace,
        trace_llm_call,
    )

    LANGSMITH_AVAILABLE = True
except ImportError:
    LANGSMITH_AVAILABLE = False

    # Fallback stubs if tracing module isn't available
    def should_trace() -> bool:
        return False

    async def trace_llm_call(*args, **kwargs) -> None:
        pass

    def create_child_run(*args, **kwargs) -> Any:  # noqa: ARG001
        return None

    async def end_child_run(*args, **kwargs) -> None:
        pass

    class TracingConfig:
        @staticmethod
        def sanitize_input(text: str) -> str:
            return text


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
    trace_metadata: dict[str, Any] | None = None,
) -> BaseMessage:
    """Invoke LLM with automatic Prometheus metrics and LangSmith tracing.

    Enhanced version that maintains all existing Prometheus metrics while
    adding optional LangSmith tracing for detailed observability.

    Args:
        llm: The LangChain LLM instance.
        messages: Messages to send to the LLM.
        model_name: Optional model name override (defaults to settings).
        trace_metadata: Optional metadata for LangSmith trace.

    Returns:
        The LLM response message.

    Raises:
        Exception: Re-raises any exception from the LLM call after recording metrics.
    """
    settings = get_settings()
    fallback_model = model_name or settings.ollama_model

    start_time = time.perf_counter()

    try:
        # Make the LLM call
        response = await llm.ainvoke(messages)
        duration = time.perf_counter() - start_time
        duration_ms = duration * 1000

        # Extract actual model name from response
        actual_model = extract_model_name(response, fallback_model)

        # Record Prometheus metrics (existing functionality)
        record_llm_metrics(actual_model, duration, success=True, response=response)

        # Add LangSmith tracing (new functionality)
        if LANGSMITH_AVAILABLE and should_trace():
            await trace_llm_call(
                model_name=actual_model,
                messages=messages,
                response=response,
                duration_ms=duration_ms,
                metadata=trace_metadata,
            )

        return response

    except Exception:
        duration = time.perf_counter() - start_time

        # Record failure metrics
        record_llm_metrics(fallback_model, duration, success=False)

        # Note: LangSmith will automatically capture exceptions if tracing is active
        raise


async def instrumented_vector_search(
    search_func: Any,
    query: str,
    k: int = 5,
    trace_metadata: dict[str, Any] | None = None,
) -> list[Any]:
    """Perform vector search with automatic metrics and tracing.

    Args:
        search_func: The vector search function to call
        query: Search query text
        k: Number of results to return
        trace_metadata: Optional metadata for LangSmith trace

    Returns:
        List of search results

    Raises:
        Exception: Re-raises any exception from the search after recording metrics.
    """
    start_time = time.perf_counter()

    child_run = None
    if LANGSMITH_AVAILABLE and should_trace():
        sanitized_query = TracingConfig.sanitize_input(query)
        child_run = create_child_run(
            name="vector_search",
            run_type="retriever",
            inputs={
                "query": sanitized_query,
                "k": k,
            },
            metadata=trace_metadata,
        )
    else:
        sanitized_query = query

    try:
        results = await search_func(sanitized_query, k=k)
        duration = time.perf_counter() - start_time
        duration_ms = duration * 1000

        record_vector_search_metrics(duration=duration, success=True, num_results=len(results))

        if child_run is not None:
            top_scores: list[float] = []
            countries_found: set[str] = set()
            mechanisms_found: set[str] = set()

            for result in results:
                if hasattr(result, "metadata"):
                    if "score" in result.metadata:
                        top_scores.append(result.metadata["score"])
                    if "country" in result.metadata:
                        countries_found.add(result.metadata["country"])
                    if "mechanism" in result.metadata:
                        mechanisms_found.add(result.metadata["mechanism"])

            outputs = {
                "num_results": len(results),
                "duration_ms": duration_ms,
                "top_scores": top_scores[:5],
                "countries_found": list(countries_found),
                "mechanisms_found": list(mechanisms_found),
            }
            await end_child_run(child_run, outputs=outputs)

        return results

    except Exception as e:
        duration = time.perf_counter() - start_time

        record_vector_search_metrics(duration=duration, success=False)

        if child_run is not None:
            await end_child_run(child_run, error=str(e))

        raise


async def instrumented_embeddings_generate(
    embed_func: Any,
    texts: list[str],
    trace_metadata: dict[str, Any] | None = None,
) -> list[list[float]]:
    """Generate embeddings with automatic metrics recording.

    Args:
        embed_func: The embedding function to call
        texts: List of texts to embed
        trace_metadata: Optional metadata for tracing

    Returns:
        List of embedding vectors

    Raises:
        Exception: Re-raises any exception after recording metrics.
    """
    settings = get_settings()
    start_time = time.perf_counter()

    child_run = None
    sanitized_texts = texts
    if LANGSMITH_AVAILABLE and should_trace():
        sanitized_texts = [TracingConfig.sanitize_input(text) for text in texts]
        avg_text_length = sum(len(t) for t in texts) / len(texts) if texts else 0
        child_run = create_child_run(
            name="embeddings_generate",
            run_type="embedding",
            inputs={
                "text_count": len(texts),
                "avg_text_length": avg_text_length,
                "model": settings.ollama_embedding_model,
            },
            metadata=trace_metadata,
        )

    try:
        embeddings = embed_func(sanitized_texts)
        duration_ms = (time.perf_counter() - start_time) * 1000

        record_embeddings_generated(count=len(texts))

        if child_run is not None:
            vector_dimensions = len(embeddings[0]) if embeddings else 0
            outputs = {
                "embeddings_generated": len(embeddings),
                "vector_dimensions": vector_dimensions,
                "duration_ms": duration_ms,
            }
            await end_child_run(child_run, outputs=outputs)

        return embeddings

    except Exception as e:
        if child_run is not None:
            await end_child_run(child_run, error=str(e))
        raise


# Health check for instrumentation
def instrumentation_health_check() -> dict[str, Any]:
    """Check instrumentation system health.

    Returns:
        Dictionary with health status of metrics and tracing systems
    """
    health_info = {
        "prometheus_metrics": "healthy",  # Always available
        "langsmith_available": LANGSMITH_AVAILABLE,
    }

    if LANGSMITH_AVAILABLE:
        try:
            from src.app.core.tracing import langsmith_health_check

            health_info["langsmith_status"] = langsmith_health_check()
        except Exception as e:
            health_info["langsmith_status"] = f"error: {str(e)}"
    else:
        health_info["langsmith_status"] = "not_installed"

    return health_info


# Backward compatibility aliases
# These ensure existing code continues to work without changes
llm_invoke = instrumented_llm_invoke  # Legacy alias
vector_search = instrumented_vector_search  # Legacy alias
