"""Unit tests for HRAS services (ChatService, DataIngestionService)."""

from unittest.mock import AsyncMock, MagicMock, patch
from uuid import uuid4

import pytest

from src.app.schemas.chat import ChatRequest
from src.app.services.chat_service import ChatService, DataIngestionService


class TestChatService:
    """Tests for ChatService."""

    @pytest.fixture
    def mock_rag_chain(self):
        mock = MagicMock()
        mock.invoke_with_sources = AsyncMock(
            return_value={
                "answer": "Test response about human rights.",
                "sources": [{"title": "Test Source", "country": "Kenya"}],
            }
        )
        return mock

    @pytest.fixture
    def mock_vector_store(self):
        mock = MagicMock()
        mock.get_collection_stats.return_value = {"name": "uhri", "count": 100}
        return mock

    @pytest.fixture
    def mock_empty_vector_store(self):
        mock = MagicMock()
        mock.get_collection_stats.return_value = {"name": "uhri", "count": 0}
        return mock

    @pytest.mark.asyncio
    async def test_process_message_success(self, mock_rag_chain, mock_vector_store):
        service = ChatService(
            rag_chain=mock_rag_chain,
            vector_store=mock_vector_store,
            use_multi_agent=False,
        )
        request = ChatRequest(message="What are human rights recommendations for Kenya?")

        response = await service.process_message(request)

        assert response.message.role == "assistant"
        assert "Test response" in response.message.content
        assert response.conversation_id is not None
        mock_rag_chain.invoke_with_sources.assert_called_once()

    @pytest.mark.asyncio
    async def test_process_message_empty_vectorstore(self, mock_rag_chain, mock_empty_vector_store):
        service = ChatService(
            rag_chain=mock_rag_chain,
            vector_store=mock_empty_vector_store,
            use_multi_agent=False,
        )
        request = ChatRequest(message="Test query")

        response = await service.process_message(request)

        assert "database has not been initialized" in response.message.content
        assert response.sources == []
        mock_rag_chain.invoke_with_sources.assert_not_called()

    @pytest.mark.asyncio
    async def test_process_message_with_conversation_id(self, mock_rag_chain, mock_vector_store):
        service = ChatService(
            rag_chain=mock_rag_chain,
            vector_store=mock_vector_store,
            use_multi_agent=False,
        )
        conversation_id = uuid4()
        request = ChatRequest(message="Follow-up question", conversation_id=conversation_id)

        response = await service.process_message(request)

        assert response.conversation_id == conversation_id

    @pytest.mark.asyncio
    async def test_process_message_multi_agent_success(self, mock_rag_chain, mock_vector_store):
        mock_workflow_result = {
            "answer": "Multi-agent response.",
            "sources": [{"title": "Agent Source"}],
        }

        with patch(
            "src.app.services.chat_service.run_agent_workflow",
            new_callable=AsyncMock,
            return_value=mock_workflow_result,
        ):
            service = ChatService(
                rag_chain=mock_rag_chain,
                vector_store=mock_vector_store,
                use_multi_agent=True,
            )
            request = ChatRequest(message="Test multi-agent query")

            response = await service.process_message(request)

            assert "Multi-agent response" in response.message.content

    @pytest.mark.asyncio
    async def test_process_message_multi_agent_fallback(self, mock_rag_chain, mock_vector_store):
        with patch(
            "src.app.services.chat_service.run_agent_workflow",
            new_callable=AsyncMock,
            side_effect=Exception("Agent workflow failed"),
        ):
            service = ChatService(
                rag_chain=mock_rag_chain,
                vector_store=mock_vector_store,
                use_multi_agent=True,
            )
            request = ChatRequest(message="Test query")

            response = await service.process_message(request)

            assert "Test response" in response.message.content
            mock_rag_chain.invoke_with_sources.assert_called_once()

    @pytest.mark.asyncio
    async def test_process_message_rag_error(self, mock_vector_store):
        failing_rag = MagicMock()
        failing_rag.invoke_with_sources = AsyncMock(side_effect=Exception("RAG failed"))

        service = ChatService(
            rag_chain=failing_rag,
            vector_store=mock_vector_store,
            use_multi_agent=False,
        )
        request = ChatRequest(message="Test query")

        with pytest.raises(Exception, match="RAG failed"):
            await service.process_message(request)

    def test_get_conversation_history_empty(self, mock_rag_chain, mock_vector_store):
        service = ChatService(
            rag_chain=mock_rag_chain,
            vector_store=mock_vector_store,
        )
        history = service.get_conversation_history(uuid4())
        assert history == []

    @pytest.mark.asyncio
    async def test_get_conversation_history_with_messages(self, mock_rag_chain, mock_vector_store):
        service = ChatService(
            rag_chain=mock_rag_chain,
            vector_store=mock_vector_store,
            use_multi_agent=False,
        )
        request = ChatRequest(message="Test query")

        response = await service.process_message(request)
        history = service.get_conversation_history(response.conversation_id)

        assert len(history) == 2
        assert history[0].role == "user"
        assert history[0].content == "Test query"
        assert history[1].role == "assistant"

    @pytest.mark.asyncio
    async def test_session_tracking(self, mock_rag_chain, mock_vector_store):
        service = ChatService(
            rag_chain=mock_rag_chain,
            vector_store=mock_vector_store,
            use_multi_agent=False,
        )
        conversation_id = uuid4()

        request1 = ChatRequest(message="First message", conversation_id=conversation_id)
        await service.process_message(request1)

        request2 = ChatRequest(message="Second message", conversation_id=conversation_id)
        await service.process_message(request2)

        history = service.get_conversation_history(conversation_id)
        assert len(history) == 4


class TestDataIngestionService:
    """Tests for DataIngestionService."""

    @pytest.fixture
    def mock_vector_store(self):
        mock = MagicMock()
        mock.get_collection_stats.return_value = {"name": "uhri", "count": 100}
        mock.add_documents.return_value = [str(uuid4()) for _ in range(10)]
        mock.clear_collection.return_value = None
        return mock

    @pytest.fixture
    def mock_document_loader(self):
        from langchain_core.documents import Document

        mock = MagicMock()
        mock.load = AsyncMock(
            return_value=[
                Document(
                    page_content="Human rights content",
                    metadata={"title": "Test Doc", "country": "Kenya"},
                )
                for _ in range(10)
            ]
        )
        return mock

    @pytest.mark.asyncio
    async def test_ingest_success(self, mock_vector_store, mock_document_loader):
        with patch(
            "src.app.services.chat_service.UHRIDocumentLoader",
            return_value=mock_document_loader,
        ):
            service = DataIngestionService(vector_store=mock_vector_store)
            service.loader = mock_document_loader

            result = await service.ingest()

            assert result["documents_added"] == 10
            assert result["total_documents"] == 100
            assert result["collection"] == "uhri"
            mock_vector_store.add_documents.assert_called_once()

    @pytest.mark.asyncio
    async def test_ingest_with_clear(self, mock_vector_store, mock_document_loader):
        with patch(
            "src.app.services.chat_service.UHRIDocumentLoader",
            return_value=mock_document_loader,
        ):
            service = DataIngestionService(vector_store=mock_vector_store)
            service.loader = mock_document_loader

            await service.ingest(clear_existing=True)

            mock_vector_store.clear_collection.assert_called_once()
            mock_vector_store.add_documents.assert_called_once()

    @pytest.mark.asyncio
    async def test_ingest_error(self, mock_vector_store, mock_document_loader):
        mock_document_loader.load = AsyncMock(side_effect=Exception("Load failed"))

        with patch(
            "src.app.services.chat_service.UHRIDocumentLoader",
            return_value=mock_document_loader,
        ):
            service = DataIngestionService(vector_store=mock_vector_store)
            service.loader = mock_document_loader

            with pytest.raises(Exception, match="Load failed"):
                await service.ingest()

    @pytest.mark.asyncio
    async def test_get_stats(self, mock_vector_store):
        service = DataIngestionService(vector_store=mock_vector_store)

        stats = await service.get_stats()

        assert stats["name"] == "uhri"
        assert stats["count"] == 100
        mock_vector_store.get_collection_stats.assert_called()


class TestChatServiceWithDB:
    """Tests for ChatService with database integration."""

    @pytest.fixture
    def mock_rag_chain(self):
        mock = MagicMock()
        mock.invoke_with_sources = AsyncMock(
            return_value={
                "answer": "Test DB response.",
                "sources": [{"title": "DB Source"}],
            }
        )
        return mock

    @pytest.fixture
    def mock_vector_store(self):
        mock = MagicMock()
        mock.get_collection_stats.return_value = {"name": "uhri", "count": 100}
        return mock

    @pytest.mark.asyncio
    async def test_process_message_without_db_session(self, mock_rag_chain, mock_vector_store):
        service = ChatService(
            rag_chain=mock_rag_chain,
            vector_store=mock_vector_store,
            use_multi_agent=False,
            db_session=None,
        )

        assert service._repo is None

        request = ChatRequest(message="Test query")
        response = await service.process_message(request)

        assert response.message.content == "Test DB response."

    @pytest.mark.asyncio
    async def test_process_message_with_db_session(self, mock_rag_chain, mock_vector_store, db_session):
        service = ChatService(
            rag_chain=mock_rag_chain,
            vector_store=mock_vector_store,
            use_multi_agent=False,
            db_session=db_session,
        )

        assert service._repo is not None

        with (
            patch.object(service._repo, "create", new_callable=AsyncMock) as mock_create,
            patch.object(service._repo, "add_message", new_callable=AsyncMock),
            patch("src.app.services.chat_service.settings") as mock_settings,
        ):
            mock_settings.use_postgres = False

            request = ChatRequest(message="Test query")
            response = await service.process_message(request)

            assert response.message.content == "Test DB response."
            mock_create.assert_not_called()
