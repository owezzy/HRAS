# HRAS - Human Rights Advisory System

## Project Overview

AI-powered advisory system for UN human rights officers. RAG pipeline over UN documents with multi-agent orchestration using Ollama.

---

## Quick Start

```bash
# Install dependencies
make install

# Start development servers
make dev
```

---

## Frontend (Next.js 15 + Fuse React)

### Commands

```bash
cd frontend
npm run dev          # Start dev server with Turbopack
npm run build        # Production build
npm run start        # Start production server
npm run lint         # Run ESLint
npm run lint:fix     # Fix ESLint issues
```

### Code Style

**Prettier Configuration:**
- Tabs for indentation (tabWidth: 4)
- Single quotes
- No trailing commas
- Print width: 120 characters
- Semicolons required
- Single attribute per line in JSX
- Arrow parens: always

**ESLint Rules:**
- `unused-imports/no-unused-imports`: error
- `no-console`: error (except console.error)
- Unused vars with `_` prefix are allowed
- Blank lines required around functions and if statements

### TypeScript

**Compiler Options:**
- Target: ESNext
- Strict mode: OFF (legacy codebase)
- Module resolution: Node
- JSX: preserve

**Path Aliases:**
```typescript
@auth/*        → ./src/@auth/*
@i18n/*        → ./src/@i18n/*
@fuse/*        → ./src/@fuse/*
@history*      → ./src/@history
@mock-utils/*  → ./src/@mock-utils/*
@schema        → ./src/@schema
@/*            → ./src/*
```

### React Patterns

**Components:**
- Functional components only
- Named exports preferred
- Use React hooks (useState, useEffect, useMemo, useCallback)
- React Query for data fetching (@tanstack/react-query)
- react-hook-form + zod for forms

**State Management:**
- Local state: useState/useReducer
- Server state: React Query
- Form state: react-hook-form

**Styling:**
- TailwindCSS 4 for utility classes
- MUI 7 for components
- Emotion for MUI styling overrides
- Use clsx for conditional classes

---

## Backend (Python FastAPI)

### Commands

```bash
cd backend
PYTHONPATH=. uv run uvicorn src.app.main:app --reload  # Dev server
uv run pytest                                           # Run tests
uv run ruff check src                                   # Lint
uv run ruff format src                                  # Format
```

### Code Style

**Ruff Configuration:**
- Line length: 120
- Python 3.12+
- Import sorting: isort-compatible

**Type Hints:**
- All functions must have type hints
- Use `typing` module types
- Pydantic v2 for data validation

### Python Patterns

**Architecture (4-Layer):**
```
src/app/
├── api/routes/      # FastAPI routers (thin, validation only)
├── services/        # Business logic
├── repositories/    # Database access (SQLAlchemy)
├── models/          # SQLAlchemy ORM models
├── schemas/         # Pydantic request/response schemas
└── core/            # Config, dependencies, exceptions
```

**Dependency Injection:**
```python
def get_service(
    repo: Annotated[Repository, Depends(get_repository)],
) -> Service:
    return Service(repo)
```

**Async Patterns:**
- All I/O operations must be async
- Use `async with` for context managers
- Use `asyncio.gather` for parallel operations

---

## AI/ML (LangChain + LangGraph + Ollama)

### LLM Configuration

- **Model**: Nemotron 3 Nano (30B cloud) via Ollama
- **Embeddings**: nomic-embed-text via Ollama
- **Vector Store**: ChromaDB

### Structure

```
backend/src/app/
├── ai/                  # AI/ML components
│   ├── agents/          # LangGraph agent definitions
│   ├── chains/          # LangChain LCEL chains
│   ├── tools/           # Agent tools (search, retrieve, etc.)
│   ├── vectorstore/     # Embedding and retrieval logic
│   └── prompts/         # Prompt templates
├── api/routes/          # FastAPI routers
├── core/                # Config, dependencies, metrics
├── services/            # Business logic
├── schemas/             # Pydantic models
├── models/              # SQLAlchemy ORM
└── repositories/        # Database access
```

### Patterns

**RAG Chain:**
```python
chain = (
    {"context": retriever, "question": RunnablePassthrough()}
    | prompt
    | llm
    | StrOutputParser()
)
```

**LangGraph Agent:**
```python
graph = StateGraph(AgentState)
graph.add_node("retrieve", retrieve_node)
graph.add_node("generate", generate_node)
graph.add_edge("retrieve", "generate")
graph.add_edge(START, "retrieve")
graph.add_edge("generate", END)
```

**Tool Definition:**
```python
@tool
def search_uhri(query: str) -> list[dict]:
    """Search UN Human Rights Index for relevant documents."""
    ...
```

---

## Testing

### Backend
```bash
cd backend
uv run pytest                    # Run all tests
uv run pytest -v                 # Verbose
uv run pytest --cov=src          # With coverage
uv run pytest -k "test_name"     # Run specific test
```

**Test Patterns:**
- Use pytest fixtures for setup
- Use pytest-asyncio for async tests
- Mock external services with pytest-mock
- Use httpx AsyncClient for API tests

---

## Environment Variables

### Backend (.env)
```
OLLAMA_BASE_URL=http://localhost:11434
OLLAMA_MODEL=nemotron-3-nano:30b-cloud
OLLAMA_EMBEDDING_MODEL=nomic-embed-text
CHROMA_PERSIST_DIRECTORY=./chroma_db
DATABASE_URL=sqlite+aiosqlite:///./hras.db
```

### Frontend (.env.local)
```
NEXT_PUBLIC_API_URL=http://localhost:8000
AUTH_SECRET=your-auth-secret
```

---

## Git Conventions

**Commit Messages:**
```
feat: add human rights document search
fix: resolve RAG retrieval timeout
docs: update API documentation
refactor: extract embedding logic
test: add unit tests for advisor agent
```

**Branch Names (git-flow):**
```
feature/rag-pipeline
bugfix/auth-session-timeout
release/v0.1.0
hotfix/critical-fix
```
