"""Integration tests for API endpoints."""

from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from httpx import ASGITransport, AsyncClient
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine

from src.app.main import create_app
from src.app.models.conversation import Base


@pytest.fixture
async def integration_db_engine():
    engine = create_async_engine("sqlite+aiosqlite:///:memory:", echo=False)
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    yield engine
    await engine.dispose()


@pytest.fixture
def integration_app(integration_db_engine):
    app = create_app()

    async def override_get_db():
        session_factory = async_sessionmaker(integration_db_engine, expire_on_commit=False)
        async with session_factory() as session:
            yield session

    from src.app.core.database import get_db

    app.dependency_overrides[get_db] = override_get_db
    return app


@pytest.fixture
async def integration_client(integration_app):
    async with AsyncClient(
        transport=ASGITransport(app=integration_app),
        base_url="http://test",
    ) as client:
        yield client


class TestConversationEndpointsIntegration:
    @pytest.mark.asyncio
    async def test_list_conversations_when_postgres_disabled(self, integration_client):
        with patch("src.app.api.routes.conversations.settings") as mock_settings:
            mock_settings.use_postgres = False

            response = await integration_client.get("/api/v1/conversations")

            assert response.status_code == 503
            assert "disabled" in response.json()["detail"].lower()

    @pytest.mark.asyncio
    async def test_list_conversations_empty(self, integration_client):
        with patch("src.app.api.routes.conversations.settings") as mock_settings:
            mock_settings.use_postgres = True

            response = await integration_client.get("/api/v1/conversations")

            assert response.status_code == 200
            data = response.json()
            assert data["conversations"] == []
            assert data["total"] == 0

    @pytest.mark.asyncio
    async def test_get_conversation_not_found(self, integration_client):
        with patch("src.app.api.routes.conversations.settings") as mock_settings:
            mock_settings.use_postgres = True

            response = await integration_client.get("/api/v1/conversations/nonexistent-id")

            assert response.status_code == 404

    @pytest.mark.asyncio
    async def test_delete_conversation_not_found(self, integration_client):
        with patch("src.app.api.routes.conversations.settings") as mock_settings:
            mock_settings.use_postgres = True

            response = await integration_client.delete("/api/v1/conversations/nonexistent-id")

            assert response.status_code == 404


class TestChatEndpointIntegration:
    @pytest.fixture
    def mock_services(self):
        mock_vector_store = MagicMock()
        mock_vector_store.get_collection_stats.return_value = {"name": "uhri", "count": 100}

        mock_rag_chain = MagicMock()
        mock_rag_chain.invoke_with_sources = AsyncMock(
            return_value={
                "answer": "Integration test response about human rights.",
                "sources": [{"country": "Kenya", "mechanism": "UPR"}],
            }
        )

        return mock_vector_store, mock_rag_chain

    @pytest.mark.asyncio
    async def test_chat_endpoint_success(self, integration_client, mock_services):
        mock_vector_store, mock_rag_chain = mock_services

        with (
            patch("src.app.services.chat_service.get_vector_store", return_value=mock_vector_store),
            patch("src.app.services.chat_service.get_rag_chain", return_value=mock_rag_chain),
        ):
            import src.app.services.chat_service as chat_module

            chat_module._chat_service = None

            response = await integration_client.post(
                "/api/v1/chat",
                json={"message": "What are human rights recommendations for Kenya?"},
            )

            chat_module._chat_service = None

        assert response.status_code == 200
        data = response.json()
        assert "message" in data
        assert "conversation_id" in data

    @pytest.mark.asyncio
    async def test_chat_endpoint_empty_vectorstore(self, integration_client):
        mock_vector_store = MagicMock()
        mock_vector_store.get_collection_stats.return_value = {"name": "uhri", "count": 0}

        with patch("src.app.services.chat_service.get_vector_store", return_value=mock_vector_store):
            import src.app.services.chat_service as chat_module

            chat_module._chat_service = None

            response = await integration_client.post(
                "/api/v1/chat",
                json={"message": "Test query"},
            )

            chat_module._chat_service = None

        assert response.status_code == 200
        data = response.json()
        assert "not been initialized" in data["message"]["content"]

    @pytest.mark.asyncio
    async def test_chat_endpoint_validation_error(self, integration_client):
        response = await integration_client.post(
            "/api/v1/chat",
            json={"message": ""},
        )

        assert response.status_code == 422


class TestHealthEndpointsIntegration:
    @pytest.mark.asyncio
    async def test_health_endpoint(self, integration_client):
        response = await integration_client.get("/health")

        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "healthy"

    @pytest.mark.asyncio
    async def test_root_endpoint(self, integration_client):
        response = await integration_client.get("/")

        assert response.status_code == 200
        data = response.json()
        assert "Human Rights Advisory System" in data["message"]


class TestAdminEndpointsIntegration:
    @pytest.mark.asyncio
    async def test_stats_endpoint(self, integration_client):
        mock_vector_store = MagicMock()
        mock_vector_store.get_collection_stats.return_value = {"name": "uhri", "count": 50}

        with patch("src.app.services.chat_service.get_vector_store", return_value=mock_vector_store):
            import src.app.services.chat_service as chat_module

            chat_module._ingestion_service = None

            response = await integration_client.get("/api/v1/admin/stats")

            chat_module._ingestion_service = None

        assert response.status_code == 200
        data = response.json()
        assert data["count"] == 50

    @pytest.mark.asyncio
    async def test_ingest_endpoint(self, integration_client):
        mock_vector_store = MagicMock()
        mock_vector_store.get_collection_stats.return_value = {"name": "uhri", "count": 10}
        mock_vector_store.add_documents.return_value = ["id1", "id2"]

        mock_loader = MagicMock()
        mock_loader.load = AsyncMock(return_value=[])

        with (
            patch("src.app.services.chat_service.get_vector_store", return_value=mock_vector_store),
            patch("src.app.services.chat_service.UHRIDocumentLoader", return_value=mock_loader),
        ):
            import src.app.services.chat_service as chat_module

            chat_module._ingestion_service = None

            response = await integration_client.post("/api/v1/admin/ingest")

            chat_module._ingestion_service = None

        assert response.status_code == 200
