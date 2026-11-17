"""Offline evaluation of HRAS: retrieval recall@k, answer faithfulness and latency.

Runs a labelled question set through the real retrieval and agent workflow:

- **Retrieval recall@k**: the share of a question's gold UHRI records that appear in the
  top k results of the vector search the agents start from.
- **Faithfulness**: an LLM judge splits the final answer into factual claims and checks each
  one against the document text the agents were given. Score = supported / total claims.
- **Latency**: wall-clock time for the vector search and for the full answer.

Questions run one at a time so latencies are not inflated by concurrent requests.
"""

from __future__ import annotations

import json
import math
import re
import time
from collections.abc import Awaitable, Callable, Sequence
from dataclasses import dataclass, field
from pathlib import Path

from langchain_core.language_models import BaseChatModel
from langchain_core.messages import HumanMessage


@dataclass(frozen=True)
class EvalQuestion:
    id: str
    question: str
    gold_ids: tuple[str, ...]
    kind: str  # the question type it was written as: research, compare or advisory


@dataclass(frozen=True)
class FaithfulnessVerdict:
    supported: int
    total: int
    unsupported_claims: tuple[str, ...] = ()

    @property
    def score(self) -> float | None:
        """Supported share of claims, or None when the answer makes no factual claims."""
        return self.supported / self.total if self.total else None


@dataclass
class QuestionResult:
    id: str
    kind: str
    route: str
    recall: dict[int, float]
    retrieval_ms: float
    answer_ms: float
    faithfulness: float | None
    claims: int
    unsupported_claims: list[str] = field(default_factory=list)
    context_docs: int = 0


Retrieve = Callable[[str, int], Awaitable[list[str]]]
Answer = Callable[[str], Awaitable[dict]]
Judge = Callable[[str, list[str]], Awaitable[FaithfulnessVerdict]]


def load_questions(path: Path) -> list[EvalQuestion]:
    rows = json.loads(path.read_text())
    questions = [
        EvalQuestion(id=r["id"], question=r["question"], gold_ids=tuple(r["gold_ids"]), kind=r["kind"]) for r in rows
    ]
    for q in questions:
        if not q.gold_ids:
            raise ValueError(f"Question {q.id} has no gold_ids")
    return questions


def recall_at_k(retrieved_ids: Sequence[str], gold_ids: Sequence[str], k: int) -> float:
    """Share of gold records found in the first k retrieved records."""
    gold = set(gold_ids)
    if not gold:
        raise ValueError("gold_ids must not be empty")
    return len(gold & set(retrieved_ids[:k])) / len(gold)


def percentile(values: Sequence[float], pct: float) -> float:
    """Percentile with linear interpolation between closest ranks (pct in 0..100)."""
    if not values:
        raise ValueError("values must not be empty")
    ordered = sorted(values)
    rank = (len(ordered) - 1) * pct / 100
    low, high = math.floor(rank), math.ceil(rank)
    return ordered[low] + (ordered[high] - ordered[low]) * (rank - low)


FAITHFULNESS_PROMPT = """You are checking whether an answer is supported by its source documents.

1. Split the ANSWER into its individual factual claims about human-rights recommendations,
   countries, mechanisms, years, themes or statuses. Skip advice, opinions, offers of help and
   statements about the answer itself (for example "the sources do not cover X").
2. For each claim, decide whether the SOURCES state or directly imply it. General knowledge
   that is not in the SOURCES does not count as support.

Reply with JSON only, in this shape:
{{"claims": [{{"claim": "<claim>", "supported": true}}]}}

SOURCES:
{sources}

ANSWER:
{answer}"""


def parse_verdict(text: str) -> FaithfulnessVerdict:
    """Parse the judge's JSON reply. Raises ValueError when it is not the expected shape."""
    match = re.search(r"\{.*\}", text, re.DOTALL)
    if not match:
        raise ValueError(f"No JSON object in judge reply: {text[:200]!r}")
    claims = json.loads(match.group())["claims"]
    supported = [c for c in claims if c.get("supported") is True]
    unsupported = tuple(str(c.get("claim", "")) for c in claims if c.get("supported") is not True)
    return FaithfulnessVerdict(supported=len(supported), total=len(claims), unsupported_claims=unsupported)


def llm_judge(llm: BaseChatModel) -> Judge:
    async def judge(answer: str, context: list[str]) -> FaithfulnessVerdict:
        sources = "\n\n".join(f"[{i}] {doc}" for i, doc in enumerate(context, 1)) or "(no sources were provided)"
        reply = await llm.ainvoke([HumanMessage(content=FAITHFULNESS_PROMPT.format(sources=sources, answer=answer))])
        return parse_verdict(str(reply.content))

    return judge


async def evaluate(
    questions: Sequence[EvalQuestion],
    *,
    retrieve: Retrieve,
    answer: Answer,
    judge: Judge,
    ks: Sequence[int],
    on_result: Callable[[QuestionResult], None] = lambda _r: None,
) -> list[QuestionResult]:
    results = []
    for q in questions:
        start = time.perf_counter()
        retrieved = await retrieve(q.question, max(ks))
        retrieval_ms = (time.perf_counter() - start) * 1000

        start = time.perf_counter()
        response = await answer(q.question)
        answer_ms = (time.perf_counter() - start) * 1000

        context = response.get("context", [])
        verdict = await judge(response.get("answer", ""), context)

        result = QuestionResult(
            id=q.id,
            kind=q.kind,
            route=response.get("query_type", "unknown"),
            recall={k: recall_at_k(retrieved, q.gold_ids, k) for k in ks},
            retrieval_ms=retrieval_ms,
            answer_ms=answer_ms,
            faithfulness=verdict.score,
            claims=verdict.total,
            unsupported_claims=list(verdict.unsupported_claims),
            context_docs=len(context),
        )
        on_result(result)
        results.append(result)
    return results


def _mean(values: Sequence[float]) -> float | None:
    return sum(values) / len(values) if values else None


def summarize(results: Sequence[QuestionResult], ks: Sequence[int]) -> dict:
    """Aggregate metrics overall and per agent route."""

    def block(rows: Sequence[QuestionResult]) -> dict:
        scored = [r.faithfulness for r in rows if r.faithfulness is not None]
        claims = sum(r.claims for r in rows)
        return {
            "questions": len(rows),
            **{f"recall@{k}": _mean([r.recall[k] for r in rows]) for k in ks},
            "faithfulness": _mean(scored),
            "claims": claims,
            "unsupported_claims": sum(len(r.unsupported_claims) for r in rows),
            "answer_ms_p50": percentile([r.answer_ms for r in rows], 50),
            "answer_ms_p95": percentile([r.answer_ms for r in rows], 95),
            "retrieval_ms_p50": percentile([r.retrieval_ms for r in rows], 50),
            "retrieval_ms_p95": percentile([r.retrieval_ms for r in rows], 95),
        }

    routes = sorted({r.route for r in results})
    return {
        "overall": block(results),
        "by_route": {route: block([r for r in results if r.route == route]) for route in routes},
    }


def _pct(value: float | None) -> str:
    return "n/a" if value is None else f"{value:.0%}"


def _secs(ms: float) -> str:
    return f"{ms / 1000:.1f} s" if ms >= 1000 else f"{ms:.0f} ms"


def render_markdown(summary: dict, results: Sequence[QuestionResult], ks: Sequence[int], meta: dict) -> str:
    recall_cols = " | ".join(f"Recall@{k}" for k in ks)
    header = f"| | Questions | {recall_cols} | Faithfulness | Answer p50 | Answer p95 | Search p50 |"
    divider = "|---|---:|" + "---:|" * len(ks) + "---:|---:|---:|---:|"

    def row(label: str, b: dict) -> str:
        recalls = " | ".join(_pct(b[f"recall@{k}"]) for k in ks)
        return (
            f"| {label} | {b['questions']} | {recalls} | {_pct(b['faithfulness'])} | "
            f"{_secs(b['answer_ms_p50'])} | {_secs(b['answer_ms_p95'])} | {_secs(b['retrieval_ms_p50'])} |"
        )

    lines = [
        f"Run {meta['date']} · chat model `{meta['llm_model']}` (also the judge) · "
        f"embeddings `{meta['embedding_model']}` · {meta['corpus_size']} UHRI records",
        "",
        header,
        divider,
        row("**All**", summary["overall"]),
        *(row(f"Route: {route}", b) for route, b in summary["by_route"].items()),
        "",
        "<details><summary>Per-question results</summary>",
        "",
        f"| ID | Written as | Routed to | {recall_cols} | Faithfulness | Claims | Answer |",
        "|---|---|---|" + "---:|" * len(ks) + "---:|---:|---:|",
    ]
    for r in results:
        recalls = " | ".join(_pct(r.recall[k]) for k in ks)
        lines.append(
            f"| {r.id} | {r.kind} | {r.route} | {recalls} | {_pct(r.faithfulness)} | {r.claims} | {_secs(r.answer_ms)} |"
        )
    lines += ["", "</details>"]
    return "\n".join(lines)
