"""Tests for the offline evaluation metrics and runner."""

import json

import pytest

from src.app.ai.evaluation.offline import (
    EvalQuestion,
    FaithfulnessVerdict,
    evaluate,
    load_questions,
    parse_verdict,
    percentile,
    recall_at_k,
    render_markdown,
    summarize,
)
from src.app.ai.tools.uhri_client import normalize_export_record


class TestRecallAtK:
    def test_counts_gold_records_inside_the_cutoff(self) -> None:
        assert recall_at_k(["a", "x", "b", "c"], ["a", "b", "c"], k=3) == pytest.approx(2 / 3)

    def test_ignores_results_past_k(self) -> None:
        assert recall_at_k(["x", "y", "a"], ["a"], k=2) == 0.0

    def test_rejects_empty_gold_set(self) -> None:
        with pytest.raises(ValueError):
            recall_at_k(["a"], [], k=1)


class TestPercentile:
    def test_interpolates_between_ranks(self) -> None:
        assert percentile([1, 2, 3, 4], 50) == 2.5
        assert percentile([10, 20, 30, 40, 50], 95) == pytest.approx(48)

    def test_single_value(self) -> None:
        assert percentile([7], 95) == 7


class TestParseVerdict:
    def test_scores_supported_share_and_keeps_unsupported_claims(self) -> None:
        reply = 'Here you go:\n{"claims": [{"claim": "A", "supported": true}, {"claim": "B", "supported": false}]}'
        verdict = parse_verdict(reply)
        assert verdict == FaithfulnessVerdict(supported=1, total=2, unsupported_claims=("B",))
        assert verdict.score == 0.5

    def test_no_claims_has_no_score(self) -> None:
        assert parse_verdict('{"claims": []}').score is None

    def test_rejects_reply_without_json(self) -> None:
        with pytest.raises(ValueError):
            parse_verdict("I could not judge this.")


def test_load_questions_rejects_missing_gold(tmp_path) -> None:
    path = tmp_path / "q.json"
    path.write_text(json.dumps([{"id": "q1", "question": "?", "gold_ids": [], "kind": "research"}]))
    with pytest.raises(ValueError, match="q1"):
        load_questions(path)


async def test_evaluate_runs_each_stage_and_summarizes() -> None:
    questions = [
        EvalQuestion(id="q1", question="Kenya torture?", gold_ids=("1", "2"), kind="research"),
        EvalQuestion(id="q2", question="Advise on Brazil", gold_ids=("3",), kind="advisory"),
    ]
    rankings = {"Kenya torture?": ["1", "9", "2"], "Advise on Brazil": ["8", "9", "7"]}

    async def retrieve(question: str, k: int) -> list[str]:
        return rankings[question][:k]

    async def answer(question: str) -> dict:
        route = "research" if "Kenya" in question else "advisory"
        context = ["doc"] if route == "research" else []
        return {"answer": "text", "context": context, "query_type": route}

    async def judge(_answer: str, context: list[str]) -> FaithfulnessVerdict:
        return FaithfulnessVerdict(supported=2, total=2) if context else FaithfulnessVerdict(0, 3, ("x", "y", "z"))

    results = await evaluate(questions, retrieve=retrieve, answer=answer, judge=judge, ks=(1, 3))

    assert [r.recall for r in results] == [{1: 0.5, 3: 1.0}, {1: 0.0, 3: 0.0}]
    assert [r.faithfulness for r in results] == [1.0, 0.0]
    assert results[1].unsupported_claims == ["x", "y", "z"]

    summary = summarize(results, ks=(1, 3))
    assert summary["overall"]["recall@3"] == 0.5
    assert summary["overall"]["faithfulness"] == 0.5
    assert summary["by_route"]["advisory"]["faithfulness"] == 0.0

    table = render_markdown(
        summary,
        results,
        ks=(1, 3),
        meta={"date": "2026-11-17", "llm_model": "m", "embedding_model": "e", "corpus_size": 3},
    )
    assert "| **All** | 2 | 25% | 50% | 50% |" in table
    assert "| q2 | advisory | advisory | 0% | 0% | 0% | 3 |" in table


def test_normalize_export_record_flattens_uhri_export_fields() -> None:
    record = {
        "AnnotationId": "abc",
        "Symbol": "CCPR/C/KEN/CO/4",
        "Text": '<p style="font-weight:bold;">Adopt a law on\n enforced disappearances&rsquo;</p>',
        "AnnotationType": "- Recommendations",
        "Body": "- CCPR",
        "Countries": ["Kenya"],
        "Themes": ["Enforced disappearances", " Right to life"],
        "PublicationDate": "2021-05-11T00:00:00",
        "UprCycle": None,
        "UprPositions": [],
        "UprRecommendingCountry": [],
    }
    assert normalize_export_record(record) == {
        "id": "abc",
        "country": "Kenya",
        "mechanism": "CCPR",
        "cycle": "",
        "year": "2021",
        "recommending_state": None,
        "recommendation": "Adopt a law on enforced disappearances\u2019",
        "theme": "Enforced disappearances; Right to life",
        "status": "",
        "annotation_type": "Recommendations",
        "symbol": "CCPR/C/KEN/CO/4",
    }
