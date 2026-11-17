"""Run the HRAS offline eval: retrieval recall@k, faithfulness and latency.

Embeds evals/corpus.json into a local ChromaDB store (evals/.chroma, rebuilt when the corpus
changes), runs each question in evals/questions.json through the real agent workflow, and writes:

- evals/results/latest.json: every metric per question, including the claims the judge rejected
- docs/reference/EVALS.md: the results table, between the eval-results markers

Uses the chat model and embeddings configured in backend/.env. From backend/:

    PYTHONPATH=. uv run python evals/run_eval.py
"""

import asyncio
import json
import os
import sys
from dataclasses import asdict
from datetime import date
from pathlib import Path

EVALS_DIR = Path(__file__).resolve().parent
REPORT_PATH = EVALS_DIR.parent.parent / "docs" / "reference" / "EVALS.md"
START_MARKER, END_MARKER = "<!-- eval-results:start -->", "<!-- eval-results:end -->"
KS = (1, 3, 5, 8)  # 5 is the RAG chain's k; 8 is the research agent's k
INGEST_BATCH = 50

# Settings are read once and cached, so point them at the eval store before importing the app.
os.environ["VECTOR_STORE_BACKEND"] = "chroma"
os.environ["CHROMA_PERSIST_DIRECTORY"] = str(EVALS_DIR / ".chroma")
os.environ["USE_LANGSMITH_TRACING"] = "false"

from src.app.ai.agents.graph import run_agent_workflow  # noqa: E402
from src.app.ai.evaluation.offline import (  # noqa: E402
    QuestionResult,
    evaluate,
    llm_judge,
    load_questions,
    render_markdown,
    summarize,
)
from src.app.ai.vectorstore.document_loader import UHRIDocumentLoader  # noqa: E402
from src.app.ai.vectorstore.store import get_vector_store  # noqa: E402
from src.app.core.config import get_settings  # noqa: E402
from src.app.core.llm import get_deterministic_llm  # noqa: E402


def ensure_corpus_indexed(corpus: list[dict]) -> None:
    store = get_vector_store()
    if store.get_collection_stats()["count"] == len(corpus):
        return
    print(f"Embedding {len(corpus)} records into {os.environ['CHROMA_PERSIST_DIRECTORY']} ...")
    store.clear_collection()
    documents = UHRIDocumentLoader().to_documents(corpus)
    for start in range(0, len(documents), INGEST_BATCH):
        store.add_documents(documents[start : start + INGEST_BATCH])


def write_report(table: str) -> None:
    report = REPORT_PATH.read_text()
    before, rest = report.split(START_MARKER, 1)
    _, after = rest.split(END_MARKER, 1)
    REPORT_PATH.write_text(f"{before}{START_MARKER}\n{table}\n{END_MARKER}{after}")


def print_progress(result: QuestionResult) -> None:
    recall = " ".join(f"@{k}={v:.0%}" for k, v in result.recall.items())
    faith = "n/a" if result.faithfulness is None else f"{result.faithfulness:.0%}"
    print(f"{result.id:>4} {result.route:<9} recall {recall}  faithfulness {faith}  {result.answer_ms / 1000:.1f}s")


async def main() -> None:
    settings = get_settings()
    corpus = json.loads((EVALS_DIR / "corpus.json").read_text())
    questions = load_questions(EVALS_DIR / "questions.json")
    ensure_corpus_indexed(corpus)

    store = get_vector_store()

    async def retrieve(question: str, k: int) -> list[str]:
        return [doc.metadata["id"] for doc in await store.asimilarity_search(question, k=k)]

    results = await evaluate(
        questions,
        retrieve=retrieve,
        answer=run_agent_workflow,
        judge=llm_judge(get_deterministic_llm()),
        ks=KS,
        on_result=print_progress,
    )

    summary = summarize(results, KS)
    meta = {
        "date": date.today().isoformat(),
        "llm_model": settings.resolved_llm_model,
        "embedding_model": settings.embedding_model,
        "corpus_size": len(corpus),
    }
    (EVALS_DIR / "results").mkdir(exist_ok=True)
    (EVALS_DIR / "results" / "latest.json").write_text(
        json.dumps({"meta": meta, "summary": summary, "results": [asdict(r) for r in results]}, indent=2) + "\n"
    )
    table = render_markdown(summary, results, KS, meta)
    write_report(table)
    print(f"\n{table}\n\nWrote {REPORT_PATH} and evals/results/latest.json")


if __name__ == "__main__":
    sys.exit(asyncio.run(main()))
