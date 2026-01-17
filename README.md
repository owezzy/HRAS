# HRAS - Human Rights Advisory System

AI-powered advisory system for UN human rights officers. Uses RAG (Retrieval-Augmented Generation) over UN Human Rights Index (UHRI) documents with multi-agent orchestration powered by LangChain and LangGraph.

## Documentation Map

If you are new to this repo, read in this order:

1. **Root README (this file)** – What HRAS is, how to run it locally, production architecture.
2. **Docs Index** – `./docs/00-INDEX.md` – Navigation hub for all documentation.
3. **Backend** – `./backend/README.md` – Backend API, architecture, and testing.
4. **Frontend** – `./frontend/README.md` – Next.js app, UI structure, and dev workflow.
5. **Deployment** – `./docs/deployment/DEPLOYMENT.md` – All deployment options, with AWS Amplify + EC2 as current production.

---

## Overview

HRAS enables human rights officers to ask natural language questions about UN human rights recommendations and receive AI-generated responses with source citations from UHRI documents.

**Key Features:**
- Conversational AI interface for querying UN human rights data
- RAG pipeline with semantic search across UHRI documents
- Multi-agent system for retrieval, generation, and validation
- Source attribution for every response
- Production-ready deployment on AWS

## Tech Stack

| Component | Technology |
|-----------|------------|
| **Frontend** | Next.js 15, React 19, MUI 7, TailwindCSS 4 |
| **Backend** | Python 3.12+, FastAPI, LangChain, LangGraph |
| **AI/LLM** | Ollama + Nemotron 3 Nano (30B cloud model) |
| **Embeddings** | nomic-embed-text (via Ollama) |
| **Vector Store** | ChromaDB |
| **Database** | PostgreSQL (production) / SQLite (development) |
| **Monitoring** | Prometheus + Grafana |

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
│ AWS EC2 (Backend + Monitoring)                           │
│ https://api.hras.owezzy.tech                             │
│ • Caddy reverse proxy (TLS via Lets Encrypt)            │
│ • FastAPI backend (Docker)                               │
│ • PostgreSQL database                                    │
│ • Ollama local LLM (no API costs)                        │
│ • ChromaDB vector store                                  │
│ • Prometheus + Grafana (SSH tunnel access)              │
└──────────────────────────────────────────────────────────┘
```

### Production URLs

- **Frontend**: https://hras.owezzy.tech
- **API**: https://api.hras.owezzy.tech
- **API Docs**: https://api.hras.owezzy.tech/docs
- **Health**: https://api.hras.owezzy.tech/health

**Note**: Monitoring (Grafana/Prometheus) is accessed via SSH tunnel for security.

### Deployment Guides

1. **[EC2 Backend Deployment](./docs/deployment/aws/EC2_DEPLOYMENT.md)** - Backend setup with Caddy, Docker, PostgreSQL
2. **[Amplify Frontend Deployment](./docs/deployment/aws/AMPLIFY_DEPLOYMENT.md)** - Next.js frontend with custom domain
3. **[Monitoring Setup](./docs/deployment/aws/MONITORING_SETUP.md)** - Prometheus + Grafana configuration

### Monthly Cost: ~$25

- EC2 t3.small: $15.18
- EBS (20GB): $2.00
- Elastic IP: $3.65
- Data transfer: $2-5
- AWS Amplify: Free tier
- LLM inference: $0 (local Ollama)

## Documentation

### For Developers
- **[Backend README](./backend/README.md)** - Backend architecture, API, testing
- **[Frontend README](./frontend/README.md)** - Frontend components, state, styling
- **[Development Guide](./docs/development/DEVELOPMENT.md)** - Local setup, workflows, conventions
- **[Configuration](./docs/development/CONFIGURATION.md)** - Environment variables

### For Operators
- **[Deployment Overview](./docs/deployment/DEPLOYMENT.md)** - All deployment options
- **[AWS EC2 Guide](./docs/deployment/aws/EC2_DEPLOYMENT.md)** - Production backend
- **[AWS Amplify Guide](./docs/deployment/aws/AMPLIFY_DEPLOYMENT.md)** - Production frontend
- **[Monitoring](./docs/deployment/aws/MONITORING_SETUP.md)** - Observability setup
- **[Troubleshooting](./docs/operations/TROUBLESHOOTING.md)** - Common issues

### Architecture & Design
- **[System Architecture](./docs/architecture/ARCHITECTURE.md)** - High-level design, data flow
- **[AI/ML Pipeline](./docs/architecture/AI_ML.md)** - RAG system, agents, prompts

### Reference
- **[API Documentation](./docs/reference/API.md)** - Complete REST API reference
- **[Documentation Index](./docs/00-INDEX.md)** - Quick navigation hub

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
├── frontend/              # Next.js 15 application
│   ├── src/
│   │   ├── app/           # App router pages
│   │   ├── @fuse/         # Fuse React UI components
│   │   └── components/    # HRAS components
│   └── README.md          # Frontend docs
├── backend/               # FastAPI application
│   ├── src/app/           # Main application
│   │   ├── api/           # API routes
│   │   ├── core/          # Config, dependencies
│   │   ├── schemas/       # Pydantic models
│   │   └── services/      # Business logic
│   ├── agents/            # LangGraph multi-agent system
│   ├── chains/            # LangChain LCEL chains
│   ├── vectorstore/       # ChromaDB management
│   ├── prompts/           # Prompt templates
│   ├── tests/             # Pytest suite
│   └── README.md          # Backend docs
├── docs/                  # Documentation
│   ├── 00-INDEX.md        # Quick navigation
│   ├── architecture/      # System design docs
│   ├── deployment/        # Deployment guides
│   ├── development/       # Developer guides
│   ├── operations/        # Operations docs
│   └── reference/         # API reference
├── zarf/                  # Deployment configs
│   ├── docker/            # Dockerfiles
│   ├── k8s/               # Kubernetes manifests
│   └── scripts/           # Deployment scripts
├── Makefile               # Common tasks
└── README.md              # This file
```

## Getting Help

- Check **[Troubleshooting Guide](./docs/operations/TROUBLESHOOTING.md)** for common issues
- Review **[API Documentation](./docs/reference/API.md)** for endpoint details
- See **[Development Guide](./docs/development/DEVELOPMENT.md)** for setup help
- Open a GitHub issue for bugs or feature requests

## License

MIT License - See LICENSE file for details
