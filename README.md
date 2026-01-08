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
# Create Kind cluster with ingress support
make kind-create

# Build images and load into cluster
make kind-load

# Deploy HRAS
make kind-deploy

# Check status
make kind-status
```

**Access the app:**
- Frontend: http://localhost
- API: http://localhost/api
- Health check: http://localhost/health

**Useful Commands:**

| Command | Description |
|---------|-------------|
| `make kind-create` | Create Kind cluster with ingress |
| `make kind-delete` | Delete Kind cluster |
| `make kind-load` | Build and load images into cluster |
| `make kind-deploy` | Deploy HRAS to cluster |
| `make kind-status` | Show pods, services, ingress status |
| `make kind-logs` | Tail logs from all HRAS pods |
| `make kind-logs-backend` | Tail backend logs only |
| `make kind-logs-frontend` | Tail frontend logs only |
| `make kind-clean` | Remove HRAS resources from cluster |

**Ollama Configuration:**

For Kind to access Ollama running on your host machine, update `k8s/backend-configmap.yaml`:

```yaml
# On macOS/Windows (Docker Desktop):
OLLAMA_BASE_URL: "http://host.docker.internal:11434"

# On Linux:
OLLAMA_BASE_URL: "http://172.17.0.1:11434"
```

### Production Kubernetes Deployment

For production clusters (GKE, EKS, AKS, etc.):

```bash
# Deploy using Kustomize
kubectl apply -k k8s/

# Check deployment status
kubectl get pods -n hras
kubectl get services -n hras
kubectl get ingress -n hras
```

**Configuration:**

1. Update `k8s/backend-configmap.yaml` with your Ollama endpoint
2. Update `k8s/ingress.yaml` with your domain
3. Update image names in deployments if using a container registry
4. Create secrets for sensitive data:
   ```bash
   kubectl create secret generic hras-secrets \
     --from-literal=database-url=your-db-url \
     -n hras
   ```

**Manifest Overview:**

| File | Description |
|------|-------------|
| `namespace.yaml` | HRAS namespace |
| `kind-config.yaml` | Kind cluster config with ingress ports |
| `backend-configmap.yaml` | Backend environment variables |
| `backend-deployment.yaml` | Backend pods with PVC for ChromaDB |
| `backend-service.yaml` | Backend ClusterIP service (port 8000) |
| `frontend-deployment.yaml` | Frontend pods |
| `frontend-service.yaml` | Frontend ClusterIP service (port 3000) |
| `ingress.yaml` | Nginx ingress with TLS support |
| `kustomization.yaml` | Kustomize configuration |

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
