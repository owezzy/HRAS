# Evaluation

HRAS is measured offline on 30 labelled questions over 480 real UHRI recommendations. The eval reports three things:

| Metric | What it measures |
|--------|------------------|
| **Recall@k** | Share of a question's gold UHRI records in the top k results of the vector search the agents start from. k = 5 is the RAG chain's cut-off and k = 8 is the research agent's. |
| **Faithfulness** | Share of the factual claims in the final answer that the documents given to the agents support. An LLM judge splits the answer into claims and checks each one. |
| **Latency** | Wall-clock time for the full answer (supervisor and agents) and for the vector search alone, at p50 and p95. |

## Results

<!-- eval-results:start -->
Run 2026-11-18 · chat model `deepseek-flash` (also the judge) · embeddings `@cf/baai/bge-small-en-v1.5` · 480 UHRI records

| | Questions | Recall@1 | Recall@3 | Recall@5 | Recall@8 | Faithfulness | Answer p50 | Answer p95 | Search p50 |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| **All** | 30 | 27% | 64% | 81% | 89% | 96% | 36.8 s | 52.3 s | 846 ms |
| Route: advisory | 4 | 17% | 29% | 52% | 75% | 99% | 44.4 s | 50.8 s | 867 ms |
| Route: compare | 4 | 19% | 57% | 66% | 66% | 94% | 50.9 s | 63.8 s | 831 ms |
| Route: research | 22 | 30% | 72% | 89% | 96% | 96% | 34.2 s | 41.9 s | 846 ms |

<details><summary>Per-question results</summary>

| ID | Written as | Routed to | Recall@1 | Recall@3 | Recall@5 | Recall@8 | Faithfulness | Claims | Answer |
|---|---|---|---:|---:|---:|---:|---:|---:|---:|
| r01 | research | research | 0% | 33% | 100% | 100% | 95% | 19 | 29.5 s |
| r02 | research | research | 33% | 100% | 100% | 100% | 96% | 27 | 37.1 s |
| r03 | research | research | 50% | 100% | 100% | 100% | 95% | 20 | 26.2 s |
| r04 | research | research | 25% | 75% | 100% | 100% | 93% | 27 | 39.8 s |
| r05 | research | research | 25% | 50% | 75% | 75% | 95% | 60 | 51.2 s |
| r06 | research | research | 33% | 100% | 100% | 100% | 91% | 35 | 23.4 s |
| r07 | research | research | 25% | 50% | 75% | 100% | 93% | 29 | 33.7 s |
| r08 | research | research | 33% | 67% | 67% | 67% | 100% | 15 | 25.5 s |
| r09 | research | research | 25% | 25% | 50% | 75% | 100% | 26 | 39.4 s |
| r10 | research | research | 50% | 100% | 100% | 100% | 100% | 25 | 28.1 s |
| r11 | research | research | 50% | 100% | 100% | 100% | 95% | 21 | 28.5 s |
| r12 | research | research | 33% | 67% | 100% | 100% | 100% | 27 | 32.8 s |
| r13 | research | research | 50% | 100% | 100% | 100% | 100% | 16 | 27.0 s |
| r14 | research | research | 50% | 100% | 100% | 100% | 100% | 28 | 35.4 s |
| r15 | research | research | 0% | 0% | 67% | 100% | 100% | 26 | 36.8 s |
| r16 | research | research | 50% | 100% | 100% | 100% | 93% | 27 | 39.8 s |
| r17 | research | research | 33% | 67% | 100% | 100% | 92% | 37 | 35.0 s |
| r18 | research | research | 25% | 50% | 75% | 100% | 95% | 20 | 34.8 s |
| r19 | research | research | 20% | 60% | 80% | 100% | 96% | 25 | 31.3 s |
| r20 | research | research | 25% | 75% | 100% | 100% | 91% | 33 | 42.0 s |
| r21 | research | research | 0% | 100% | 100% | 100% | 100% | 26 | 22.2 s |
| r22 | research | research | 20% | 60% | 80% | 100% | 100% | 25 | 36.8 s |
| c01 | compare | compare | 20% | 60% | 60% | 60% | 90% | 80 | 49.1 s |
| c02 | compare | compare | 20% | 60% | 60% | 60% | 91% | 65 | 65.8 s |
| c03 | compare | compare | 17% | 50% | 83% | 83% | 100% | 32 | 41.7 s |
| c04 | compare | compare | 20% | 60% | 60% | 60% | 93% | 61 | 52.6 s |
| a01 | advisory | advisory | 33% | 33% | 67% | 67% | 100% | 14 | 43.4 s |
| a02 | advisory | advisory | 0% | 0% | 0% | 33% | 100% | 31 | 45.3 s |
| a03 | advisory | advisory | 0% | 50% | 75% | 100% | 94% | 18 | 41.8 s |
| a04 | advisory | advisory | 33% | 33% | 67% | 100% | 100% | 37 | 51.8 s |

</details>
<!-- eval-results:end -->

"Route" is where the supervisor sent the question. It decides whether the answering agent sees any retrieved documents, so faithfulness is reported per route.

## Findings

The first run (2026-11-17, saved as `backend/evals/results/2026-11-17-baseline.json`) found two grounding bugs. Both are fixed, and the table above is the run on the fixed code.

| Faithfulness | Baseline | Fixed |
|---|---:|---:|
| All 30 questions | 77% (239 of 815 claims unsupported) | 96% (43 of 932) |
| Advisory route | 0% | 99% |
| Compare route | 34% | 94% |
| Research route | 97% | 96% |

- **Advisory answers were not grounded.** The supervisor sent advisory questions straight to the advisory agent, which got no retrieved documents and answered from model memory. Advisory questions now go through the research agent first, so the advice is built on retrieved UHRI records.
- **Comparison answers lost their evidence.** The compare agent retrieved records, but the advisory agent wrote the final answer from a prompt that left the comparison out. The advisory prompt now includes the comparison, and the compare agent returns its records as sources (it returned none before).
- **Retrieval ranks the right records just below the top.** Recall@1 is 27% and recall@3 is 64%, but recall@8 is 89%, and 96% on research questions. Gold records are usually retrieved, but behind other records from the same country. A reranker is the most likely way to lift the top of the list.
- **Latency comes from the three sequential LLM calls.** Answers take a median of about 37 s, and the vector search takes under 1 s.

Each number comes from a single run, and the judge is an LLM, so expect a few points of variation between runs. The research route went from 97% to 96% without any change to that path.

## Method

**Corpus.** `backend/evals/corpus.json` holds 60 recommendations for each of 8 countries (Kenya, Brazil, India, Mexico, the Philippines, Nigeria, Ukraine and Colombia), published from 2015, sliced from the UHRI full export by `backend/evals/build_corpus.py`. The slice is committed because the export is about 380 MB and changes daily.

**Questions.** `backend/evals/questions.json` holds 30 questions, written the way an officer would ask them:

- 22 research questions about one country and one theme
- 4 comparison questions across two countries
- 4 advisory questions asking what to prioritise

Each question lists its gold records. A gold record is a corpus record for the question's country (or countries) that is tagged with the question's theme and whose text answers it. Every gold record was read before it was labelled.

**Faithfulness judge.** The judge is the same chat model that writes the answers (`deepseek-flash`), at temperature 0. A model judging its own output tends to be lenient, so treat the score as an upper bound. The judge sees exactly the document text the agents put in their prompts (`context` in the workflow result), not the whole corpus. An answer with no factual claims gets no score, and it is left out of the average.

**Latency.** Questions run one at a time against hosted model APIs from a laptop, so the numbers include network time. Use them to compare runs with each other, not as production latency.

## Running the eval

1. In `backend/.env`, set the chat model (`LLM_API_KEY`) and an embedding provider (`EMBEDDING_BASE_URL`, `EMBEDDING_API_KEY`, `EMBEDDING_MODEL`). To match production, use Workers AI:

   ```bash
   EMBEDDING_BASE_URL=https://api.cloudflare.com/client/v4/accounts/<account-id>/ai/v1
   EMBEDDING_MODEL=@cf/baai/bge-small-en-v1.5
   ```

2. From `backend/`, run:

   ```bash
   PYTHONPATH=. uv run python evals/run_eval.py
   ```

   The first run embeds the corpus into `backend/evals/.chroma`, which git ignores. The script then rewrites the results table above and `backend/evals/results/latest.json`. That file lists every claim the judge rejected.

To rebuild the corpus from a newer export, see the docstring in `backend/evals/build_corpus.py`. Rebuilding changes the record IDs, so the gold labels in `questions.json` have to be redone.
