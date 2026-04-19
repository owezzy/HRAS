# HRAS - Human Rights Advisory System

AI-powered advisory system for UN human rights officers. Uses RAG (Retrieval-Augmented Generation) over UN Human Rights Index (UHRI) documents with multi-agent orchestration powered by LangChain and LangGraph.

## 🌐 Production Links

| Resource | URL |
|----------|-----|
| **Application** | https://hras.owezzy.tech |
| **API** | https://hetzner-api.hras.owezzy.tech |
| **API Documentation** | https://hetzner-api.hras.owezzy.tech/docs |
| **Health Check** | https://hetzner-api.hras.owezzy.tech/health |
| **Repository** | https://github.com/owezzy/HRAS |

**Monitoring** (via SSH tunnel):

| Service | Local URL | SSH Tunnel Command |
|---------|-----------|-------------------|
| **Grafana** | http://localhost:3001 | `ssh -L 3001:localhost:3001 ubuntu@<EC2_HOST>` |
| **Prometheus** | http://localhost:9090 | `ssh -L 9090:localhost:9090 ubuntu@<EC2_HOST>` |
| **Loki** | http://localhost:3100 | `ssh -L 3100:localhost:3100 ubuntu@<EC2_HOST>` |

## 📚 Onboarding Guide

### For New Users (Non-Technical)

1. **Access the Application**: Visit https://hras.owezzy.tech
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
| 6 | Understand Deployment | [Deployment Guide](./docs/deployment/DEPLOYMENT.md) - Hetzner + Amplify production setup |

### For DevOps / Operators

| Task | Documentation |
|------|---------------|
| Deploy Backend (Hetzner) | [Deployment Guide](./docs/deployment/DEPLOYMENT.md#hetzner-production-deployment) |
| Deploy Frontend (Amplify) | [Amplify Deployment](./docs/deployment/aws/AMPLIFY_DEPLOYMENT.md) |
| Set up Monitoring | [Monitoring Setup](./docs/deployment/aws/MONITORING_SETUP.md) |
| Configure CI/CD | See [CI/CD Pipeline](#cicd-pipeline) section below |
| Troubleshoot Issues | [Troubleshooting Guide](./docs/operations/TROUBLESHOOTING.md) |

---

## Overview

HRAS enables human rights officers to ask natural language questions about UN human rights recommendations and receive AI-generated responses with source citations from UHRI documents.

**Key Features:**
- Conversational AI interface for querying UN human rights data
- RAG pipeline with semantic search across UHRI documents
- Multi-agent system for retrieval, generation, and validation
- Source attribution for every response
- Production-ready deployment on AWS Amplify + Hetzner

## Tech Stack

| Component | Technology |
|-----------|------------|
| **Frontend** | Next.js 15, React 19, MUI 7, TailwindCSS 4 |
| **Backend** | Python 3.12+, FastAPI, LangChain, LangGraph |
| **AI/LLM** | Ollama + Nemotron 3 Nano (30B cloud model) |
| **Embeddings** | nomic-embed-text (via Ollama) |
| **Vector Store** | ChromaDB |
| **Database** | PostgreSQL (production) / SQLite (development) |
| **Monitoring** | Prometheus + Grafana + Loki |
| **CI/CD** | GitHub Actions |

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

```
┌──────────────────────────────────────────────────────────┐
│ AWS Amplify (Frontend)                                   │
│ https://hras.owezzy.tech                                 │
│ • Next.js SSR with auto-scaling CDN                      │
│ • www redirect: www.hras.owezzy.tech → hras.owezzy.tech │
└──────────────────────────────────────────────────────────┘
                         │ HTTPS API calls
                         ▼
┌──────────────────────────────────────────────────────────┐
│ Hetzner (Backend + Monitoring)                           │
│ https://hetzner-api.hras.owezzy.tech                     │
│ • Caddy reverse proxy (TLS via Let's Encrypt)           │
│ • FastAPI backend (Docker)                               │
│ • PostgreSQL database                                    │
│ • Ollama local LLM (no API costs)                        │
│ • ChromaDB vector store                                  │
│ • Prometheus + Grafana + Loki (SSH tunnel access)       │
└──────────────────────────────────────────────────────────┘
```

**Note**: Monitoring dashboards are accessed via SSH tunnel for security.

### Deployment Guides

1. **[EC2 Backend Deployment](./docs/deployment/aws/EC2_DEPLOYMENT.md)** - Backend setup with Caddy, Docker, PostgreSQL
2. **[Amplify Frontend Deployment](./docs/deployment/aws/AMPLIFY_DEPLOYMENT.md)** - Next.js frontend with custom domain
3. **[Monitoring Setup](./docs/deployment/aws/MONITORING_SETUP.md)** - Prometheus + Grafana configuration

### CI/CD Pipeline

Automated deployment via GitHub Actions on push to `main` branch:

```
.github/workflows/deploy-production-docker.yml
```

**Pipeline Stages:**
1. **Quality Gates** - Lint, build, and test frontend/backend
2. **Deploy to EC2** - Rsync code, rebuild Docker containers
3. **Health Verification** - API health checks with automatic rollback on failure
4. **Post-Deployment Tests** - Verify chat endpoint and admin stats

**Required GitHub Secrets:**

| Secret | Description |
|--------|-------------|
| `EC2_SSH_KEY` | SSH private key for EC2 access |
| `EC2_HOST` | EC2 instance public IP or hostname |
| `EC2_USER` | SSH user (e.g., `ubuntu`) |
| `DB_PASSWORD` | PostgreSQL database password |
| `DOMAIN` | API domain (e.g., `api.hras.owezzy.tech`) |
| `LETSENCRYPT_EMAIL` | Email for Let's Encrypt SSL certificates |

### Monthly Cost: ~$10-20

- Hetzner VPS: $8-15
- Snapshots/backups: $1-5
- AWS Amplify: Free tier
- LLM inference: $0 (local Ollama)

## Configuration

### Backend Environment Variables

Copy `backend/.env.example` to `backend/.env` and configure:

```env
# Application
APP_ENV=development
DEBUG=true

# Database (SQLite for dev, PostgreSQL for production)
DATABASE_URL=sqlite+aiosqlite:///./hras.db

# Ollama Configuration
OLLAMA_BASE_URL=http://localhost:11434
OLLAMA_MODEL=nemotron-3-nano:30b-cloud
OLLAMA_EMBEDDING_MODEL=nomic-embed-text
OLLAMA_TIMEOUT=180

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

Production variables are set in AWS Amplify Console or `frontend/.env.production`.

## Documentation

| Category | Key Documents |
|----------|---------------|
| **Development** | [Backend README](./backend/README.md) · [Frontend README](./frontend/README.md) · [Dev Guide](./docs/development/DEVELOPMENT.md) |
| **Deployment** | [EC2 Guide](./docs/deployment/aws/EC2_DEPLOYMENT.md) · [Amplify Guide](./docs/deployment/aws/AMPLIFY_DEPLOYMENT.md) · [Monitoring](./docs/deployment/aws/MONITORING_SETUP.md) |
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
├── zarf/                      # Deployment configs
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
