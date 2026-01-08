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
# Build backend image
docker build -t hras-backend:latest ./backend

# Build frontend image
docker build -t hras-frontend:latest ./frontend
```

### Kubernetes Deployment

The `k8s/` directory contains Kubernetes manifests using Kustomize.

**Prerequisites:**
- Kubernetes cluster (minikube, kind, or cloud provider)
- kubectl configured
- Nginx Ingress Controller installed
- cert-manager (optional, for TLS)
- Ollama running externally (accessible from cluster)

**Deploy:**

```bash
# Create namespace and deploy all resources
kubectl apply -k k8s/

# Check deployment status
kubectl get pods -n hras
kubectl get services -n hras
kubectl get ingress -n hras
```

**Configuration:**

1. Update `k8s/backend-configmap.yaml` with your Ollama endpoint:
   ```yaml
   OLLAMA_BASE_URL: "http://your-ollama-host:11434"
   ```

2. Update `k8s/ingress.yaml` with your domain:
   ```yaml
   - host: your-domain.com
   ```

3. For production, create secrets for sensitive data:
   ```bash
   kubectl create secret generic hras-secrets \
     --from-literal=database-url=your-db-url \
     -n hras
   ```

**Manifest Overview:**

| File | Description |
|------|-------------|
| `namespace.yaml` | HRAS namespace |
| `backend-configmap.yaml` | Backend environment variables |
| `backend-deployment.yaml` | Backend pods with PVC for ChromaDB |
| `backend-service.yaml` | Backend ClusterIP service (port 8000) |
| `frontend-deployment.yaml` | Frontend pods |
| `frontend-service.yaml` | Frontend ClusterIP service (port 3000) |
| `ingress.yaml` | Nginx ingress with TLS support |
| `kustomization.yaml` | Kustomize configuration |

**Note:** Ollama is expected to run outside the cluster (on GPU nodes or as a managed service). Update `OLLAMA_BASE_URL` in the configmap to point to your Ollama instance.

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
