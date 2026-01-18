# HRAS Backend

Human Rights Advisory System - AI-powered advisory for UN human rights officers.

## Features

- **RAG Pipeline**: Retrieval-augmented generation over UN human rights documents
- **Multi-Agent System**: LangGraph-based workflow with specialized agents
- **Vector Search**: ChromaDB for semantic document retrieval
- **Source Citations**: Every response includes document references
- **Conversation Persistence**: Optional PostgreSQL storage for chat history
- **Feature Flags**: Gradual rollout of new functionality

## Quick Start

```bash
# Install dependencies
uv sync

# Set up environment variables
cp .env.example .env
# Edit .env with your configuration

# Run development server
PYTHONPATH=. uv run uvicorn src.app.main:app --reload

# Server starts at http://localhost:8000
```

## API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/health` | Health check - verify server status |
| `GET` | `/` | Welcome message |
| `POST` | `/api/v1/chat` | Process chat message through RAG pipeline |
| `GET` | `/api/v1/conversations` | List conversations (requires `use_postgres` flag) |
| `GET` | `/api/v1/conversations/{id}` | Get conversation by ID |
| `DELETE` | `/api/v1/conversations/{id}` | Delete conversation |
| `POST` | `/api/v1/admin/ingest` | Ingest documents into vector store |
| `GET` | `/api/v1/admin/stats` | Get vector store statistics |

### Chat Endpoint

**Request:**
```bash
curl -X POST http://localhost:8000/api/v1/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "What human rights recommendations exist for Kenya?"}'
```

**Response:**
```json
{
  "conversation_id": "550e8400-e29b-41d4-a716-446655440000",
  "message": {
    "role": "assistant",
    "content": "Based on the UN Human Rights Index..."
  },
  "sources": [
    {
      "title": "UPR Recommendation 2021",
      "document_type": "UPR",
      "country": "Kenya",
      "year": 2021,
      "excerpt": "..."
    }
  ]
}
```

## Development Commands

```bash
# Start dev server with hot reload
PYTHONPATH=. uv run uvicorn src.app.main:app --reload

# Lint code
uv run ruff check src

# Format code
uv run ruff format src

# Run all tests
uv run pytest tests/ -v

# Run tests with coverage
uv run pytest tests/ --cov=src --cov-report=term-missing

# Run specific test file
uv run pytest tests/test_core.py -v

# Run tests matching pattern
uv run pytest tests/ -k "test_chat" -v
```

## Testing

The test suite includes 97 tests across multiple layers:

| Test File | Tests | Coverage |
|-----------|-------|----------|
| `test_smoke.py` | 16 | Baseline endpoint tests |
| `test_core.py` | 13 | Settings, async utilities |
| `test_repositories.py` | 15 | ConversationRepository CRUD |
| `test_services.py` | 15 | ChatService, DataIngestionService |
| `test_agents_chains.py` | 27 | Agent graph, RAG chain, vectorstore |
| `test_integration.py` | 11 | API endpoint integration |

```bash
# Run full test suite
uv run pytest tests/ -v

# Run with parallel execution
uv run pytest tests/ -n auto
```

## Architecture

```
backend/
├── src/app/                 # FastAPI application
│   ├── api/routes/          # HTTP endpoints
│   ├── core/                # Config, dependencies, utilities
│   │   ├── config.py        # Settings with feature flags
│   │   ├── database.py      # Async SQLAlchemy setup
│   │   ├── async_utils.py   # Async wrappers
│   │   ├── metrics.py       # Prometheus metrics
│   │   ├── instrumentation.py # LLM & vectorstore metrics wrappers
│   │   └── logging.py       # Structured logging
│   ├── ai/                  # AI/ML components
│   │   ├── agents/          # LangGraph agents
│   │   │   ├── graph.py     # Workflow definition
│   │   │   ├── nodes.py     # Agent implementations
│   │   │   └── state.py     # State schema
│   │   ├── chains/          # LangChain LCEL chains
│   │   ├── tools/           # Agent tools (UHRI client)
│   │   ├── vectorstore/     # ChromaDB setup
│   │   └── prompts/         # Prompt templates
│   ├── services/            # Business logic
│   ├── schemas/             # Pydantic models
│   ├── models/              # SQLAlchemy ORM
│   └── repositories/        # Database access
├── tests/                   # Pytest tests
└── alembic/                 # Database migrations
```

## Multi-Agent System

The system uses a supervisor pattern with three specialized agents:

1. **Research Agent** - Document search and retrieval
2. **Advisory Agent** - Generate recommendations with citations
3. **Compare Agent** - Cross-country analysis

## Feature Flags

Feature flags in `src/app/core/config.py` enable gradual rollout:

| Flag | Default | Description |
|------|---------|-------------|
| `use_postgres` | `false` | Enable PostgreSQL for conversation persistence |
| `use_async_tools` | `true` | Use async tool execution in agents |

Set via environment variables:
```bash
USE_POSTGRES=true
USE_ASYNC_TOOLS=true
```

## Database Setup (PostgreSQL)

When `use_postgres` is enabled:

```bash
# Start PostgreSQL with Docker
docker compose up -d postgres

# Run migrations
uv run alembic upgrade head

# Check migration status
uv run alembic current
```

## Environment Variables

```env
# LLM Configuration
OLLAMA_BASE_URL=http://localhost:11434
OLLAMA_MODEL=nemotron-3-nano:30b-cloud
OLLAMA_EMBEDDING_MODEL=nomic-embed-text

# Vector Store
CHROMA_PERSIST_DIRECTORY=./chroma_db

# Database (optional, requires use_postgres=true)
DATABASE_URL=postgresql+asyncpg://hras:hras@localhost:5432/hras

# Feature Flags
USE_POSTGRES=false
USE_ASYNC_TOOLS=true

# CORS
CORS_ORIGINS=["http://localhost:3000"]
```

## API Documentation

**Local Development:**
- Swagger UI: http://localhost:8000/docs
- ReDoc: http://localhost:8000/redoc
- OpenAPI JSON: http://localhost:8000/openapi.json

**Production:**
- Base URL: https://api.hras.owezzy.tech
- Swagger UI: https://api.hras.owezzy.tech/docs
- Health Check: https://api.hras.owezzy.tech/health

**Note**: Production API is served through Caddy reverse proxy with automatic HTTPS via Let's Encrypt.

## Tech Stack

- **FastAPI** - Async web framework
- **LangChain** - LLM orchestration
- **LangGraph** - Multi-agent workflows
- **Ollama** - Local LLM inference
- **ChromaDB** - Vector store
- **SQLAlchemy 2.0** - Async ORM
- **Alembic** - Database migrations
- **Pydantic v2** - Data validation
- **Prometheus** - Metrics collection
- **structlog** - Structured logging
