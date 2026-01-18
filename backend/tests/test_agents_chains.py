"""Unit tests for agents, chains, and vectorstore."""

from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from langchain_core.documents import Document

from src.app.ai.agents.graph import (
    _count_workflow_steps,
    _extract_json_from_response,
    build_graph,
    get_agent_graph,
    route_to_agent,
)
from src.app.ai.agents.state import AgentState
from src.app.ai.chains.rag_chain import RAGChain, format_docs, reset_rag_chain


def create_mock_llm_response(content: str) -> MagicMock:
    """Create a mock LLM response with proper metadata for instrumentation.

    Args:
        content: The response content string.

    Returns:
        A MagicMock configured with content, usage_metadata, and response_metadata.
    """
    mock_response = MagicMock()
    mock_response.content = content
    mock_response.usage_metadata = {
        "input_tokens": 100,
        "output_tokens": 50,
        "total_tokens": 150,
    }
    mock_response.response_metadata = {
        "model": "test-model",
        "prompt_eval_count": 100,
        "eval_count": 50,
    }
    return mock_response


class TestAgentGraph:
    def test_extract_json_from_response_valid_json(self):
        content = '{"query_type": "research", "countries": ["Kenya"]}'
        result = _extract_json_from_response(content)
        assert result == {"query_type": "research", "countries": ["Kenya"]}

    def test_extract_json_from_response_json_in_text(self):
        content = 'Here is my analysis: {"query_type": "advisory"} based on the query.'
        result = _extract_json_from_response(content)
        assert result == {"query_type": "advisory"}

    def test_extract_json_from_response_invalid_json(self):
        content = "This is not JSON at all"
        result = _extract_json_from_response(content)
        assert result is None

    def test_extract_json_from_response_list_content(self):
        content = ['{"query_type": "compare"}', "some other text"]
        result = _extract_json_from_response(content)
        assert result == {"query_type": "compare"}

    def test_route_to_agent(self):
        state = AgentState(question="test", next_agent="research")
        assert route_to_agent(state) == "research"

        state.next_agent = "advisory"
        assert route_to_agent(state) == "advisory"

        state.next_agent = "compare"
        assert route_to_agent(state) == "compare"

    def test_count_workflow_steps_minimal(self):
        state = {}
        assert _count_workflow_steps(state) == 1

    def test_count_workflow_steps_with_research(self):
        state = {"research_summary": "Some research"}
        assert _count_workflow_steps(state) == 2

    def test_count_workflow_steps_full(self):
        state = {"research_summary": "Research", "final_response": "Response"}
        assert _count_workflow_steps(state) == 3

    def test_build_graph_creates_valid_graph(self):
        graph = build_graph()
        assert graph is not None
        assert "supervisor" in graph.nodes
        assert "research" in graph.nodes
        assert "advisory" in graph.nodes
        assert "compare" in graph.nodes

    def test_get_agent_graph_returns_compiled_graph(self):
        import src.app.ai.agents.graph as graph_module

        graph_module._compiled_graph = None

        graph = get_agent_graph()
        assert graph is not None

        graph2 = get_agent_graph()
        assert graph is graph2

        graph_module._compiled_graph = None


class TestAgentWorkflow:
    @pytest.fixture
    def mock_llm(self):
        mock = MagicMock()
        mock.ainvoke = AsyncMock(
            return_value=create_mock_llm_response(
                '{"query_type": "research", "countries": ["Kenya"], "themes": ["torture"], "requires_comparison": false}'
            )
        )
        return mock

    @pytest.mark.asyncio
    async def test_supervisor_node_routes_to_research(self, mock_llm):
        from src.app.ai.agents.graph import supervisor_node

        with patch("src.app.ai.agents.graph.get_deterministic_llm", return_value=mock_llm):
            state = AgentState(question="What recommendations exist for Kenya?")
            result = await supervisor_node(state)

            assert result.next_agent == "research"
            assert result.query_type == "research"
            assert "Kenya" in result.countries

    @pytest.mark.asyncio
    async def test_supervisor_node_routes_to_compare(self, mock_llm):
        from src.app.ai.agents.graph import supervisor_node

        mock_llm.ainvoke = AsyncMock(
            return_value=create_mock_llm_response(
                '{"query_type": "compare", "countries": ["Kenya", "Tanzania"], "themes": [], "requires_comparison": true}'
            )
        )

        with patch("src.app.ai.agents.graph.get_deterministic_llm", return_value=mock_llm):
            state = AgentState(question="Compare Kenya and Tanzania")
            result = await supervisor_node(state)

            assert result.next_agent == "compare"

    @pytest.mark.asyncio
    async def test_supervisor_node_routes_to_advisory(self, mock_llm):
        from src.app.ai.agents.graph import supervisor_node

        mock_llm.ainvoke = AsyncMock(
            return_value=create_mock_llm_response(
                '{"query_type": "advisory", "countries": [], "themes": [], "requires_comparison": false}'
            )
        )

        with patch("src.app.ai.agents.graph.get_deterministic_llm", return_value=mock_llm):
            state = AgentState(question="What should we focus on?")
            result = await supervisor_node(state)

            assert result.next_agent == "advisory"

    @pytest.mark.asyncio
    async def test_supervisor_node_fallback_on_invalid_json(self, mock_llm):
        from src.app.ai.agents.graph import supervisor_node

        mock_llm.ainvoke = AsyncMock(return_value=create_mock_llm_response("I don't understand the format"))

        with patch("src.app.ai.agents.graph.get_deterministic_llm", return_value=mock_llm):
            state = AgentState(question="Random question")
            result = await supervisor_node(state)

            assert result.next_agent == "research"


class TestRAGChain:
    @pytest.fixture
    def mock_vector_store(self):
        mock = MagicMock()
        mock.similarity_search.return_value = [
            Document(
                page_content="Human rights recommendation content for testing purposes.",
                metadata={"country": "Kenya", "mechanism": "UPR", "year": 2021},
            )
        ]
        mock.as_retriever.return_value = MagicMock()
        return mock

    @pytest.fixture
    def mock_llm(self):
        mock = MagicMock()
        mock.ainvoke = AsyncMock(return_value=create_mock_llm_response("This is the RAG response."))
        return mock

    def test_format_docs_single_document(self):
        docs = [
            Document(
                page_content="Test content",
                metadata={"country": "Kenya", "mechanism": "UPR", "year": 2021},
            )
        ]
        result = format_docs(docs)

        assert "[Source 1]" in result
        assert "Country: Kenya" in result
        assert "Mechanism: UPR" in result
        assert "Year: 2021" in result
        assert "Test content" in result

    def test_format_docs_multiple_documents(self):
        docs = [
            Document(page_content="First doc", metadata={"country": "Kenya"}),
            Document(page_content="Second doc", metadata={"country": "Tanzania"}),
        ]
        result = format_docs(docs)

        assert "[Source 1]" in result
        assert "[Source 2]" in result
        assert "Kenya" in result
        assert "Tanzania" in result
        assert "---" in result

    def test_format_docs_partial_metadata(self):
        docs = [Document(page_content="Content only", metadata={})]
        result = format_docs(docs)

        assert "[Source 1]" in result
        assert "Content only" in result

    @pytest.mark.asyncio
    async def test_invoke_with_sources(self, mock_vector_store, mock_llm):
        with patch("src.app.ai.chains.rag_chain.get_llm", return_value=mock_llm):
            chain = RAGChain(vector_store=mock_vector_store)
            chain.llm = mock_llm

            result = await chain.invoke_with_sources("What about Kenya?")

            assert "answer" in result
            assert "sources" in result
            assert result["answer"] == "This is the RAG response."
            assert len(result["sources"]) == 1
            assert result["sources"][0]["country"] == "Kenya"

    @pytest.mark.asyncio
    async def test_invoke_with_sources_long_snippet(self, mock_vector_store, mock_llm):
        long_content = "A" * 300
        mock_vector_store.similarity_search.return_value = [
            Document(page_content=long_content, metadata={"country": "Kenya"})
        ]

        with patch("src.app.ai.chains.rag_chain.get_llm", return_value=mock_llm):
            chain = RAGChain(vector_store=mock_vector_store)
            chain.llm = mock_llm

            result = await chain.invoke_with_sources("Query")

            assert result["sources"][0]["snippet"].endswith("...")
            assert len(result["sources"][0]["snippet"]) == 203

    def test_reset_rag_chain(self):
        import src.app.ai.chains.rag_chain as rag_module

        rag_module._rag_chain = MagicMock()
        assert rag_module._rag_chain is not None

        reset_rag_chain()
        assert rag_module._rag_chain is None


class TestVectorStoreManager:
    @pytest.fixture
    def mock_embeddings(self):
        mock = MagicMock()
        mock.embed_documents.return_value = [[0.1, 0.2, 0.3]]
        mock.embed_query.return_value = [0.1, 0.2, 0.3]
        return mock

    @pytest.fixture
    def mock_chroma_client(self):
        mock = MagicMock()
        mock_collection = MagicMock()
        mock_collection.count.return_value = 100
        mock.get_or_create_collection.return_value = mock_collection
        return mock

    def test_vector_store_manager_initialization(self, mock_embeddings, tmp_path):
        from src.app.ai.vectorstore.store import VectorStoreManager

        with patch("src.app.ai.vectorstore.store.chromadb.PersistentClient") as mock_client:
            manager = VectorStoreManager(
                embeddings=mock_embeddings,
                persist_directory=str(tmp_path),
            )

            assert manager.embeddings == mock_embeddings
            assert manager.persist_directory == str(tmp_path)
            mock_client.assert_called_once()

    def test_get_collection_stats(self, mock_embeddings, mock_chroma_client, tmp_path):
        from src.app.ai.vectorstore.store import VectorStoreManager

        with patch("src.app.ai.vectorstore.store.chromadb.PersistentClient", return_value=mock_chroma_client):
            manager = VectorStoreManager(
                embeddings=mock_embeddings,
                persist_directory=str(tmp_path),
            )

            stats = manager.get_collection_stats()

            assert stats["name"] == "uhri_recommendations"
            assert stats["count"] == 100

    def test_clear_collection(self, mock_embeddings, mock_chroma_client, tmp_path):
        from src.app.ai.vectorstore.store import VectorStoreManager

        with patch("src.app.ai.vectorstore.store.chromadb.PersistentClient", return_value=mock_chroma_client):
            manager = VectorStoreManager(
                embeddings=mock_embeddings,
                persist_directory=str(tmp_path),
            )
            manager._vectorstore = MagicMock()

            manager.clear_collection()

            mock_chroma_client.delete_collection.assert_called_once_with("uhri_recommendations")
            assert manager._vectorstore is None

    def test_clear_collection_handles_missing(self, mock_embeddings, mock_chroma_client, tmp_path):
        from src.app.ai.vectorstore.store import VectorStoreManager

        mock_chroma_client.delete_collection.side_effect = ValueError("Collection not found")

        with patch("src.app.ai.vectorstore.store.chromadb.PersistentClient", return_value=mock_chroma_client):
            manager = VectorStoreManager(
                embeddings=mock_embeddings,
                persist_directory=str(tmp_path),
            )

            manager.clear_collection()

    @pytest.mark.asyncio
    async def test_async_similarity_search(self, mock_embeddings, mock_chroma_client, tmp_path):
        from src.app.ai.vectorstore.store import VectorStoreManager

        with patch("src.app.ai.vectorstore.store.chromadb.PersistentClient", return_value=mock_chroma_client):
            manager = VectorStoreManager(
                embeddings=mock_embeddings,
                persist_directory=str(tmp_path),
            )

            mock_docs = [Document(page_content="Test", metadata={})]
            manager.similarity_search = MagicMock(return_value=mock_docs)

            result = await manager.asimilarity_search("query", k=3)

            assert result == mock_docs
            manager.similarity_search.assert_called_once_with("query", k=3, filter=None)

    @pytest.mark.asyncio
    async def test_async_get_collection_stats(self, mock_embeddings, mock_chroma_client, tmp_path):
        from src.app.ai.vectorstore.store import VectorStoreManager

        with patch("src.app.ai.vectorstore.store.chromadb.PersistentClient", return_value=mock_chroma_client):
            manager = VectorStoreManager(
                embeddings=mock_embeddings,
                persist_directory=str(tmp_path),
            )

            result = await manager.aget_collection_stats()

            assert result["count"] == 100

    def test_reset_vector_store(self):
        import src.app.ai.vectorstore.store as store_module
        from src.app.ai.vectorstore.store import reset_vector_store

        store_module._vector_store_manager = MagicMock()
        assert store_module._vector_store_manager is not None

        reset_vector_store()
        assert store_module._vector_store_manager is None
