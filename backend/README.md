# HRAS Backend

Human Rights Advisory System - AI-powered advisory for UN human rights officers.

## Features

- **RAG Pipeline**: Retrieval-augmented generation over UN human rights documents
- **Multi-Agent System**: LangGraph-based workflow with specialized agents
- **Vector Search**: ChromaDB for semantic document retrieval
- **Source Citations**: Every response includes document references

## Quick Start

```bash
# Install dependencies
uv sync

# Set up environment variables
cp .env.example .env
# Edit .env with your API keys

# Run development server
uv run dev

# Server starts at http://localhost:8000
```

## API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/api/health` | Health check - verify server status |
| `POST` | `/api/chat` | Process chat message through RAG pipeline |
| `POST` | `/api/admin/ingest` | Ingest documents into vector store |
| `GET` | `/api/admin/stats` | Get vector store statistics |

### Chat Endpoint

**Request:**
```bash
curl -X POST http://localhost:8000/api/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "What human rights recommendations exist for Kenya?"}'
```

**Response:**
```json
{
  "response": "Based on the UN Human Rights Index...",
  "sources": [
    {
      "title": "UPR Recommendation 2021",
      "document_type": "UPR",
      "country": "Kenya",
      "year": 2021,
      "excerpt": "..."
    }
  ],
  "query_type": "research"
}
```

## Development Commands

```bash
# Start dev server with hot reload
uv run dev

# Lint code
uv run lint

# Format code
uv run format

# Type check
uv run typecheck

# Run tests
uv run test

# Run tests with coverage
uv run pytest --cov=src
```

## Architecture

```
backend/
├── src/app/                 # FastAPI application
│   ├── api/routes/          # HTTP endpoints
│   ├── core/                # Config, dependencies
│   ├── services/            # Business logic
│   ├── schemas/             # Pydantic models
│   ├── models/              # SQLAlchemy ORM
│   └── repositories/        # Database access
├── agents/                  # LangGraph agents
│   ├── graph.py             # Workflow definition
│   ├── nodes.py             # Agent implementations
│   └── state.py             # State schema
├── chains/                  # LangChain LCEL chains
├── tools/                   # Agent tools (UHRI client)
├── vectorstore/             # ChromaDB setup
├── prompts/                 # Prompt templates
└── tests/                   # Pytest tests
```

## Multi-Agent System

The system uses a supervisor pattern with three specialized agents:

1. **Research Agent** - Document search and retrieval
2. **Advisory Agent** - Generate recommendations with citations
3. **Compare Agent** - Cross-country analysis

## Environment Variables

```env
# Required
OPENAI_API_KEY=sk-...

# Optional (defaults shown)
OPENAI_MODEL=gpt-4-turbo-preview
CHROMA_PERSIST_DIRECTORY=./chroma_data
DATABASE_URL=postgresql+asyncpg://...
```

## API Documentation

- Swagger UI: http://localhost:8000/docs
- ReDoc: http://localhost:8000/redoc

## Tech Stack

- **FastAPI** - Async web framework
- **LangChain** - LLM orchestration
- **LangGraph** - Multi-agent workflows
- **ChromaDB** - Vector store
- **OpenAI** - Embeddings & LLM
- **Pydantic v2** - Data validation
- **SQLAlchemy 2.0** - ORM (async)
