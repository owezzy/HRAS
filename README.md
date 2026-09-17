# HRAS - Human Rights Advisory System

AI-powered advisory system for UN human rights officers. Uses RAG (Retrieval-Augmented Generation) over UN Human Rights Index (UHRI) documents with multi-agent orchestration powered by LangChain and LangGraph.

## 🌐 Production Links

| Resource | URL |
|----------|-----|
| **Application** | https://hras.owenadirah.com |
| **API** | https://backend-production-f15e.up.railway.app |
| **API Documentation** | https://backend-production-f15e.up.railway.app/docs |
| **Health Check** | https://backend-production-f15e.up.railway.app/health |
| **Repository** | https://github.com/owezzy/HRAS |

## 📚 Onboarding Guide

### For New Users (Non-Technical)

1. **Access the Application**: Visit https://hras.owenadirah.com
2. **Start a Conversation**: Navigate to the Chat interface
3. **Ask Questions**: Type natural language questions about UN human rights recommendations
4. **View Sources**: Each response includes citations from UHRI documents

### For New Developers

| Step | Action | Documentation |
|------|--------|---------------|
| 1 | Read this README | Understand project overview and architecture |
| 2 | Review [Docs Index](./docs/00-INDEX.md) | Navigate all documentation |
| 3 | Set up local environment | Follow [Quick Start](#quick-start-local-development) below |
| 4 | Explore Backend | [Backend README](./backend/README.md) - API, testing, agents |
| 5 | Explore Frontend | [Frontend README](./frontend/README.md) - UI, components, styling |
| 6 | Understand Deployment | [Deployment Guide](./docs/deployment/DEPLOYMENT.md) - Railway production setup |

### For DevOps / Operators

| Task | Documentation |
|------|---------------|
| Deploy | Push to `main` - Railway builds and deploys automatically |
| Configure Secrets | Set service variables in the Railway dashboard |
| Troubleshoot Issues | [Troubleshooting Guide](./docs/operations/TROUBLESHOOTING.md) |

---

## Overview

HRAS enables human rights officers to ask natural language questions about UN human rights recommendations and receive AI-generated responses with source citations from UHRI documents.

**Key Features:**
- Conversational AI interface for querying UN human rights data
- RAG pipeline with semantic search across UHRI documents
- Multi-agent system for retrieval, generation, and validation
- Source attribution for every response
- Production-ready deployment on Railway

## Tech Stack

| Component | Technology |
|-----------|------------|
| **Frontend** | Next.js 15, React 19, MUI 7, TailwindCSS 4 |
| **Backend** | Python 3.12+, FastAPI, LangChain, LangGraph |
| **AI/LLM** | DeepSeek (`deepseek-flash`) via an OpenAI-compatible API |
| **Embeddings** | Cloudflare Workers AI (`@cf/baai/bge-small-en-v1.5`) |
| **Vector Store** | ChromaDB |
| **Database** | PostgreSQL (production) / SQLite (development) |
| **Monitoring** | LangSmith tracing |
| **CI/CD** | Railway (builds from the repository on push) |

## Quick Start (Local Development)

### Prerequisites

- Node.js >= 22.12.0
- Python 3.12+
- [uv](https://docs.astral.sh/uv/) (Python package manager)
- [Ollama](https://ollama.com/) installed and running

### Installation

```bash
# Clone repository
git clone https://github.com/owezzy/HRAS.git
cd HRAS

# Install dependencies
make install

# Set up Ollama
ollama serve                    # Terminal 1
ollama login                    # Required for cloud models
ollama pull nomic-embed-text    # Embedding model

# Configure environment
cp backend/.env.example backend/.env
# Edit backend/.env if needed

# Run development servers
make dev                        # Starts frontend + backend
# Frontend: http://localhost:3000
# Backend:  http://localhost:8000
```

### First-Time Data Setup

```bash
# Ingest UHRI sample data (do this once)
make ingest

# Verify ingestion
make db-stats
```

## Production Deployment

### Architecture

| Service | Host | Notes |
|---------|------|-------|
| **Frontend** | https://hras.owenadirah.com | Next.js standalone (`Dockerfile.multi-stage`), TLS via Let's Encrypt |
| **Backend** | https://backend-production-f15e.up.railway.app | FastAPI (`Dockerfile`), ChromaDB on a persistent volume |

**Backend providers:** DeepSeek (`deepseek-flash`) for chat, Cloudflare Workers AI
(`@cf/baai/bge-small-en-v1.5`) for embeddings, LangSmith for tracing.

### Deployment

Both services build from this repository on push to `main`.

| Service | Root Directory | Dockerfile |
|---------|----------------|------------|
| Frontend | `frontend` | `Dockerfile.multi-stage` |
| Backend | `backend` | `Dockerfile` |

**Required service variables:**

| Variable | Service | Description |
|----------|---------|-------------|
| `LLM_API_KEY` | backend | DeepSeek API key |
| `EMBEDDING_BASE_URL` | backend | Host serving the embedding model |
| `EMBEDDING_API_KEY` | backend | Key for that host |
| `AUTH_SECRET` | frontend | NextAuth session secret |

### CI/CD Pipeline

Deployment runs automatically on push to `main`:

```
Railway (repository integration)
```

**Pipeline:** Railway detects the push, builds each service image, and rolls out
the new version. A failed build leaves the previous deployment running.

### Monthly Cost

- Railway: usage-based, no fixed server cost
- LLM inference: pay-per-token (DeepSeek)
- Embeddings: pay-per-token (Cloudflare Workers AI)
- Stale `zarf/`, `nginx/`, and `docs/deployment/aws/` directories remain for
  reference only and are not part of the current deployment path.

## Configuration

### Backend Environment Variables

Copy `backend/.env.example` to `backend/.env` and configure:

```env
# Application
APP_ENV=development
DEBUG=true

# Database (SQLite for dev, PostgreSQL for production)
DATABASE_URL=sqlite+aiosqlite:///./hras.db

# Chat LLM (OpenAI-compatible: deepseek | openai | openrouter | ollama | custom)
LLM_PROVIDER=deepseek
LLM_API_KEY=
LLM_MODEL=deepseek-flash

# Embeddings (configured independently of chat)
EMBEDDING_BASE_URL=
EMBEDDING_API_KEY=
EMBEDDING_MODEL=@cf/baai/bge-small-en-v1.5

# Vector Store
CHROMA_PERSIST_DIRECTORY=./chroma_db

# CORS Origins (include frontend URL)
CORS_ORIGINS=["http://localhost:3000"]

# Feature Flags
USE_POSTGRES=false
USE_ASYNC_TOOLS=true
```

### Frontend Environment Variables

Create `frontend/.env` for local development:

```env
# API URL
NEXT_PUBLIC_API_URL=http://localhost:8000

# Base URL
NEXT_PUBLIC_BASE_URL=http://localhost:3000

# Auth Configuration
AUTH_URL=http://localhost:3000
AUTH_SECRET=your-secret-here  # Generate with: openssl rand -base64 32

# Optional: OAuth Providers
AUTH_GOOGLE_ID=
AUTH_GOOGLE_SECRET=
```

Production variables are set as Railway service variables.

## Documentation

| Category | Key Documents |
|----------|---------------|
| **Development** | [Backend README](./backend/README.md) · [Frontend README](./frontend/README.md) · [Dev Guide](./docs/development/DEVELOPMENT.md) |
| **Deployment** | [Deployment Guide](./docs/deployment/DEPLOYMENT.md) · [Backend README](./backend/README.md) |
| **Architecture** | [System Architecture](./docs/architecture/ARCHITECTURE.md) · [AI/ML Pipeline](./docs/architecture/AI_ML.md) |
| **Reference** | [API Documentation](./docs/reference/API.md) · [Docs Index](./docs/00-INDEX.md) · [Troubleshooting](./docs/operations/TROUBLESHOOTING.md) |

## Common Commands

```bash
# Development
make dev              # Run frontend + backend
make frontend-dev     # Frontend only (port 3000)
make backend-dev      # Backend only (port 8000)
make install          # Install all dependencies
make lint             # Run linters
make test             # Run tests
make format           # Format code

# Data Management
make ingest           # Ingest UHRI sample data
make ingest-clear     # Clear and re-ingest
make db-stats         # Show vector store stats

# Docker (for Kind local Kubernetes)
make kind-create      # Create local K8s cluster
make kind-deploy      # Deploy to Kind
make kind-status      # Check deployment
make kind-clean       # Remove cluster

# Utilities
make clean            # Clean build artifacts
make build            # Build frontend for production
```

See `make help` for full command list.

## Project Structure

```
HRAS/
├── frontend/                  # Next.js 15 application
│   ├── src/
│   │   ├── app/               # App router pages
│   │   ├── @fuse/             # Fuse React UI components
│   │   └── components/        # HRAS components
│   ├── .env.production        # Production environment
│   └── README.md              # Frontend docs
├── backend/                   # FastAPI application
│   ├── src/app/               # Main application
│   │   ├── api/               # API routes
│   │   ├── core/              # Config, dependencies
│   │   ├── schemas/           # Pydantic models
│   │   ├── services/          # Business logic
│   │   └── ai/                # AI/ML components
│   │       ├── agents/        # LangGraph multi-agent system
│   │       ├── chains/        # LangChain LCEL chains
│   │       ├── tools/         # Agent tools (UHRI client)
│   │       ├── vectorstore/   # ChromaDB management
│   │       └── prompts/       # Prompt templates
│   ├── tests/                 # Pytest suite
│   ├── .env.example           # Environment template
│   └── README.md              # Backend docs
├── docs/                      # Documentation
│   ├── 00-INDEX.md            # Quick navigation
│   ├── architecture/          # System design docs
│   ├── deployment/            # Deployment guides
│   ├── development/           # Developer guides
│   ├── operations/            # Operations docs
│   └── reference/             # API reference
├── zarf/                      # Legacy deployment configs (not in the deploy path)
│   ├── docker/                # Dockerfiles & Docker Compose
│   │   ├── compose/           # Docker Compose configurations
│   │   ├── caddy/             # Caddy reverse proxy config
│   │   └── monitoring/        # Loki, Promtail configs
│   ├── monitoring/            # Prometheus, Grafana configs
│   ├── k8s/                   # Kubernetes manifests
│   └── scripts/               # Deployment scripts
├── .github/workflows/         # CI/CD pipeline
│   └── deploy-production-docker.yml
├── Makefile                   # Common tasks
└── README.md                  # This file
```

## Getting Help

- Check **[Troubleshooting Guide](./docs/operations/TROUBLESHOOTING.md)** for common issues
- Review **[API Documentation](./docs/reference/API.md)** for endpoint details
- See **[Development Guide](./docs/development/DEVELOPMENT.md)** for setup help
- Open a GitHub issue for bugs or feature requests

## License

MIT License - See LICENSE file for details
