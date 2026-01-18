"""RAG chain for the Human Rights Advisory System."""

from langchain_core.documents import Document
from langchain_core.output_parsers import StrOutputParser
from langchain_core.runnables import RunnablePassthrough, RunnableSerializable

from src.app.ai.prompts.hr_advisor import SIMPLE_RAG_PROMPT
from src.app.ai.vectorstore.store import VectorStoreManager, get_vector_store
from src.app.core.instrumentation import instrumented_llm_invoke
from src.app.core.llm import get_llm


def format_docs(docs: list[Document]) -> str:
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
    def __init__(
        self,
        vector_store: VectorStoreManager | None = None,
    ) -> None:
        self.vector_store = vector_store or get_vector_store()
        self.llm = get_llm()
        self._chain: RunnableSerializable | None = None

    @property
    def chain(self) -> RunnableSerializable:
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
        return await self.chain.ainvoke(question)

    async def invoke_with_sources(
        self,
        question: str,
        k: int = 5,
    ) -> dict:
        docs = self.vector_store.similarity_search(question, k=k)
        context = format_docs(docs)

        messages = SIMPLE_RAG_PROMPT.format_messages(context=context, question=question)
        response = await instrumented_llm_invoke(self.llm, messages)

        sources = []
        for doc in docs:
            sources.append(
                {
                    "country": doc.metadata.get("country", ""),
                    "mechanism": doc.metadata.get("mechanism", ""),
                    "year": doc.metadata.get("year", ""),
                    "theme": doc.metadata.get("theme", ""),
                    "status": doc.metadata.get("status", ""),
                    "snippet": doc.page_content[:200] + "..." if len(doc.page_content) > 200 else doc.page_content,
                }
            )

        return {
            "answer": str(response.content),
            "sources": sources,
        }


_rag_chain: RAGChain | None = None


def get_rag_chain() -> RAGChain:
    global _rag_chain
    if _rag_chain is None:
        _rag_chain = RAGChain()
    return _rag_chain


def reset_rag_chain() -> None:
    global _rag_chain
    _rag_chain = None
