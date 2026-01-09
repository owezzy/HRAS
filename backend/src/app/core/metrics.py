"""Prometheus metrics collection for HRAS backend."""

from prometheus_client import Counter, Gauge, Histogram, Info

APP_INFO = Info("hras_app", "HRAS application information")

HTTP_REQUESTS_TOTAL = Counter(
    "hras_http_requests_total",
    "Total HTTP requests",
    ["method", "endpoint", "status_code"],
)

HTTP_REQUEST_DURATION_SECONDS = Histogram(
    "hras_http_request_duration_seconds",
    "HTTP request duration in seconds",
    ["method", "endpoint"],
    buckets=(0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0, 10.0),
)

ACTIVE_REQUESTS = Gauge(
    "hras_active_requests",
    "Number of active requests",
)

RAG_QUERIES_TOTAL = Counter(
    "hras_rag_queries_total",
    "Total RAG pipeline queries",
    ["status"],
)

RAG_QUERY_DURATION_SECONDS = Histogram(
    "hras_rag_query_duration_seconds",
    "RAG query duration in seconds",
    buckets=(0.1, 0.5, 1.0, 2.5, 5.0, 10.0, 30.0, 60.0),
)

MODEL_INFERENCE_TOTAL = Counter(
    "hras_model_inference_total",
    "Total model inference requests",
    ["model", "status"],
)

MODEL_INFERENCE_DURATION_SECONDS = Histogram(
    "hras_model_inference_duration_seconds",
    "Model inference duration in seconds",
    ["model"],
    buckets=(0.1, 0.5, 1.0, 2.5, 5.0, 10.0, 30.0, 60.0, 120.0),
)

MODEL_TOKENS_TOTAL = Counter(
    "hras_model_tokens_total",
    "Total tokens processed by models",
    ["model", "type"],
)

VECTOR_SEARCH_TOTAL = Counter(
    "hras_vector_search_total",
    "Total vector search operations",
    ["status"],
)

VECTOR_SEARCH_DURATION_SECONDS = Histogram(
    "hras_vector_search_duration_seconds",
    "Vector search duration in seconds",
    buckets=(0.01, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5),
)

VECTOR_SEARCH_RESULTS = Histogram(
    "hras_vector_search_results",
    "Number of results returned from vector search",
    buckets=(0, 1, 2, 5, 10, 20, 50, 100),
)

AGENT_EXECUTIONS_TOTAL = Counter(
    "hras_agent_executions_total",
    "Total agent workflow executions",
    ["agent_name", "status"],
)

AGENT_EXECUTION_DURATION_SECONDS = Histogram(
    "hras_agent_execution_duration_seconds",
    "Agent execution duration in seconds",
    ["agent_name"],
    buckets=(0.5, 1.0, 2.5, 5.0, 10.0, 30.0, 60.0, 120.0, 300.0),
)

AGENT_STEPS_TOTAL = Counter(
    "hras_agent_steps_total",
    "Total agent workflow steps executed",
    ["agent_name", "step_type"],
)

DOCUMENT_INGESTION_TOTAL = Counter(
    "hras_document_ingestion_total",
    "Total documents ingested",
    ["status"],
)

DOCUMENT_CHUNKS_TOTAL = Counter(
    "hras_document_chunks_total",
    "Total document chunks created",
)

EMBEDDINGS_GENERATED_TOTAL = Counter(
    "hras_embeddings_generated_total",
    "Total embeddings generated",
)

VECTORSTORE_DOCUMENTS = Gauge(
    "hras_vectorstore_documents",
    "Current number of documents in vector store",
)

CHAT_SESSIONS_ACTIVE = Gauge(
    "hras_chat_sessions_active",
    "Number of active chat sessions",
)

ERRORS_TOTAL = Counter(
    "hras_errors_total",
    "Total errors by type",
    ["error_type", "component"],
)


def init_app_info(version: str, environment: str) -> None:
    APP_INFO.info({
        "version": version,
        "environment": environment,
        "service": "hras-backend",
    })
