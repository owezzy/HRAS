"""Structured logging configuration for HRAS backend."""

import logging
import sys
from contextvars import ContextVar
from typing import Any
from uuid import uuid4

import structlog
from structlog.types import Processor

from src.app.core.config import get_settings

request_id_ctx: ContextVar[str | None] = ContextVar("request_id", default=None)
user_id_ctx: ContextVar[str | None] = ContextVar("user_id", default=None)


def add_request_context(
    logger: logging.Logger,
    method_name: str,
    event_dict: dict[str, Any],
) -> dict[str, Any]:
    """Add request context to log entries."""
    request_id = request_id_ctx.get()
    user_id = user_id_ctx.get()
    
    if request_id:
        event_dict["request_id"] = request_id
    if user_id:
        event_dict["user_id"] = user_id
    
    return event_dict


def add_app_context(
    logger: logging.Logger,
    method_name: str,
    event_dict: dict[str, Any],
) -> dict[str, Any]:
    """Add application context to log entries."""
    settings = get_settings()
    event_dict["service"] = "hras-backend"
    event_dict["version"] = settings.app_version
    event_dict["environment"] = "production" if not settings.debug else "development"
    return event_dict


def setup_logging() -> None:
    """Configure structured logging for the application."""
    settings = get_settings()
    
    log_level = logging.DEBUG if settings.debug else logging.INFO
    
    shared_processors: list[Processor] = [
        structlog.contextvars.merge_contextvars,
        structlog.stdlib.add_logger_name,
        structlog.stdlib.add_log_level,
        structlog.stdlib.PositionalArgumentsFormatter(),
        structlog.processors.TimeStamper(fmt="iso"),
        structlog.processors.StackInfoRenderer(),
        structlog.processors.UnicodeDecoder(),
        add_request_context,
        add_app_context,
    ]
    
    if settings.debug:
        processors: list[Processor] = [
            *shared_processors,
            structlog.dev.ConsoleRenderer(colors=True),
        ]
    else:
        processors = [
            *shared_processors,
            structlog.processors.format_exc_info,
            structlog.processors.JSONRenderer(),
        ]
    
    structlog.configure(
        processors=processors,
        wrapper_class=structlog.stdlib.BoundLogger,
        context_class=dict,
        logger_factory=structlog.stdlib.LoggerFactory(),
        cache_logger_on_first_use=True,
    )
    
    logging.basicConfig(
        format="%(message)s",
        stream=sys.stdout,
        level=log_level,
    )
    
    for logger_name in ["uvicorn", "uvicorn.access", "uvicorn.error"]:
        logging.getLogger(logger_name).handlers = []
        logging.getLogger(logger_name).propagate = True


def get_logger(name: str | None = None) -> structlog.stdlib.BoundLogger:
    """Get a structured logger instance."""
    return structlog.get_logger(name)


def generate_request_id() -> str:
    """Generate a unique request ID."""
    return str(uuid4())


class SecurityLogger:
    """Security-focused logger for audit trails."""
    
    def __init__(self) -> None:
        self.logger = get_logger("security")
    
    def log_auth_attempt(
        self,
        success: bool,
        user_id: str | None = None,
        ip_address: str | None = None,
        reason: str | None = None,
    ) -> None:
        """Log authentication attempt."""
        self.logger.info(
            "auth_attempt",
            success=success,
            user_id=user_id,
            ip_address=ip_address,
            reason=reason,
            event_type="security.auth",
        )
    
    def log_data_access(
        self,
        resource_type: str,
        resource_id: str,
        action: str,
        user_id: str | None = None,
    ) -> None:
        """Log data access for audit trail."""
        self.logger.info(
            "data_access",
            resource_type=resource_type,
            resource_id=resource_id,
            action=action,
            user_id=user_id,
            event_type="security.data_access",
        )
    
    def log_sensitive_operation(
        self,
        operation: str,
        details: dict[str, Any] | None = None,
    ) -> None:
        """Log sensitive operations."""
        self.logger.warning(
            "sensitive_operation",
            operation=operation,
            details=details or {},
            event_type="security.sensitive",
        )


class AILogger:
    """AI/ML-focused logger for RAG pipeline monitoring."""
    
    def __init__(self) -> None:
        self.logger = get_logger("ai")
    
    def log_inference(
        self,
        model: str,
        latency_ms: float,
        token_count: int | None = None,
        success: bool = True,
        error: str | None = None,
    ) -> None:
        """Log model inference metrics."""
        self.logger.info(
            "model_inference",
            model=model,
            latency_ms=latency_ms,
            token_count=token_count,
            success=success,
            error=error,
            event_type="ai.inference",
        )
    
    def log_retrieval(
        self,
        query: str,
        num_results: int,
        latency_ms: float,
        relevance_scores: list[float] | None = None,
    ) -> None:
        """Log vector retrieval metrics."""
        self.logger.info(
            "vector_retrieval",
            query_length=len(query),
            num_results=num_results,
            latency_ms=latency_ms,
            avg_relevance=sum(relevance_scores) / len(relevance_scores) if relevance_scores else None,
            event_type="ai.retrieval",
        )
    
    def log_agent_execution(
        self,
        agent_name: str,
        execution_time_ms: float,
        steps_count: int,
        success: bool = True,
        error: str | None = None,
    ) -> None:
        """Log agent workflow execution."""
        self.logger.info(
            "agent_execution",
            agent_name=agent_name,
            execution_time_ms=execution_time_ms,
            steps_count=steps_count,
            success=success,
            error=error,
            event_type="ai.agent",
        )


security_logger = SecurityLogger()
ai_logger = AILogger()
