"""Pytest configuration and fixtures for HRAS backend tests."""

# Disable LangSmith tracing during tests to avoid async event loop issues
# This MUST happen before any imports that read settings
import os

os.environ["USE_LANGSMITH_TRACING"] = "false"

os.environ.setdefault("LLM_API_KEY", "test-key")

from collections.abc import AsyncGenerator
from typing import Any
from unittest.mock import MagicMock, patch
from uuid import uuid4

import pytest
from fastapi import FastAPI
from httpx import ASGITransport, AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

from src.app.main import create_app
from src.app.models.conversation import Base


@pytest.fixture
def app() -> FastAPI:
    """Create a test FastAPI application."""
    return create_app()


@pytest.fixture
async def client(app: FastAPI) -> AsyncGenerator[AsyncClient, None]:
    """Create an async HTTP client for testing."""
    async with AsyncClient(
        transport=ASGITransport(app=app),
        base_url="http://test",
    ) as ac:
        yield ac


@pytest.fixture
async def db_engine():
    engine = create_async_engine("sqlite+aiosqlite:///:memory:", echo=False)
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    yield engine
    await engine.dispose()


@pytest.fixture
async def db_session(db_engine) -> AsyncGenerator[AsyncSession, None]:
    session_factory = async_sessionmaker(db_engine, expire_on_commit=False)
    async with session_factory() as session:
        yield session
        await session.rollback()


@pytest.fixture
def mock_vector_store() -> MagicMock:
    """Create a mock VectorStoreManager."""
    mock = MagicMock()
    mock.get_collection_stats.return_value = {"name": "uhri", "count": 100}
    mock.add_documents.return_value = [str(uuid4()) for _ in range(10)]
    mock.clear_collection.return_value = None
    return mock


@pytest.fixture
def mock_empty_vector_store() -> MagicMock:
    """Create a mock VectorStoreManager with no documents."""
    mock = MagicMock()
    mock.get_collection_stats.return_value = {"name": "uhri", "count": 0}
    return mock


@pytest.fixture
def mock_rag_chain() -> MagicMock:
    """Create a mock RAG chain."""
    mock = MagicMock()
    mock.invoke_with_sources = MagicMock(
        return_value={
            "answer": "This is a test response about human rights.",
            "sources": [
                {
                    "title": "UPR Recommendation 2021",
                    "document_type": "UPR",
                    "country": "Kenya",
                    "year": 2021,
                    "excerpt": "Test excerpt",
                }
            ],
        }
    )
    return mock


@pytest.fixture
def mock_agent_workflow() -> dict[str, Any]:
    """Create a mock response from the agent workflow."""
    return {
        "answer": "Based on the UN Human Rights Index, here is the response.",
        "sources": [
            {
                "title": "UHRI Document",
                "document_type": "Treaty Body",
                "country": "Global",
                "year": 2023,
                "excerpt": "Sample excerpt from UHRI",
            }
        ],
    }


@pytest.fixture
def mock_document_loader() -> MagicMock:
    """Create a mock UHRIDocumentLoader."""
    from langchain_core.documents import Document

    mock = MagicMock()
    mock.load = MagicMock(
        return_value=[
            Document(
                page_content="Human rights recommendation content",
                metadata={"title": "Test Doc", "country": "Kenya", "year": 2021},
            )
            for _ in range(10)
        ]
    )
    return mock


@pytest.fixture
def patch_services(
    mock_vector_store: MagicMock,
    mock_rag_chain: MagicMock,
    mock_agent_workflow: dict[str, Any],
) -> None:
    """Patch services to avoid external dependencies during testing."""
    with (
        patch("src.app.services.chat_service.get_vector_store", return_value=mock_vector_store),
        patch("src.app.services.chat_service.get_rag_chain", return_value=mock_rag_chain),
        patch("src.app.services.chat_service.run_agent_workflow", return_value=mock_agent_workflow),
    ):
        # Reset singleton services
        import src.app.services.chat_service as chat_service_module

        chat_service_module._chat_service = None
        chat_service_module._ingestion_service = None
        yield
        chat_service_module._chat_service = None
        chat_service_module._ingestion_service = None
