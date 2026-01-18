"""ChromaDB vector store for UHRI documents."""

import time

import chromadb
from chromadb.config import Settings as ChromaSettings
from langchain_chroma import Chroma
from langchain_core.documents import Document
from langchain_core.embeddings import Embeddings
from langchain_ollama import OllamaEmbeddings

from src.app.core.async_utils import run_in_thread
from src.app.core.config import get_settings
from src.app.core.instrumentation import record_embeddings_generated, record_vector_search_metrics


def get_embeddings() -> Embeddings:
    """Get Ollama embeddings."""
    settings = get_settings()
    return OllamaEmbeddings(
        base_url=settings.ollama_base_url,
        model=settings.ollama_embedding_model,
    )


class VectorStoreManager:
    """Manages the ChromaDB vector store for UHRI documents."""

    COLLECTION_NAME = "uhri_recommendations"

    def __init__(
        self,
        embeddings: Embeddings | None = None,
        persist_directory: str | None = None,
    ) -> None:
        """Initialize the vector store manager.

        Args:
            embeddings: Embedding model to use. Defaults to OpenAI embeddings.
            persist_directory: Directory to persist ChromaDB. Defaults to config value.
        """
        settings = get_settings()
        self.persist_directory = persist_directory or settings.chroma_persist_directory

        self.embeddings = embeddings or get_embeddings()

        # Initialize ChromaDB client
        self._chroma_client = chromadb.PersistentClient(
            path=self.persist_directory,
            settings=ChromaSettings(anonymized_telemetry=False),
        )

        self._vectorstore: Chroma | None = None

    @property
    def vectorstore(self) -> Chroma:
        """Get or create the Chroma vector store."""
        if self._vectorstore is None:
            self._vectorstore = Chroma(
                client=self._chroma_client,
                collection_name=self.COLLECTION_NAME,
                embedding_function=self.embeddings,
            )
        return self._vectorstore

    def add_documents(self, documents: list[Document]) -> list[str]:
        """Add documents to the vector store.

        Args:
            documents: List of LangChain Documents to add.

        Returns:
            List of document IDs.
        """
        record_embeddings_generated(len(documents))
        return self.vectorstore.add_documents(documents)

    def similarity_search(
        self,
        query: str,
        k: int = 5,
        filter: dict | None = None,
    ) -> list[Document]:
        """Search for similar documents.

        Args:
            query: Search query text.
            k: Number of results to return.
            filter: Optional metadata filter (e.g., {"country": "Kenya"}).

        Returns:
            List of matching Documents.
        """
        start_time = time.perf_counter()
        try:
            results = self.vectorstore.similarity_search(query, k=k, filter=filter)
            duration = time.perf_counter() - start_time
            record_vector_search_metrics(duration, success=True, num_results=len(results))
            return results
        except Exception:
            duration = time.perf_counter() - start_time
            record_vector_search_metrics(duration, success=False)
            raise

    def similarity_search_with_score(
        self,
        query: str,
        k: int = 5,
        filter: dict | None = None,
    ) -> list[tuple[Document, float]]:
        """Search for similar documents with relevance scores.

        Args:
            query: Search query text.
            k: Number of results to return.
            filter: Optional metadata filter.

        Returns:
            List of (Document, score) tuples.
        """
        start_time = time.perf_counter()
        try:
            results = self.vectorstore.similarity_search_with_score(query, k=k, filter=filter)
            duration = time.perf_counter() - start_time
            record_vector_search_metrics(duration, success=True, num_results=len(results))
            return results
        except Exception:
            duration = time.perf_counter() - start_time
            record_vector_search_metrics(duration, success=False)
            raise

    def as_retriever(self, search_kwargs: dict | None = None):
        """Get a retriever interface for the vector store.

        Args:
            search_kwargs: Optional search parameters (k, filter, etc.).

        Returns:
            LangChain Retriever object.
        """
        kwargs = search_kwargs or {"k": 5}
        return self.vectorstore.as_retriever(search_kwargs=kwargs)

    def get_collection_stats(self) -> dict:
        """Get statistics about the vector store collection.

        Returns:
            Dictionary with collection statistics.
        """
        collection = self._chroma_client.get_or_create_collection(self.COLLECTION_NAME)
        return {
            "name": self.COLLECTION_NAME,
            "count": collection.count(),
        }

    def clear_collection(self) -> None:
        """Clear all documents from the collection."""
        try:
            self._chroma_client.delete_collection(self.COLLECTION_NAME)
            self._vectorstore = None
        except ValueError:
            pass

    async def asimilarity_search(
        self,
        query: str,
        k: int = 5,
        filter: dict | None = None,
    ) -> list[Document]:
        """Async version of similarity_search using thread pool."""
        return await run_in_thread(self.similarity_search, query, k=k, filter=filter)

    async def asimilarity_search_with_score(
        self,
        query: str,
        k: int = 5,
        filter: dict | None = None,
    ) -> list[tuple[Document, float]]:
        """Async version of similarity_search_with_score using thread pool."""
        return await run_in_thread(self.similarity_search_with_score, query, k=k, filter=filter)

    async def aadd_documents(self, documents: list[Document]) -> list[str]:
        """Async version of add_documents using thread pool."""
        return await run_in_thread(self.add_documents, documents)

    async def aget_collection_stats(self) -> dict:
        """Async version of get_collection_stats using thread pool."""
        return await run_in_thread(self.get_collection_stats)


# Global instance for dependency injection
_vector_store_manager: VectorStoreManager | None = None


def get_vector_store() -> VectorStoreManager:
    """Get the global vector store manager instance."""
    global _vector_store_manager
    if _vector_store_manager is None:
        _vector_store_manager = VectorStoreManager()
    return _vector_store_manager


def reset_vector_store() -> None:
    """Reset the global vector store manager (for testing)."""
    global _vector_store_manager
    _vector_store_manager = None
