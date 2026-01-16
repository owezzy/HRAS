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
make docker-build-backend
```

### Local Development with Kind

[Kind](https://kind.sigs.k8s.io/) (Kubernetes IN Docker) provides a local Kubernetes cluster for development.

**Prerequisites:**
- Docker running
- [kind](https://kind.sigs.k8s.io/docs/user/quick-start/#installation) installed
- kubectl installed
- Ollama running on host machine

**Quick Start:**

```bash
make kind-create          # Create Kind cluster
make kind-load            # Build and load backend image
make kind-deploy          # Deploy backend + postgres (auto-ingests data)
make kind-status          # Check status
```

**Access the app:**
- Backend API: http://localhost:8000
- Health check: http://localhost:8000/health
- PostgreSQL: localhost:30432

**Useful Commands:**

| Command | Description |
|---------|-------------|
| `make kind-create` | Create Kind cluster |
| `make kind-delete` | Delete Kind cluster |
| `make kind-load` | Build and load backend image |
| `make kind-deploy` | Deploy backend + postgres (auto-ingestion included) |
| `make kind-deploy-backend` | Deploy backend only |
| `make kind-deploy-postgres` | Deploy PostgreSQL only |
| `make kind-status` | Show pods and services |
| `make kind-logs` | Tail all logs |
| `make kind-logs-backend` | Tail backend logs |
| `make kind-clean` | Remove HRAS from cluster |

**Ollama Configuration:**

The dev overlay configures Ollama to use `host.docker.internal:11434` (macOS/Windows).

For Linux, update `zarf/k8s/dev/backend/configmap.yaml`:

```yaml
ollama_base_url: "http://172.17.0.1:11434"
```

### Production Deployment with K3s

K3s is a lightweight Kubernetes distribution ideal for production on AWS EC2.

**Quick Start:**

```bash
make k3s-setup      # Install K3s on EC2 instance (run via SSH)
make k3s-deploy     # Deploy HRAS to K3s cluster
make k3s-status     # Check deployment status
make k3s-teardown   # Remove HRAS and K3s
```

**Production K3s Commands:**

| Command | Description |
|---------|-------------|
| `make k3s-setup` | Install K3s with Nginx Ingress on EC2 |
| `make k3s-deploy` | Deploy HRAS backend to K3s |
| `make k3s-status` | Show K3s cluster status |
| `make k3s-logs` | View backend logs |
| `make k3s-teardown` | Remove K3s and all resources |

See [docs/KUBERNETES.md](docs/KUBERNETES.md) for comprehensive deployment documentation.

### Directory Structure (Ardan Labs Pattern)

```
zarf/
├── docker/
│   ├── dockerfile.backend     # Backend Dockerfile
│   └── README.md              # Build documentation
├── k8s/
│   ├── base/                  # Base manifests (backend, postgres, monitoring, ingress)
│   ├── dev/                   # Kind local development overlay
│   └── prod/                  # K3s production overlay
└── scripts/
    ├── k3s-setup.sh           # Install K3s on EC2
    ├── k3s-deploy.sh          # Deploy HRAS to K3s
    └── k3s-teardown.sh        # Teardown K3s cluster
```

**Key Patterns:**
- Base manifests use placeholder images (`backend-image`)
- Overlays use `images:` transformer to swap actual image names
- ConfigMaps are environment-specific (in overlay, not base)
- Frontend deployed separately on AWS Amplify

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

---

## AWS Production Deployment

### Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│ AWS Amplify (Frontend)                                      │
│ • Next.js application with Fuse React UI                   │
│ • Auto-scaling, global CDN                                 │
│ • Custom domain: hras.owezzy.tech                          │
│ • www redirect: www.hras.owezzy.tech → hras.owezzy.tech    │
└─────────────────────────────────────────────────────────────┘
                              │ API calls
                              ▼
┌─────────────────────────────────────────────────────────────┐
│ AWS EC2 (Backend + Monitoring)                             │
│ • FastAPI backend with RAG pipeline                        │
│ • PostgreSQL database                                       │
│ • Prometheus + Grafana monitoring                          │
│ • Ollama local LLM (no API costs)                         │
│ • ChromaDB vector store                                     │
└─────────────────────────────────────────────────────────────┘
```

### Cost Breakdown

**Monthly AWS Costs (~$25/month):**
- EC2 t3.small (2 vCPU, 2GB RAM): $15.18
- EBS Storage (20GB): $2.00
- Elastic IP: $3.65
- Data Transfer: $2-5
- **AWS Amplify**: Free tier (generous limits)
- **LLM Inference**: $0 (Ollama local)

### Deployment Guides

- **[EC2 Backend Deployment](./docs/deployment/aws/EC2_DEPLOYMENT.md)** - Complete backend setup
- **[Amplify Frontend Deployment](./docs/deployment/aws/AMPLIFY_DEPLOYMENT.md)** - Next.js frontend setup
- **[Monitoring Setup](./docs/deployment/aws/MONITORING_SETUP.md)** - Prometheus + Grafana configuration
- **[Domain & SSL Configuration](./docs/deployment/aws/DOMAIN_SSL.md)** - Custom domain setup
- **[Troubleshooting Guide](./docs/deployment/aws/TROUBLESHOOTING.md)** - Common issues and solutions

### Quick Deploy Commands

```bash
# 1. Deploy Backend to EC2
./scripts/deploy-ec2.sh

# 2. Deploy Frontend to Amplify
git push origin main  # Auto-deploys via Amplify

# 3. Configure custom domain
./scripts/setup-domain.sh hras.owezzy.tech
```

### Environment URLs

- **Production Frontend**: https://hras.owezzy.tech
- **Production API**: http://your-ec2-ip:8000
- **Monitoring (Grafana)**: http://your-ec2-ip:3001
- **Metrics (Prometheus)**: http://your-ec2-ip:9090
