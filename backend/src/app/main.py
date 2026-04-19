"""HRAS FastAPI Application."""

from collections.abc import AsyncGenerator
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.trustedhost import TrustedHostMiddleware
from prometheus_client import make_asgi_app

from src.app.api.routes import admin, chat, conversations, health
from src.app.core.config import get_settings
from src.app.core.logging import get_logger, setup_logging
from src.app.core.metrics import VECTORSTORE_DOCUMENTS, init_app_info
from src.app.middleware.logging import RequestLoggingMiddleware
from src.app.middleware.metrics import PrometheusMiddleware
from src.app.middleware.security import SecurityHeadersMiddleware

logger = get_logger(__name__)


@asynccontextmanager
async def lifespan(_app: FastAPI) -> AsyncGenerator[None, None]:
    settings = get_settings()

    setup_logging()
    init_app_info(
        version=settings.app_version,
        environment="production" if settings.is_production else "development",
    )

    logger.info(
        "application_started",
        app_name=settings.app_name,
        version=settings.app_version,
        debug=settings.debug,
        environment=settings.app_env,
    )

    logger.info(
        "feature_flags",
        use_postgres=settings.use_postgres,
        use_async_tools=settings.use_async_tools,
    )

    # Initialize vectorstore document count metric from actual store
    try:
        from src.app.ai.vectorstore.store import get_vector_store

        vector_store = get_vector_store()
        stats = vector_store.get_collection_stats()
        VECTORSTORE_DOCUMENTS.set(stats["count"])
        logger.info("vectorstore_metrics_initialized", document_count=stats["count"])
    except Exception as e:
        logger.warning("vectorstore_metrics_init_failed", error=str(e))

    yield

    logger.info("application_shutdown")


def create_app() -> FastAPI:
    settings = get_settings()

    docs_url = "/docs" if settings.docs_enabled else None
    redoc_url = "/redoc" if settings.docs_enabled else None
    openapi_url = "/openapi.json" if settings.docs_enabled else None

    app = FastAPI(
        title=settings.app_name,
        version=settings.app_version,
        description="AI-powered Human Rights Advisory System for UN officers",
        lifespan=lifespan,
        docs_url=docs_url,
        redoc_url=redoc_url,
        openapi_url=openapi_url,
    )

    app.add_middleware(SecurityHeadersMiddleware)
    app.add_middleware(RequestLoggingMiddleware)
    app.add_middleware(PrometheusMiddleware)

    if settings.is_production:
        app.add_middleware(
            TrustedHostMiddleware,
            allowed_hosts=settings.trusted_hosts,
        )

    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.cors_origins,
        allow_credentials=settings.cors_allow_credentials,
        allow_methods=settings.cors_allow_methods,
        allow_headers=settings.cors_allow_headers,
        expose_headers=["X-Request-ID"],
        max_age=3600,
    )

    app.include_router(health.router)
    app.include_router(chat.router, prefix="/api/v1")
    app.include_router(admin.router, prefix="/api/v1")
    app.include_router(conversations.router, prefix="/api/v1")

    metrics_app = make_asgi_app()
    app.mount("/metrics", metrics_app)

    return app


app = create_app()
