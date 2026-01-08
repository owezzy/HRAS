"""Chat service for the Human Rights Advisory System.

Handles conversation logic, multi-agent invocation, and response formatting.
"""

from uuid import UUID, uuid4

from agents.graph import run_agent_workflow
from chains.rag_chain import RAGChain, get_rag_chain
from src.app.schemas.chat import ChatMessage, ChatRequest, ChatResponse
from vectorstore.document_loader import UHRIDocumentLoader
from vectorstore.store import VectorStoreManager, get_vector_store


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
        if self.use_multi_agent:
            result = await self._process_with_agents(request.message)
        else:
            result = await self.rag_chain.invoke_with_sources(request.message)

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
        try:
            result = await run_agent_workflow(message)
            return {
                "answer": result.get("answer", "I couldn't generate a response. Please try again."),
                "sources": result.get("sources", []),
            }
        except Exception as e:
            # Fallback to simple RAG on error
            print(f"Multi-agent error, falling back to RAG: {e}")
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
        if clear_existing:
            self.vector_store.clear_collection()

        # Load documents
        documents = await self.loader.load()

        # Add to vector store
        doc_ids = self.vector_store.add_documents(documents)

        # Get updated stats
        stats = self.vector_store.get_collection_stats()

        return {
            "documents_added": len(doc_ids),
            "total_documents": stats["count"],
            "collection": stats["name"],
        }

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
