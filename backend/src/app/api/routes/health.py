"""Health check routes with instrumentation status."""

from fastapi import APIRouter

from src.app.core.config import get_settings
from src.app.schemas.health import DetailedHealthResponse, HealthResponse

# Import instrumentation health checks with graceful fallback
try:
    from src.app.core.instrumentation import instrumentation_health_check

    INSTRUMENTATION_AVAILABLE = True
except ImportError:

    def instrumentation_health_check():
        return {"status": "not_available"}

    INSTRUMENTATION_AVAILABLE = False

router = APIRouter(tags=["Health"])


@router.get("/health", response_model=HealthResponse)
async def health_check() -> HealthResponse:
    """Basic health check - backwards compatible."""
    settings = get_settings()

    # Include basic instrumentation status if available
    instrumentation_status = None
    langsmith_status = None

    if INSTRUMENTATION_AVAILABLE:
        health_info = instrumentation_health_check()
        instrumentation_status = {
            "prometheus_metrics": health_info.get("prometheus_metrics", "unknown"),
            "langsmith_available": health_info.get("langsmith_available", False),
        }
        langsmith_status = health_info.get("langsmith_status")

    return HealthResponse(
        status="healthy",
        version=settings.app_version,
        service=settings.app_name,
        instrumentation=instrumentation_status,
        langsmith=langsmith_status,
    )


@router.get("/health/detailed", response_model=DetailedHealthResponse)
async def detailed_health_check() -> DetailedHealthResponse:
    """Detailed health check with subsystem status."""
    settings = get_settings()

    checks = {
        "app": {
            "status": "healthy",
            "version": settings.app_version,
            "environment": settings.app_env,
        }
    }

    # Add instrumentation checks
    if INSTRUMENTATION_AVAILABLE:
        checks["instrumentation"] = instrumentation_health_check()
    else:
        checks["instrumentation"] = {"status": "not_available"}

    # Add database checks (if using postgres)
    if settings.use_postgres:
        checks["database"] = {
            "status": "configured",
            "type": "postgresql",
            "url_configured": bool(settings.database_url),
        }
    else:
        checks["database"] = {
            "status": "sqlite",
            "type": "sqlite",
        }

    # Add feature flags status
    checks["features"] = {
        "postgres": settings.use_postgres,
        "async_tools": settings.use_async_tools,
        "langsmith_tracing": settings.use_langsmith_tracing,
    }

    # Add Ollama status
    checks["ollama"] = {
        "base_url": settings.ollama_base_url,
        "model": settings.ollama_model,
        "embedding_model": settings.ollama_embedding_model,
    }

    # Overall system status
    overall_status = "healthy"
    if checks["instrumentation"]["status"] == "error":
        overall_status = "degraded"

    return DetailedHealthResponse(
        status=overall_status,
        version=settings.app_version,
        service=settings.app_name,
        checks=checks,
    )


@router.get("/")
async def root() -> dict[str, str]:
    """Root endpoint."""
    return {"message": "Welcome to HRAS - Human Rights Advisory System"}
