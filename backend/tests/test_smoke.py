"""Baseline smoke tests to ensure current functionality is preserved.

These tests verify that all existing endpoints work correctly and serve
as a safety net before making any refactoring changes.
"""

from unittest.mock import AsyncMock, MagicMock, patch
from uuid import uuid4

import pytest
from httpx import ASGITransport, AsyncClient

from src.app.main import create_app


@pytest.fixture
def app():
    """Fresh app instance for each test."""
    return create_app()


@pytest.fixture
async def client(app):
    """Async HTTP client for testing."""
    async with AsyncClient(
        transport=ASGITransport(app=app),
        base_url="http://test",
    ) as ac:
        yield ac


class TestHealthEndpoints:
    """Health check endpoint tests."""

    async def test_health_returns_200(self, client: AsyncClient):
        response = await client.get("/health")

        assert response.status_code == 200

    async def test_health_response_schema(self, client: AsyncClient):
        response = await client.get("/health")
        data = response.json()

        assert "status" in data
        assert "version" in data
        assert "service" in data
        assert data["status"] == "healthy"

    async def test_root_returns_welcome_message(self, client: AsyncClient):
        response = await client.get("/")

        assert response.status_code == 200
        data = response.json()
        assert "message" in data
        assert "HRAS" in data["message"]


class TestChatEndpoint:
    """Chat endpoint tests (with mocked LLM/vectorstore)."""

    @pytest.fixture
    def _mock_services(self):
        """Patch external services for chat tests."""
        mock_vector_store = MagicMock()
        mock_vector_store.get_collection_stats.return_value = {"name": "uhri", "count": 100}

        mock_agent_result = {
            "answer": "Based on UHRI documents, human rights are fundamental.",
            "sources": [{"title": "Test Doc", "country": "Kenya"}],
        }

        with (
            patch("src.app.services.chat_service.get_vector_store", return_value=mock_vector_store),
            patch(
                "src.app.services.chat_service.run_agent_workflow",
                new_callable=AsyncMock,
                return_value=mock_agent_result,
            ),
            patch("src.app.services.chat_service._chat_service", None),
        ):
            yield

    async def test_chat_returns_200(self, client: AsyncClient, _mock_services):
        response = await client.post(
            "/api/v1/chat",
            json={"message": "What human rights recommendations exist for Kenya?"},
        )

        assert response.status_code == 200

    async def test_chat_response_schema(self, client: AsyncClient, _mock_services):
        response = await client.post(
            "/api/v1/chat",
            json={"message": "Tell me about human rights in Kenya"},
        )
        data = response.json()

        assert "conversation_id" in data
        assert "message" in data
        assert "sources" in data
        assert "role" in data["message"]
        assert "content" in data["message"]

    async def test_chat_with_conversation_id(self, client: AsyncClient, _mock_services):
        conversation_id = str(uuid4())
        response = await client.post(
            "/api/v1/chat",
            json={
                "message": "Continue our discussion",
                "conversation_id": conversation_id,
            },
        )

        assert response.status_code == 200
        data = response.json()
        assert data["conversation_id"] == conversation_id

    async def test_chat_empty_vectorstore_returns_helpful_message(self, client: AsyncClient):
        """When vectorstore is empty, should return a message about ingestion."""
        mock_empty_store = MagicMock()
        mock_empty_store.get_collection_stats.return_value = {"name": "uhri", "count": 0}

        with (
            patch("src.app.services.chat_service.get_vector_store", return_value=mock_empty_store),
            patch("src.app.services.chat_service._chat_service", None),
        ):
            response = await client.post(
                "/api/v1/chat",
                json={"message": "Test message"},
            )

            assert response.status_code == 200
            data = response.json()
            assert "ingestion" in data["message"]["content"].lower() or "ingest" in data["message"]["content"].lower()

    async def test_chat_rejects_empty_message(self, client: AsyncClient):
        response = await client.post(
            "/api/v1/chat",
            json={"message": ""},
        )

        assert response.status_code == 422  # Validation error


class TestAdminEndpoints:
    """Admin endpoint tests (with mocked vectorstore)."""

    @pytest.fixture
    def _mock_ingestion_services(self):
        """Patch services for admin tests."""
        mock_vector_store = MagicMock()
        mock_vector_store.get_collection_stats.return_value = {"name": "uhri", "count": 50}
        mock_vector_store.add_documents.return_value = [str(uuid4()) for _ in range(10)]
        mock_vector_store.clear_collection.return_value = None

        mock_loader = MagicMock()
        mock_loader.load = AsyncMock(return_value=[MagicMock() for _ in range(10)])

        with (
            patch("src.app.services.chat_service.get_vector_store", return_value=mock_vector_store),
            patch("src.app.services.chat_service.UHRIDocumentLoader", return_value=mock_loader),
            patch("src.app.services.chat_service._ingestion_service", None),
        ):
            yield

    async def test_stats_returns_200(self, client: AsyncClient, _mock_ingestion_services):
        response = await client.get("/api/v1/admin/stats")

        assert response.status_code == 200

    async def test_stats_response_schema(self, client: AsyncClient, _mock_ingestion_services):
        response = await client.get("/api/v1/admin/stats")
        data = response.json()

        assert "name" in data
        assert "count" in data
        assert isinstance(data["count"], int)

    async def test_ingest_returns_200(self, client: AsyncClient, _mock_ingestion_services):
        response = await client.post(
            "/api/v1/admin/ingest",
            json={"clear_existing": False, "use_sample": True},
        )

        assert response.status_code == 200

    async def test_ingest_response_schema(self, client: AsyncClient, _mock_ingestion_services):
        response = await client.post(
            "/api/v1/admin/ingest",
            json={"clear_existing": False, "use_sample": True},
        )
        data = response.json()

        assert "documents_added" in data
        assert "total_documents" in data
        assert "collection" in data
        assert "message" in data

    async def test_ingest_with_defaults(self, client: AsyncClient, _mock_ingestion_services):
        """Ingest endpoint should work with default parameters."""
        response = await client.post("/api/v1/admin/ingest")

        assert response.status_code == 200


class TestOpenAPIDocumentation:
    """Verify API documentation is accessible."""

    async def test_openapi_json_accessible(self, client: AsyncClient):
        response = await client.get("/openapi.json")

        assert response.status_code == 200
        data = response.json()
        assert "openapi" in data
        assert "paths" in data

    async def test_swagger_ui_accessible(self, client: AsyncClient):
        response = await client.get("/docs")

        assert response.status_code == 200

    async def test_redoc_accessible(self, client: AsyncClient):
        response = await client.get("/redoc")

        assert response.status_code == 200
