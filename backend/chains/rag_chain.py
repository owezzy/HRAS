"""RAG chain for the Human Rights Advisory System.

Implements retrieval-augmented generation using LangChain LCEL.
"""

from langchain_core.documents import Document
from langchain_core.language_models import BaseChatModel
from langchain_core.output_parsers import StrOutputParser
from langchain_core.runnables import RunnablePassthrough, RunnableSerializable

from prompts.hr_advisor import SIMPLE_RAG_PROMPT
from src.app.core.config import get_settings
from vectorstore.store import VectorStoreManager, get_vector_store


def get_llm() -> BaseChatModel:
    """Get the configured LLM (Ollama)."""
    from langchain_ollama import ChatOllama

    settings = get_settings()

    return ChatOllama(
        base_url=settings.ollama_base_url,
        model=settings.ollama_model,
        temperature=0.1,
    )


def format_docs(docs: list[Document]) -> str:
    """Format documents for inclusion in the prompt.

    Args:
        docs: List of retrieved documents.

    Returns:
        Formatted string with document contents.
    """
    formatted = []
    for i, doc in enumerate(docs, 1):
        metadata = doc.metadata
        header = f"[Source {i}]"
        if metadata.get("country"):
            header += f" Country: {metadata['country']}"
        if metadata.get("mechanism"):
            header += f" | Mechanism: {metadata['mechanism']}"
        if metadata.get("year"):
            header += f" | Year: {metadata['year']}"

        formatted.append(f"{header}\n{doc.page_content}")

    return "\n\n---\n\n".join(formatted)


class RAGChain:
    """RAG chain for human rights advisory queries."""

    def __init__(
        self,
        vector_store: VectorStoreManager | None = None,
    ) -> None:
        """Initialize the RAG chain.

        Args:
            vector_store: Vector store manager. Defaults to global instance.
        """
        self.vector_store = vector_store or get_vector_store()
        self.llm = get_llm()
        self._chain: RunnableSerializable | None = None

    @property
    def chain(self) -> RunnableSerializable:
        """Get or build the RAG chain."""
        if self._chain is None:
            retriever = self.vector_store.as_retriever({"k": 5})

            self._chain = (
                {"context": retriever | format_docs, "question": RunnablePassthrough()}
                | SIMPLE_RAG_PROMPT
                | self.llm
                | StrOutputParser()
            )
        return self._chain

    async def invoke(self, question: str) -> str:
        """Invoke the RAG chain with a question.

        Args:
            question: User's question.

        Returns:
            Generated answer.
        """
        return await self.chain.ainvoke(question)

    async def invoke_with_sources(
        self,
        question: str,
        k: int = 5,
    ) -> dict:
        """Invoke the RAG chain and return answer with sources.

        Args:
            question: User's question.
            k: Number of sources to retrieve.

        Returns:
            Dictionary with 'answer' and 'sources' keys.
        """
        # Retrieve documents
        docs = self.vector_store.similarity_search(question, k=k)

        # Format context
        context = format_docs(docs)

        # Generate answer
        prompt_value = SIMPLE_RAG_PROMPT.format(context=context, question=question)
        response = await self.llm.ainvoke(prompt_value)

        # Format sources for response
        sources = []
        for doc in docs:
            sources.append({
                "country": doc.metadata.get("country", ""),
                "mechanism": doc.metadata.get("mechanism", ""),
                "year": doc.metadata.get("year", ""),
                "theme": doc.metadata.get("theme", ""),
                "status": doc.metadata.get("status", ""),
                "snippet": doc.page_content[:200] + "..." if len(doc.page_content) > 200 else doc.page_content,
            })

        return {
            "answer": response.content,
            "sources": sources,
        }


# Global chain instance
_rag_chain: RAGChain | None = None


def get_rag_chain() -> RAGChain:
    """Get the global RAG chain instance."""
    global _rag_chain
    if _rag_chain is None:
        _rag_chain = RAGChain()
    return _rag_chain


def reset_rag_chain() -> None:
    """Reset the global RAG chain (for testing)."""
    global _rag_chain
    _rag_chain = None
