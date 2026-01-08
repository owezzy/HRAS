# HRAS - Human Rights Advisory System

AI-powered advisory system for UN human rights officers. Uses RAG (Retrieval-Augmented Generation) over UHRI documents with multi-agent orchestration.

## Tech Stack

| Layer | Technology |
|-------|------------|
| Frontend | Next.js 15, React 19, MUI 7, TailwindCSS 4 |
| Backend | Python 3.12+, FastAPI, LangChain, LangGraph |
| AI/LLM | Ollama + Nemotron 3 Nano (30B cloud model) |
| Embeddings | nomic-embed-text (via Ollama) |
| Vector Store | ChromaDB |
| Data Source | UHRI (UN Human Rights Index) |

## Prerequisites

- Node.js >= 22.12.0
- Python 3.12+
- [uv](https://docs.astral.sh/uv/) (Python package manager)
- [Ollama](https://ollama.com/) installed and running

## Ollama Setup

The app uses Nemotron 3 Nano, a cloud model that requires Ollama authentication.

```bash
# Install Ollama (if not installed)
curl -fsSL https://ollama.com/install.sh | sh

# Start Ollama service
ollama serve

# Login to Ollama (required for cloud models)
ollama login

# Pull the embedding model
ollama pull nomic-embed-text

# The nemotron-3-nano:30b-cloud model is pulled automatically on first use
```

## Installation

```bash
# Clone the repository
git clone <repo-url>
cd HRAS

# Install all dependencies
make install
```

## Configuration

```bash
# Copy environment template
cp backend/.env.example backend/.env
```

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `OLLAMA_BASE_URL` | Ollama server URL | `http://localhost:11434` |
| `OLLAMA_MODEL` | LLM model for chat | `nemotron-3-nano:30b-cloud` |
| `OLLAMA_EMBEDDING_MODEL` | Embedding model | `nomic-embed-text` |
| `CHROMA_PERSIST_DIRECTORY` | Vector store path | `./chroma_db` |
| `DATABASE_URL` | Database connection | `sqlite+aiosqlite:///./hras.db` |
| `CORS_ORIGINS` | Allowed origins | `["http://localhost:3000"]` |

## Running the App

### Development Mode

```bash
# Run both frontend and backend
make dev

# Or run separately:
make frontend-dev  # Terminal 1 - http://localhost:3000
make backend-dev   # Terminal 2 - http://localhost:8000
```

### Production Mode

```bash
make prod
```

## Data Ingestion

Before using the chat, ingest UHRI data into the vector store:

```bash
# Start backend first, then:
make ingest        # Ingest sample UHRI data
make db-stats      # Verify ingestion (shows document count)

# To clear and re-ingest:
make ingest-clear
```

## Available Commands

| Command | Description |
|---------|-------------|
| `make dev` | Run frontend + backend in dev mode |
| `make frontend-dev` | Run frontend only (Next.js with Turbopack) |
| `make backend-dev` | Run backend only (FastAPI with hot reload) |
| `make install` | Install all dependencies |
| `make build` | Build frontend for production |
| `make lint` | Run linters (ESLint + Ruff) |
| `make test` | Run backend tests |
| `make format` | Format code |
| `make ingest` | Ingest UHRI data |
| `make db-stats` | Show vector store statistics |
| `make clean` | Clean build artifacts |

## API Documentation

See [docs/API.md](docs/API.md) for detailed API documentation.

## Docker & Kubernetes Deployment

### Building Docker Images

```bash
# Build all images
make docker-build

# Or build individually:
make docker-build-backend   # Build backend image
make docker-build-frontend  # Build frontend image
```

### Local Development with Kind

[Kind](https://kind.sigs.k8s.io/) (Kubernetes IN Docker) lets you run a local Kubernetes cluster for development.

**Prerequisites:**
- Docker running
- [kind](https://kind.sigs.k8s.io/docs/user/quick-start/#installation) installed
- kubectl installed
- Ollama running on host machine

**Quick Start:**

```bash
make kind-create    # Create Kind cluster
make kind-load      # Build and load images
make kind-deploy    # Deploy backend and frontend
make kind-status    # Check status
```

**Access the app:**
- Frontend: http://localhost:3000
- Backend API: http://localhost:8000
- Health check: http://localhost:8000/health

**Useful Commands:**

| Command | Description |
|---------|-------------|
| `make kind-create` | Create Kind cluster |
| `make kind-delete` | Delete Kind cluster |
| `make kind-load` | Build and load images |
| `make kind-deploy` | Deploy backend and frontend |
| `make kind-deploy-backend` | Deploy backend only |
| `make kind-deploy-frontend` | Deploy frontend only |
| `make kind-status` | Show pods and services |
| `make kind-logs` | Tail all logs |
| `make kind-logs-backend` | Tail backend logs |
| `make kind-logs-frontend` | Tail frontend logs |
| `make kind-clean` | Remove HRAS from cluster |

**Ollama Configuration:**

The dev overlay configures Ollama to use `host.docker.internal:11434` (macOS/Windows).

For Linux, update `k8s/dev/backend/dev-backend-configmap.yaml`:

```yaml
ollama_base_url: "http://172.17.0.1:11434"
```

### Production Kubernetes Deployment

For production, create a `k8s/prod/` overlay similar to `k8s/dev/` with production-specific patches.

**Directory Structure (Ardan Labs pattern):**

```
k8s/
├── base/
│   ├── backend/
│   │   ├── kustomization.yaml
│   │   └── base-backend.yaml      # Deployment, Service, PVC
│   └── frontend/
│       ├── kustomization.yaml
│       └── base-frontend.yaml     # Deployment, Service
└── dev/
    ├── kind-config.yaml           # Kind cluster port mappings
    ├── backend/
    │   ├── kustomization.yaml     # References base, applies patches
    │   ├── dev-backend-configmap.yaml
    │   ├── dev-backend-patch-deploy.yaml
    │   └── dev-backend-patch-service.yaml
    └── frontend/
        ├── kustomization.yaml
        ├── dev-frontend-patch-deploy.yaml
        └── dev-frontend-patch-service.yaml
```

**Key patterns:**
- Base manifests use placeholder images (`backend-image`, `frontend-image`)
- Overlays use `images:` transformer to swap actual image names
- Patches are separate files for deploy/service modifications
- ConfigMaps are environment-specific (in overlay, not base)
- hostNetwork: true for direct port access (no ingress needed for dev)

## Project Structure

```
HRAS/
├── frontend/          # Next.js 15 application
│   ├── src/
│   │   ├── app/       # App router pages
│   │   ├── @fuse/     # Fuse UI components
│   │   └── components/
│   └── package.json
├── backend/           # FastAPI application
│   ├── src/app/       # Main application
│   │   ├── api/       # API routes
│   │   ├── core/      # Config, dependencies
│   │   ├── schemas/   # Pydantic models
│   │   └── services/  # Business logic
│   ├── agents/        # LangGraph agents
│   ├── chains/        # LangChain LCEL chains
│   ├── vectorstore/   # ChromaDB management
│   └── prompts/       # Prompt templates
├── Makefile           # Common commands
└── README.md
```
