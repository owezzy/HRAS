"""Cloudflare Vectorize vector store, used where no persistent disk exists.

Talks to the Vectorize v2 REST API, so it works from any host (a Cloudflare
Container, a VPS, a laptop) with an account ID and an API token that has
Vectorize Edit. Document text is stored in vector metadata under ``text``.

Metadata filters ({"country": "Kenya"}) need a metadata index per property:

    npx wrangler vectorize create-metadata-index hras-uhri --property-name=country --type=string
"""

import json
import uuid
from collections.abc import Iterable
from typing import Any

import httpx
from langchain_core.documents import Document
from langchain_core.embeddings import Embeddings
from langchain_core.vectorstores import VectorStore

TEXT_KEY = "text"
UPSERT_BATCH_SIZE = 500
DELETE_BATCH_SIZE = 1000
# Vectorize caps metadata at 10 KiB per vector; keep headroom for the other fields.
MAX_TEXT_BYTES = 8000


class VectorizeError(RuntimeError):
    """Raised when the Vectorize API returns an error."""


class CloudflareVectorize(VectorStore):
    """LangChain vector store backed by a Cloudflare Vectorize index."""

    def __init__(
        self,
        embedding: Embeddings,
        account_id: str,
        api_token: str,
        index_name: str,
        base_url: str = "https://api.cloudflare.com/client/v4",
        timeout: float = 30,
        client: httpx.Client | None = None,
    ) -> None:
        if not account_id or not api_token:
            raise ValueError("Vectorize needs CLOUDFLARE_ACCOUNT_ID and CLOUDFLARE_API_TOKEN")
        self._embedding = embedding
        self.index_name = index_name
        self._client = client or httpx.Client(
            base_url=f"{base_url}/accounts/{account_id}/vectorize/v2/indexes/{index_name}",
            headers={"Authorization": f"Bearer {api_token}"},
            timeout=timeout,
        )

    @property
    def embeddings(self) -> Embeddings:
        return self._embedding

    def _request(self, method: str, path: str, **kwargs: Any) -> Any:
        response = self._client.request(method, path, **kwargs)
        try:
            body = response.json()
        except ValueError:
            body = {}
        if response.is_error or not body.get("success", False):
            errors = body.get("errors") or response.text
            raise VectorizeError(f"Vectorize {method} {path} failed ({response.status_code}): {errors}")
        return body.get("result")

    @staticmethod
    def _vector_id(text: str) -> str:
        # Deterministic, so re-ingesting the same text overwrites instead of duplicating.
        return str(uuid.uuid5(uuid.NAMESPACE_URL, text))

    @staticmethod
    def _truncate(text: str) -> str:
        encoded = text.encode("utf-8")
        if len(encoded) <= MAX_TEXT_BYTES:
            return text
        return encoded[:MAX_TEXT_BYTES].decode("utf-8", errors="ignore")

    def add_texts(
        self,
        texts: Iterable[str],
        metadatas: list[dict] | None = None,
        *,
        ids: list[str] | None = None,
        **kwargs: Any,  # noqa: ARG002
    ) -> list[str]:
        texts = list(texts)
        if not texts:
            return []
        metadatas = metadatas or [{} for _ in texts]
        ids = ids or [self._vector_id(text) for text in texts]
        vectors = self._embedding.embed_documents(texts)

        for start in range(0, len(texts), UPSERT_BATCH_SIZE):
            lines = [
                json.dumps(
                    {
                        "id": ids[i],
                        "values": vectors[i],
                        "metadata": {**metadatas[i], TEXT_KEY: self._truncate(texts[i])},
                    }
                )
                for i in range(start, min(start + UPSERT_BATCH_SIZE, len(texts)))
            ]
            self._request(
                "POST",
                "/upsert",
                content="\n".join(lines).encode("utf-8"),
                headers={"Content-Type": "application/x-ndjson"},
            )
        return ids

    def similarity_search_with_score(
        self,
        query: str,
        k: int = 4,
        filter: dict | None = None,
        **kwargs: Any,  # noqa: ARG002
    ) -> list[tuple[Document, float]]:
        """Return documents with a cosine distance (lower is closer), matching Chroma's convention."""
        payload: dict[str, Any] = {
            "vector": self._embedding.embed_query(query),
            "topK": k,
            "returnMetadata": "all",
        }
        if filter:
            payload["filter"] = filter
        result = self._request("POST", "/query", json=payload) or {}

        results = []
        for match in result.get("matches", []):
            metadata = dict(match.get("metadata") or {})
            text = metadata.pop(TEXT_KEY, "")
            results.append((Document(page_content=text, metadata=metadata), 1.0 - float(match["score"])))
        return results

    def similarity_search(
        self,
        query: str,
        k: int = 4,
        filter: dict | None = None,
        **kwargs: Any,  # noqa: ARG002
    ) -> list[Document]:
        return [doc for doc, _ in self.similarity_search_with_score(query, k=k, filter=filter)]

    def _similarity_search_with_relevance_scores(
        self,
        query: str,
        k: int = 4,
        **kwargs: Any,  # noqa: ARG002
    ) -> list[tuple[Document, float]]:
        return [(doc, 1.0 - distance) for doc, distance in self.similarity_search_with_score(query, k=k, **kwargs)]

    def count(self) -> int:
        info = self._request("GET", "/info") or {}
        return int(info.get("vectorCount", 0))

    def delete(self, ids: list[str] | None = None, **kwargs: Any) -> bool | None:  # noqa: ARG002
        if not ids:
            return None
        for start in range(0, len(ids), DELETE_BATCH_SIZE):
            self._request("POST", "/delete_by_ids", json={"ids": ids[start : start + DELETE_BATCH_SIZE]})
        return True

    def clear(self) -> None:
        """Delete every vector in the index (the index itself stays)."""
        cursor: str | None = None
        while True:
            params: dict[str, Any] = {"count": DELETE_BATCH_SIZE}
            if cursor:
                params["cursor"] = cursor
            page = self._request("GET", "/list", params=params) or {}
            ids = [vector["id"] for vector in page.get("vectors", [])]
            self.delete(ids)
            if not page.get("isTruncated"):
                return
            cursor = page.get("nextCursor")

    @classmethod
    def from_texts(
        cls,
        texts: list[str],
        embedding: Embeddings,
        metadatas: list[dict] | None = None,
        **kwargs: Any,  # noqa: ARG002
    ) -> "CloudflareVectorize":
        store = cls(embedding=embedding, **kwargs)
        store.add_texts(texts, metadatas)
        return store
