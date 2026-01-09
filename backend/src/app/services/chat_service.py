"""Chat service for the Human Rights Advisory System.

Handles conversation logic, multi-agent invocation, and response formatting.
"""

import time
from uuid import UUID, uuid4

from agents.graph import run_agent_workflow
from chains.rag_chain import RAGChain, get_rag_chain
from src.app.core.logging import ai_logger, get_logger
from src.app.core.metrics import (
    AGENT_EXECUTION_DURATION_SECONDS,
    AGENT_EXECUTIONS_TOTAL,
    CHAT_SESSIONS_ACTIVE,
    DOCUMENT_CHUNKS_TOTAL,
    DOCUMENT_INGESTION_TOTAL,
    ERRORS_TOTAL,
    RAG_QUERIES_TOTAL,
    RAG_QUERY_DURATION_SECONDS,
    VECTORSTORE_DOCUMENTS,
)
from src.app.schemas.chat import ChatMessage, ChatRequest, ChatResponse
from vectorstore.document_loader import UHRIDocumentLoader
from vectorstore.store import VectorStoreManager, get_vector_store

logger = get_logger(__name__)


class ChatService:
    """Service for handling chat interactions."""

    def __init__(
        self,
        rag_chain: RAGChain | None = None,
        vector_store: VectorStoreManager | None = None,
        use_multi_agent: bool = True,
    ) -> None:
        """Initialize the chat service.

        Args:
            rag_chain: RAG chain for generating responses (fallback).
            vector_store: Vector store for document retrieval.
            use_multi_agent: Whether to use the multi-agent system.
        """
        self.rag_chain = rag_chain or get_rag_chain()
        self.vector_store = vector_store or get_vector_store()
        self.use_multi_agent = use_multi_agent

        # In-memory conversation storage (replace with DB in production)
        self._conversations: dict[UUID, list[ChatMessage]] = {}

    async def process_message(self, request: ChatRequest) -> ChatResponse:
        """Process a chat message and generate a response.

        Args:
            request: Chat request from the client.

        Returns:
            Chat response with AI-generated answer and sources.
        """
        # Get or create conversation
        conversation_id = request.conversation_id or uuid4()
        is_new_session = conversation_id not in self._conversations

        if is_new_session:
            CHAT_SESSIONS_ACTIVE.inc()
            logger.info("chat_session_started", conversation_id=str(conversation_id))

        # Check if vector store has documents
        stats = self.vector_store.get_collection_stats()
        if stats["count"] == 0:
            # No documents loaded - return helpful message
            response_message = ChatMessage(
                role="assistant",
                content="The human rights database has not been initialized yet. "
                "Please run the data ingestion process first to load UHRI recommendations. "
                "You can do this by calling the /api/v1/admin/ingest endpoint.",
            )
            return ChatResponse(
                conversation_id=conversation_id,
                message=response_message,
                sources=[],
            )

        # Use multi-agent system or fallback to simple RAG
        start_time = time.perf_counter()
        try:
            if self.use_multi_agent:
                result = await self._process_with_agents(request.message)
            else:
                result = await self.rag_chain.invoke_with_sources(request.message)

            duration = time.perf_counter() - start_time
            RAG_QUERIES_TOTAL.labels(status="success").inc()
            RAG_QUERY_DURATION_SECONDS.observe(duration)

            ai_logger.log_inference(
                model="rag_pipeline",
                latency_ms=duration * 1000,
                success=True,
            )
        except Exception as e:
            duration = time.perf_counter() - start_time
            RAG_QUERIES_TOTAL.labels(status="error").inc()
            RAG_QUERY_DURATION_SECONDS.observe(duration)
            ERRORS_TOTAL.labels(error_type="rag_query", component="chat_service").inc()

            ai_logger.log_inference(
                model="rag_pipeline",
                latency_ms=duration * 1000,
                success=False,
                error=str(e),
            )
            logger.error("rag_query_failed", error=str(e), duration_s=duration)
            raise

        # Create response message
        response_message = ChatMessage(
            role="assistant",
            content=result["answer"],
        )

        # Store in conversation history
        if conversation_id not in self._conversations:
            self._conversations[conversation_id] = []

        self._conversations[conversation_id].append(
            ChatMessage(role="user", content=request.message)
        )
        self._conversations[conversation_id].append(response_message)

        return ChatResponse(
            conversation_id=conversation_id,
            message=response_message,
            sources=result.get("sources", []),
        )

    async def _process_with_agents(self, message: str) -> dict:
        """Process message using the multi-agent system.

        Args:
            message: User's message.

        Returns:
            Dictionary with answer and sources.
        """
        start_time = time.perf_counter()
        try:
            result = await run_agent_workflow(message)

            duration = time.perf_counter() - start_time
            AGENT_EXECUTIONS_TOTAL.labels(agent_name="multi_agent", status="success").inc()
            AGENT_EXECUTION_DURATION_SECONDS.labels(agent_name="multi_agent").observe(duration)

            ai_logger.log_agent_execution(
                agent_name="multi_agent",
                execution_time_ms=duration * 1000,
                steps_count=1,
                success=True,
            )

            return {
                "answer": result.get("answer", "I couldn't generate a response. Please try again."),
                "sources": result.get("sources", []),
            }
        except Exception as e:
            duration = time.perf_counter() - start_time
            AGENT_EXECUTIONS_TOTAL.labels(agent_name="multi_agent", status="error").inc()
            AGENT_EXECUTION_DURATION_SECONDS.labels(agent_name="multi_agent").observe(duration)
            ERRORS_TOTAL.labels(error_type="agent_execution", component="chat_service").inc()

            ai_logger.log_agent_execution(
                agent_name="multi_agent",
                execution_time_ms=duration * 1000,
                steps_count=0,
                success=False,
                error=str(e),
            )
            logger.warning("multi_agent_fallback_to_rag", error=str(e))

            return await self.rag_chain.invoke_with_sources(message)

    def get_conversation_history(self, conversation_id: UUID) -> list[ChatMessage]:
        """Get the history of a conversation.

        Args:
            conversation_id: ID of the conversation.

        Returns:
            List of messages in the conversation.
        """
        return self._conversations.get(conversation_id, [])


class DataIngestionService:
    """Service for ingesting UHRI data into the vector store."""

    def __init__(
        self,
        vector_store: VectorStoreManager | None = None,
        use_sample: bool = True,
    ) -> None:
        """Initialize the data ingestion service.

        Args:
            vector_store: Vector store to ingest into.
            use_sample: Whether to use sample data (True for dev).
        """
        self.vector_store = vector_store or get_vector_store()
        self.loader = UHRIDocumentLoader(use_sample=use_sample)

    async def ingest(self, clear_existing: bool = False) -> dict:
        """Ingest UHRI data into the vector store.

        Args:
            clear_existing: Whether to clear existing documents first.

        Returns:
            Dictionary with ingestion statistics.
        """
        start_time = time.perf_counter()
        try:
            if clear_existing:
                self.vector_store.clear_collection()

            documents = await self.loader.load()

            doc_ids = self.vector_store.add_documents(documents)

            stats = self.vector_store.get_collection_stats()

            duration = time.perf_counter() - start_time
            DOCUMENT_INGESTION_TOTAL.labels(status="success").inc()
            DOCUMENT_CHUNKS_TOTAL.inc(len(doc_ids))
            VECTORSTORE_DOCUMENTS.set(stats["count"])

            logger.info(
                "document_ingestion_complete",
                documents_added=len(doc_ids),
                total_documents=stats["count"],
                duration_s=duration,
            )

            return {
                "documents_added": len(doc_ids),
                "total_documents": stats["count"],
                "collection": stats["name"],
            }
        except Exception as e:
            duration = time.perf_counter() - start_time
            DOCUMENT_INGESTION_TOTAL.labels(status="error").inc()
            ERRORS_TOTAL.labels(error_type="document_ingestion", component="data_ingestion_service").inc()

            logger.error("document_ingestion_failed", error=str(e), duration_s=duration)
            raise

    async def get_stats(self) -> dict:
        """Get current vector store statistics.

        Returns:
            Dictionary with collection statistics.
        """
        return self.vector_store.get_collection_stats()


# Service instances
_chat_service: ChatService | None = None
_ingestion_service: DataIngestionService | None = None


def get_chat_service(use_multi_agent: bool = True) -> ChatService:
    """Get the global chat service instance."""
    global _chat_service
    if _chat_service is None:
        _chat_service = ChatService(use_multi_agent=use_multi_agent)
    return _chat_service


def get_ingestion_service(use_sample: bool = True) -> DataIngestionService:
    """Get the global data ingestion service instance."""
    global _ingestion_service
    if _ingestion_service is None:
        _ingestion_service = DataIngestionService(use_sample=use_sample)
    return _ingestion_service
