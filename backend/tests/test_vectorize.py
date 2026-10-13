"""Tests for the Cloudflare Vectorize vector store."""

import json

import httpx
import pytest
from langchain_core.documents import Document
from langchain_core.embeddings import Embeddings

from src.app.ai.vectorstore.vectorize import TEXT_KEY, CloudflareVectorize, VectorizeError


class FakeEmbeddings(Embeddings):
    def embed_documents(self, texts: list[str]) -> list[list[float]]:
        return [[float(len(text)), 1.0] for text in texts]

    def embed_query(self, text: str) -> list[float]:
        return [float(len(text)), 1.0]


def ok(result: object) -> httpx.Response:
    return httpx.Response(200, json={"success": True, "errors": [], "result": result})


def make_store(handler) -> tuple[CloudflareVectorize, list[httpx.Request]]:
    requests: list[httpx.Request] = []

    def record(request: httpx.Request) -> httpx.Response:
        requests.append(request)
        return handler(request)

    client = httpx.Client(transport=httpx.MockTransport(record), base_url="https://vectorize.test/idx")
    store = CloudflareVectorize(
        embedding=FakeEmbeddings(),
        account_id="acct",
        api_token="token",
        index_name="hras-uhri",
        client=client,
    )
    return store, requests


class TestCloudflareVectorize:
    def test_requires_credentials(self):
        with pytest.raises(ValueError):
            CloudflareVectorize(embedding=FakeEmbeddings(), account_id="", api_token="", index_name="x")

    def test_add_documents_upserts_ndjson_with_text_in_metadata(self):
        store, requests = make_store(lambda _request: ok({"mutationId": "m1"}))

        ids = store.add_documents([Document(page_content="Ratify CAT", metadata={"country": "Kenya"})])

        assert len(requests) == 1
        request = requests[0]
        assert request.url.path.endswith("/upsert")
        assert request.headers["content-type"] == "application/x-ndjson"
        line = json.loads(request.content.decode().splitlines()[0])
        assert line["id"] == ids[0]
        assert line["values"] == [10.0, 1.0]
        assert line["metadata"] == {"country": "Kenya", TEXT_KEY: "Ratify CAT"}

    def test_ids_are_deterministic_per_text(self):
        store, _ = make_store(lambda _request: ok({}))
        first = store.add_texts(["same text"])
        second = store.add_texts(["same text"])
        assert first == second

    def test_query_returns_documents_with_distance_and_passes_filter(self):
        matches = {
            "count": 1,
            "matches": [{"id": "a", "score": 0.9, "metadata": {"country": "Kenya", TEXT_KEY: "Ratify CAT"}}],
        }
        store, requests = make_store(lambda _request: ok(matches))

        results = store.similarity_search_with_score("torture", k=3, filter={"country": "Kenya"})

        body = json.loads(requests[0].content)
        assert body["topK"] == 3
        assert body["filter"] == {"country": "Kenya"}
        assert body["returnMetadata"] == "all"
        doc, distance = results[0]
        assert doc.page_content == "Ratify CAT"
        assert doc.metadata == {"country": "Kenya"}
        assert distance == pytest.approx(0.1)

    def test_retriever_works(self):
        matches = {"matches": [{"id": "a", "score": 0.5, "metadata": {TEXT_KEY: "hello"}}]}
        store, _ = make_store(lambda _request: ok(matches))
        docs = store.as_retriever(search_kwargs={"k": 1}).invoke("hello")
        assert [doc.page_content for doc in docs] == ["hello"]

    def test_count_reads_index_info(self):
        store, _ = make_store(lambda _request: ok({"dimensions": 384, "vectorCount": 42}))
        assert store.count() == 42

    def test_clear_lists_and_deletes_every_page(self):
        pages = iter(
            [
                {"vectors": [{"id": "a"}, {"id": "b"}], "isTruncated": True, "nextCursor": "c1"},
                {"vectors": [{"id": "c"}], "isTruncated": False},
            ]
        )

        def handler(request: httpx.Request) -> httpx.Response:
            if request.url.path.endswith("/list"):
                return ok(next(pages))
            return ok({"mutationId": "m"})

        store, requests = make_store(handler)
        store.clear()

        deleted = [json.loads(r.content)["ids"] for r in requests if r.url.path.endswith("/delete_by_ids")]
        assert deleted == [["a", "b"], ["c"]]
        assert requests[2].url.params["cursor"] == "c1"

    def test_api_errors_raise(self):
        store, _ = make_store(
            lambda _request: httpx.Response(400, json={"success": False, "errors": [{"message": "bad"}]})
        )
        with pytest.raises(VectorizeError, match="bad"):
            store.count()
