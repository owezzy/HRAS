"""LangSmith tracing integration for HRAS.

Provides utilities for instrumenting multi-agent workflows with LangSmith
for monitoring, evaluation, and debugging. Designed to complement existing
Prometheus metrics without replacement.

Key Features:
- Feature flag controlled rollout (use_langsmith_tracing)
- Input sanitization for government/UN context
- Graceful degradation if LangSmith API unavailable
- Session-based trace grouping for multi-agent workflows
- Hierarchical parent-child run tracing for multi-agent workflows
"""

import asyncio
import contextlib
import hashlib
import re
from collections.abc import Callable
from contextvars import ContextVar
from functools import wraps
from typing import Any, Literal, cast
from uuid import uuid4

from langchain_core.messages import BaseMessage
from langchain_core.tracers import LangChainTracer
from langsmith import Client, traceable
from langsmith.run_trees import RunTree

from src.app.core.config import get_settings
from src.app.core.logging import get_logger

logger = get_logger(__name__)

# Context variable to store current trace session ID
_trace_session_id: ContextVar[str | None] = ContextVar("trace_session_id", default=None)

_parent_run_tree: ContextVar[RunTree | None] = ContextVar("parent_run_tree", default=None)

# Global LangSmith client (initialized lazily)
_langsmith_client: Client | None = None


def get_parent_run() -> RunTree | None:
    return _parent_run_tree.get()


def set_parent_run(run: RunTree | None) -> Any:
    return _parent_run_tree.set(run)


def reset_parent_run(token: Any) -> None:
    _parent_run_tree.reset(token)


@contextlib.asynccontextmanager
async def parent_run_context(
    name: str,
    run_type: str = "chain",
    inputs: dict[str, Any] | None = None,
    metadata: dict[str, Any] | None = None,
):
    if not should_trace():
        yield None
        return

    settings = get_settings()
    parent_run = RunTree(
        name=name,
        run_type=run_type,
        inputs=inputs or {},
        project_name=settings.langsmith_project,
        extra=metadata or {},
    )
    parent_run.post()

    token = set_parent_run(parent_run)
    try:
        yield parent_run
    except Exception as e:
        parent_run.end(error=str(e))
        parent_run.patch()
        raise
    finally:
        reset_parent_run(token)


async def end_parent_run(parent_run: RunTree, outputs: dict[str, Any] | None = None) -> None:
    if parent_run is None:
        return
    try:
        parent_run.end(outputs=outputs or {})
        parent_run.patch()
    except Exception as e:
        logger.warning("failed_to_end_parent_run", error=str(e))


def create_child_run(
    name: str,
    run_type: str = "chain",
    inputs: dict[str, Any] | None = None,
    metadata: dict[str, Any] | None = None,
) -> RunTree | None:
    parent = get_parent_run()
    if parent is None:
        return None

    try:
        child = parent.create_child(
            name=name,
            run_type=run_type,
            inputs=inputs or {},
            extra=metadata or {},
        )
        child.post()
        return child
    except Exception as e:
        logger.warning("failed_to_create_child_run", error=str(e), name=name)
        return None


async def end_child_run(
    child_run: RunTree | None,
    outputs: dict[str, Any] | None = None,
    error: str | None = None,
) -> None:
    if child_run is None:
        return
    try:
        if error:
            child_run.end(error=error)
        else:
            child_run.end(outputs=outputs or {})
        child_run.patch()
    except Exception as e:
        logger.warning("failed_to_end_child_run", error=str(e))


class TracingConfig:
    """Configuration for LangSmith tracing with privacy controls."""

    # Patterns to sanitize from inputs/outputs
    SENSITIVE_PATTERNS = [
        r"\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b",  # Email addresses
        r"\b\d{4}[-\s]?\d{4}[-\s]?\d{4}[-\s]?\d{4}\b",  # Credit card numbers
        r"\b\d{3}-\d{2}-\d{4}\b",  # SSN format
        r"\bBearer\s+[A-Za-z0-9\-._~+/]+=*\b",  # Bearer tokens
        r'\bAPI[_-]?[Kk]ey\s*[:=]\s*[\'"]?[A-Za-z0-9\-._~+/=]+[\'"]?',  # API keys
    ]

    # Countries that require extra privacy (can be configured)
    HIGH_PRIVACY_COUNTRIES = {"china", "russia", "iran", "north korea", "myanmar", "belarus"}

    @classmethod
    def should_sanitize_country(cls, text: str) -> bool:
        """Check if text mentions high-privacy countries."""
        text_lower = text.lower()
        return any(country in text_lower for country in cls.HIGH_PRIVACY_COUNTRIES)

    @classmethod
    def sanitize_input(cls, text: str) -> str:
        """Sanitize sensitive information from text input."""
        if not text:
            return text

        sanitized = text

        # Replace sensitive patterns
        for pattern in cls.SENSITIVE_PATTERNS:
            sanitized = re.sub(pattern, "[REDACTED]", sanitized, flags=re.IGNORECASE)

        # Extra sanitization for high-privacy countries
        if cls.should_sanitize_country(sanitized):
            # Hash country names for high-privacy countries
            for country in cls.HIGH_PRIVACY_COUNTRIES:
                if country in sanitized.lower():
                    country_hash = hashlib.sha256(country.encode()).hexdigest()[:8]
                    sanitized = re.sub(re.escape(country), f"[COUNTRY_{country_hash}]", sanitized, flags=re.IGNORECASE)

        return sanitized


def get_langsmith_client() -> Client | None:
    """Get or create LangSmith client with lazy initialization."""
    global _langsmith_client

    if _langsmith_client is not None:
        return _langsmith_client

    settings = get_settings()

    # Only initialize if tracing is enabled and API key is available
    if not settings.use_langsmith_tracing or not settings.langsmith_api_key:
        return None

    try:
        _langsmith_client = Client(
            api_url=settings.langsmith_endpoint,
            api_key=settings.langsmith_api_key,
        )

        # Test connection (info is a property, not a method)
        _ = _langsmith_client.info
        logger.info("langsmith_client_initialized", project=settings.langsmith_project)
        return _langsmith_client

    except Exception as e:
        logger.warning("langsmith_client_initialization_failed", error=str(e))
        return None


def should_trace() -> bool:
    """Determine if current request should be traced."""
    settings = get_settings()

    if not settings.use_langsmith_tracing:
        return False

    return bool(get_langsmith_client())


@contextlib.asynccontextmanager
async def langsmith_trace_session(
    session_name: str,
    metadata: dict[str, Any] | None = None,  # noqa: ARG001
):
    """Context manager for LangSmith trace sessions.

    Groups related traces (e.g., multi-agent workflow) under a session ID.

    Args:
        session_name: Human-readable session name
        metadata: Optional metadata to attach to all traces in session

    Example:
        async with langsmith_trace_session("user_query_123") as session_id:
            # All traces within this context will be grouped
            result = await run_agent_workflow(question)
    """
    if not should_trace():
        yield None
        return

    session_id = str(uuid4())
    session_token = _trace_session_id.set(session_id)

    try:
        logger.debug("langsmith_session_started", session_id=session_id, session_name=session_name)
        yield session_id
    finally:
        _trace_session_id.reset(session_token)
        logger.debug("langsmith_session_ended", session_id=session_id, session_name=session_name)


RunType = Literal["tool", "chain", "llm", "retriever", "embedding", "prompt", "parser"]


def hras_traceable(
    name: str | None = None,
    *,
    run_type: RunType = "chain",
    sanitize_inputs: bool = True,
    include_metadata: bool = True,  # noqa: ARG001
):
    """HRAS-specific @traceable decorator with privacy controls.

    Args:
        name: Optional name override for the trace
        run_type: Type of run (chain, llm, tool, agent)
        sanitize_inputs: Whether to sanitize sensitive data from inputs
        include_metadata: Whether to include system metadata

    Example:
        @hras_traceable(name="research_agent", run_type="agent")
        async def research_agent(state: AgentState) -> AgentState:
            ...
    """

    def decorator(func: Callable) -> Callable:
        trace_name = name or f"{func.__module__}.{func.__name__}"

        traced_func = traceable(
            name=trace_name,
            run_type=cast(RunType, run_type),
            project_name=get_settings().langsmith_project,
        )(func)

        @wraps(func)
        async def async_wrapper(*args, **kwargs):
            # Check if tracing should happen for this call
            if not should_trace():
                return await func(*args, **kwargs)

            client = get_langsmith_client()
            if not client:
                return await func(*args, **kwargs)

            # Sanitize inputs if enabled
            sanitized_kwargs = kwargs.copy()
            if sanitize_inputs:
                for key, value in sanitized_kwargs.items():
                    if isinstance(value, str):
                        sanitized_kwargs[key] = TracingConfig.sanitize_input(value)
                    elif hasattr(value, "question") and isinstance(value.question, str):
                        value.question = TracingConfig.sanitize_input(value.question)

            return await traced_func(*args, **sanitized_kwargs)

        @wraps(func)
        def sync_wrapper(*args, **kwargs):
            # Check if tracing should happen for this call
            if not should_trace():
                return func(*args, **kwargs)

            client = get_langsmith_client()
            if not client:
                return func(*args, **kwargs)

            # Sanitize inputs if enabled
            sanitized_kwargs = kwargs.copy()
            if sanitize_inputs:
                for key, value in sanitized_kwargs.items():
                    if isinstance(value, str):
                        sanitized_kwargs[key] = TracingConfig.sanitize_input(value)

            return traced_func(*args, **sanitized_kwargs)

        if asyncio.iscoroutinefunction(func):
            return async_wrapper
        else:
            return sync_wrapper

    return decorator


def get_langchain_tracer() -> LangChainTracer | None:
    """Get LangChain tracer for use with LCEL chains.

    Returns:
        LangChainTracer instance or None if tracing disabled

    Example:
        tracer = get_langchain_tracer()
        if tracer:
            chain = prompt | llm | output_parser
            result = await chain.ainvoke(inputs, config={"callbacks": [tracer]})
    """
    if not should_trace():
        return None

    client = get_langsmith_client()
    if not client:
        return None

    return LangChainTracer(
        project_name=get_settings().langsmith_project,
        client=client,
    )


async def trace_llm_call(
    model_name: str,
    messages: list[BaseMessage],
    response: BaseMessage,
    duration_ms: float,
    metadata: dict[str, Any] | None = None,
) -> None:
    """Manually trace an LLM call to LangSmith.

    Use this for LLM calls that aren't automatically traced by decorators.

    Args:
        model_name: Name of the LLM model
        messages: Input messages
        response: LLM response
        duration_ms: Call duration in milliseconds
        metadata: Optional additional metadata
    """
    if not should_trace():
        return

    if not get_langsmith_client():
        return

    try:
        # Sanitize message content
        sanitized_messages = []
        for msg in messages:
            content = msg.content
            if isinstance(content, str):
                content = TracingConfig.sanitize_input(content)
            sanitized_messages.append(type(msg)(content=content))

        # Sanitize response content
        response_content = response.content
        if isinstance(response_content, str):
            response_content = TracingConfig.sanitize_input(response_content)

        trace_metadata = {
            "model_name": model_name,
            "duration_ms": duration_ms,
            "session_id": _trace_session_id.get(),
        }
        if metadata:
            trace_metadata.update(metadata)

        run = RunTree(
            name=f"llm_call_{model_name}",
            run_type="llm",
            inputs={"messages": [msg.model_dump() for msg in sanitized_messages]},
            project_name=get_settings().langsmith_project,
            extra=trace_metadata,
        )
        run.post()
        run.end(outputs={"response": response_content})
        run.patch()

        logger.debug("llm_call_traced", run_id=str(run.id), model=model_name)

    except Exception as e:
        logger.warning("llm_trace_failed", error=str(e), model=model_name)


# Health check function for monitoring
def langsmith_health_check() -> dict[str, Any]:
    """Check LangSmith integration health.

    Returns:
        Dictionary with health status and configuration info
    """
    settings = get_settings()

    health_info = {
        "tracing_enabled": settings.use_langsmith_tracing,
        "api_key_configured": bool(settings.langsmith_api_key),
        "project": settings.langsmith_project,
        "client_initialized": _langsmith_client is not None,
    }

    if settings.use_langsmith_tracing and settings.langsmith_api_key:
        try:
            client = get_langsmith_client()
            if client:
                _ = client.info  # property access tests API connectivity
                health_info["api_connectivity"] = "healthy"
            else:
                health_info["api_connectivity"] = "failed_initialization"
        except Exception as e:
            health_info["api_connectivity"] = f"error: {str(e)}"
    else:
        health_info["api_connectivity"] = "disabled"

    return health_info
