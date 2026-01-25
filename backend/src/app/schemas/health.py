"""Health check schemas."""

from typing import Any

from pydantic import BaseModel


class HealthResponse(BaseModel):
    """Health check response schema."""

    status: str
    version: str
    service: str
    instrumentation: dict[str, Any] | None = None
    langsmith: dict[str, Any] | None = None


class DetailedHealthResponse(BaseModel):
    """Detailed health check response with subsystem status."""

    status: str
    version: str
    service: str
    checks: dict[str, dict[str, Any]]
