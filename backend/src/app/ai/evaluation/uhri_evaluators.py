"""UHRI domain-specific evaluators for production monitoring.

These evaluators run in real-time during agent execution to provide
quality metrics for the HRAS multi-agent RAG system.
"""

from __future__ import annotations

import re
from typing import TYPE_CHECKING
from uuid import UUID

from src.app.core.config import get_settings
from src.app.core.logging import get_logger

if TYPE_CHECKING:
    from langsmith.evaluation import EvaluationResult
    from langsmith.schemas import Example, Run

logger = get_logger(__name__)

DIPLOMATIC_POSITIVE_TERMS = frozenset(
    {
        "recommendation",
        "treaty body",
        "state party",
        "universal periodic review",
        "upr",
        "cedaw",
        "cerd",
        "cat",
        "iccpr",
        "icescr",
        "mechanism",
        "implementation",
        "ratification",
        "human rights council",
        "special rapporteur",
        "working group",
    }
)

DIPLOMATIC_NEGATIVE_TERMS = frozenset(
    {
        "regime",
        "dictatorship",
        "terrorist state",
        "evil",
        "corrupt government",
        "failed state",
        "rogue nation",
    }
)

UN_MECHANISMS = frozenset(
    {
        "upr",
        "cedaw",
        "cerd",
        "cat",
        "iccpr",
        "icescr",
        "crc",
        "crpd",
        "cmw",
        "ced",
        "cescr",
        "ccpr",
        "special rapporteur",
        "working group",
        "treaty body",
        "human rights council",
    }
)


def _safe_get_output(run: Run, key: str, default: str = "") -> str:
    if run.outputs is None:
        return default
    value = run.outputs.get(key, default)
    return str(value) if value else default


def _safe_get_sources(run: Run) -> list[dict]:
    if run.outputs is None:
        return []
    sources = run.outputs.get("sources", [])
    if not isinstance(sources, list):
        return []
    return sources


def _safe_get_input(run: Run, key: str, default: str = "") -> str:
    if run.inputs is None:
        return default
    value = run.inputs.get(key, default)
    return str(value) if value else default


def _extract_keywords(text: str) -> set[str]:
    words = re.findall(r"\b[a-zA-Z]{3,}\b", text.lower())
    return set(words)


try:
    from langsmith.evaluation import EvaluationResult, RunEvaluator
    from langsmith.schemas import Example, Run

    class UNDiplomaticAppropriatenessEvaluator(RunEvaluator):  # pyright: ignore[reportRedeclaration]
        """Evaluates UN diplomatic language appropriateness in responses."""

        def evaluate_run(  # pyright: ignore[reportIncompatibleMethodOverride]
            self,
            run: Run,
            example: Example | None = None,  # noqa: ARG002
            evaluator_run_id: UUID | None = None,  # noqa: ARG002
        ) -> EvaluationResult:
            try:
                response_text = _safe_get_output(run, "answer", "")
                if not response_text:
                    response_text = _safe_get_output(run, "final_response", "")

                if not response_text:
                    return EvaluationResult(
                        key="un_diplomatic_appropriateness",
                        score=None,
                        comment="No response text found",
                    )

                text_lower = response_text.lower()

                positive_count = sum(1 for term in DIPLOMATIC_POSITIVE_TERMS if term in text_lower)

                negative_count = sum(1 for term in DIPLOMATIC_NEGATIVE_TERMS if term in text_lower)

                base_score = 0.5
                positive_boost = min(positive_count * 0.1, 0.5)
                negative_penalty = min(negative_count * 0.25, 0.5)

                score = max(0.0, min(1.0, base_score + positive_boost - negative_penalty))

                comment_parts = []
                if positive_count > 0:
                    comment_parts.append(f"{positive_count} diplomatic terms found")
                if negative_count > 0:
                    comment_parts.append(f"{negative_count} inappropriate terms found")
                if not comment_parts:
                    comment_parts.append("Neutral language detected")

                return EvaluationResult(
                    key="un_diplomatic_appropriateness",
                    score=score,
                    comment="; ".join(comment_parts),
                )

            except Exception as e:
                logger.warning("diplomatic_evaluator_error", error=str(e))
                return EvaluationResult(
                    key="un_diplomatic_appropriateness",
                    score=None,
                    comment=f"Evaluation error: {str(e)}",
                )

    class UHRISourceAccuracyEvaluator(RunEvaluator):  # pyright: ignore[reportRedeclaration]
        """Evaluates UHRI source citation quality in responses."""

        def evaluate_run(  # pyright: ignore[reportIncompatibleMethodOverride]
            self,
            run: Run,
            example: Example | None = None,  # noqa: ARG002
            evaluator_run_id: UUID | None = None,  # noqa: ARG002
        ) -> EvaluationResult:
            try:
                sources = _safe_get_sources(run)
                question = _safe_get_input(run, "question", "")

                if not sources:
                    return EvaluationResult(
                        key="uhri_source_accuracy",
                        score=0.0,
                        comment="No sources cited",
                    )

                citation_count = len(sources)
                if citation_count == 0:
                    citation_score = 0.0
                elif citation_count <= 2:
                    citation_score = 0.5
                else:
                    citation_score = 1.0

                mechanisms_found = set()
                for source in sources:
                    mechanism = ""
                    if isinstance(source, dict):
                        mechanism = source.get("mechanism", "").lower()
                    for mech in UN_MECHANISMS:
                        if mech in mechanism:
                            mechanisms_found.add(mech)

                mechanism_score = min(len(mechanisms_found) / 3.0, 1.0)

                query_countries = self._extract_countries_from_text(question)
                source_countries = set()
                for source in sources:
                    if isinstance(source, dict):
                        country = source.get("country", "").lower().strip()
                        if country:
                            source_countries.add(country)

                if not query_countries:
                    country_score = 1.0
                elif not source_countries:
                    country_score = 0.0
                else:
                    matching = len(query_countries & source_countries)
                    country_score = matching / len(query_countries)

                final_score = (0.4 * citation_score) + (0.3 * mechanism_score) + (0.3 * country_score)

                comment = (
                    f"Citations: {citation_count}, "
                    f"Mechanisms: {len(mechanisms_found)}, "
                    f"Country match: {country_score:.0%}"
                )

                return EvaluationResult(
                    key="uhri_source_accuracy",
                    score=final_score,
                    comment=comment,
                )

            except Exception as e:
                logger.warning("source_accuracy_evaluator_error", error=str(e))
                return EvaluationResult(
                    key="uhri_source_accuracy",
                    score=None,
                    comment=f"Evaluation error: {str(e)}",
                )

        def _extract_countries_from_text(self, text: str) -> set[str]:
            common_countries = {
                "kenya",
                "tanzania",
                "uganda",
                "ethiopia",
                "nigeria",
                "south africa",
                "egypt",
                "morocco",
                "algeria",
                "brazil",
                "mexico",
                "colombia",
                "argentina",
                "chile",
                "india",
                "china",
                "japan",
                "indonesia",
                "philippines",
                "thailand",
                "vietnam",
                "russia",
                "ukraine",
                "poland",
                "germany",
                "france",
                "united kingdom",
                "italy",
                "spain",
                "united states",
                "canada",
                "australia",
            }
            text_lower = text.lower()
            return {country for country in common_countries if country in text_lower}

    class RAGFaithfulnessEvaluator(RunEvaluator):  # pyright: ignore[reportRedeclaration]
        """Evaluates response faithfulness to retrieved documents."""

        def evaluate_run(  # pyright: ignore[reportIncompatibleMethodOverride]
            self,
            run: Run,
            example: Example | None = None,  # noqa: ARG002
            evaluator_run_id: UUID | None = None,  # noqa: ARG002
        ) -> EvaluationResult:
            try:
                response_text = _safe_get_output(run, "answer", "")
                if not response_text:
                    response_text = _safe_get_output(run, "final_response", "")

                sources = _safe_get_sources(run)

                if not response_text:
                    return EvaluationResult(
                        key="rag_faithfulness",
                        score=None,
                        comment="No response text found",
                    )

                if not sources:
                    return EvaluationResult(
                        key="rag_faithfulness",
                        score=0.5,
                        comment="No source documents to compare against",
                    )

                source_keywords = set()
                for source in sources:
                    if isinstance(source, dict):
                        snippet = source.get("snippet", "")
                        theme = source.get("theme", "")
                        mechanism = source.get("mechanism", "")
                        source_text = f"{snippet} {theme} {mechanism}"
                        source_keywords.update(_extract_keywords(source_text))

                if not source_keywords:
                    return EvaluationResult(
                        key="rag_faithfulness",
                        score=0.5,
                        comment="No meaningful content in source documents",
                    )

                response_keywords = _extract_keywords(response_text)

                stopwords = {
                    "the",
                    "and",
                    "for",
                    "with",
                    "that",
                    "this",
                    "from",
                    "are",
                    "was",
                    "were",
                    "been",
                    "have",
                    "has",
                    "had",
                    "will",
                    "would",
                    "could",
                    "should",
                    "may",
                    "can",
                    "not",
                    "but",
                    "also",
                    "more",
                    "than",
                    "into",
                    "their",
                    "these",
                    "those",
                    "other",
                    "which",
                    "when",
                    "where",
                    "what",
                    "who",
                    "how",
                }
                source_keywords -= stopwords
                response_keywords -= stopwords

                if not source_keywords:
                    return EvaluationResult(
                        key="rag_faithfulness",
                        score=0.5,
                        comment="Source documents contain only common words",
                    )

                overlap = response_keywords & source_keywords
                overlap_ratio = len(overlap) / len(source_keywords)

                score = min(overlap_ratio * 1.5, 1.0)

                return EvaluationResult(
                    key="rag_faithfulness",
                    score=score,
                    comment=f"Keyword overlap: {len(overlap)}/{len(source_keywords)} source terms used",
                )

            except Exception as e:
                logger.warning("faithfulness_evaluator_error", error=str(e))
                return EvaluationResult(
                    key="rag_faithfulness",
                    score=None,
                    comment=f"Evaluation error: {str(e)}",
                )

    EVALUATORS_AVAILABLE = True

except ImportError:
    EVALUATORS_AVAILABLE = False

    class UNDiplomaticAppropriatenessEvaluator:  # type: ignore[no-redef]  # pyright: ignore[reportRedeclaration]
        pass

    class UHRISourceAccuracyEvaluator:  # type: ignore[no-redef]  # pyright: ignore[reportRedeclaration]
        pass

    class RAGFaithfulnessEvaluator:  # type: ignore[no-redef]  # pyright: ignore[reportRedeclaration]
        pass


def get_production_evaluators() -> list:
    """Get list of evaluators for production monitoring.

    Respects feature flag:
    - enable_production_evaluations: Master toggle for evaluations

    Returns:
        List of evaluator instances, or empty list if disabled
    """
    if not EVALUATORS_AVAILABLE:
        logger.debug("evaluators_not_available", reason="langsmith not installed")
        return []

    settings = get_settings()

    if not settings.enable_production_evaluations:
        return []

    return [
        UNDiplomaticAppropriatenessEvaluator(),
        UHRISourceAccuracyEvaluator(),
        RAGFaithfulnessEvaluator(),
    ]
