# HRAS - Deployment Guide

## Overview

This guide covers deployment options for the HRAS (Human Rights Advisory System) including local development, Docker, and Kubernetes environments.

## Prerequisites

- Node.js >= 22.12.0
- Python 3.12+
- [uv](https://docs.astral.sh/uv/) (Python package manager)
- [Ollama](https://ollama.com/) installed and running
- Docker (for containerized deployments)
- [kind](https://kind.sigs.k8s.io/) (for Kubernetes testing)

## Local Development Setup

### 1. Manual Setup

```bash
# Clone the repository
git clone <repo-url>
cd HRAS

# Install dependencies
make install

# Configure environment
cp backend/.env.example backend/.env
# Edit .env with your settings
```

### 2. Environment Configuration

### Backend (.env)
```ini
OLLAMA_BASE_URL=http://localhost:11434
OLLAMA_MODEL=nemotron-3-nano:30b-cloud
OLLAMA_EMBEDDING_MODEL=nomic-embed-text
CHROMA_PERSIST_DIRECTORY=./chroma_db
DATABASE_URL=sqlite+aiosqlite:///./hras.db
CORS_ORIGINS=["http://localhost:3000"]
```

### Frontend (.env.local)
```bash
NEXT_PUBLIC_API_URL=http://localhost:8000
AUTH_SECRET=your-auth-secret
```

## Docker Deployment

### 1. Build Images

```bash
# Build all images
make docker-build

# Or build individually
make docker-build-backend   # Backend image
make docker-build-frontend  # Frontend image
```

### 2. Run with Docker Compose

```bash
# Full stack with Redis, PostgreSQL, and Ollama
docker-compose up

# Or run components separately:
docker-compose up frontend
docker-compose up backend
docker-compose up redis
docker-compose up postgres
```

### 3. Docker Images

- **frontend-image:** Next.js application with production build
- **backend-image:** FastAPI application with uvicorn server
- **redis-image:** Redis for caching (optional)
- **postgres-image:** PostgreSQL database (optional, currently using SQLite)

## Kubernetes Deployment (Kind)

### 1. Prerequisites

- Docker running
- kind installed
- kubectl installed
- Ollama running on host machine

### 2. Setup and Deploy

```bash
# Create Kind cluster
make kind-create

# Build and load images into cluster
make kind-load

# Deploy all services (includes automatic data ingestion)
make kind-deploy

# Check deployment status
make kind-status

# View logs
make kind-logs          # All logs
make kind-logs-backend  # Backend logs only
make kind-logs-frontend # Frontend logs only
```

### 3. Project Structure (Ardan Labs Pattern)

```
k8s/
├── base/                 # Base Kustomize manifests
│   ├── backend/          # Backend Deployment/Svc/PVC
│   │   ├── kustomization.yaml
│   │   └── base-backend.yaml
│   └── frontend/         # Frontend Deployment/Svc
│       ├── kustomization.yaml
│       └── base-frontend.yaml
└── dev/                  # Development overlays
    ├── kind-config.yaml  # Kind cluster config
    ├── backend/          # Backend patches
    │   ├── kustomization.yaml
    │   ├── dev-backend-configmap.yaml
    │   ├── dev-backend-patch-deploy.yaml
    │   └── dev-backend-patch-service.yaml
    └── frontend/         # Frontend patches
        ├── kustomization.yaml
        ├── dev-frontend-patch-deploy.yaml
        └── dev-frontend-patch-service.yaml
```

### 4. Key Patterns

- **Base Manifests:** Use placeholder images (`backend-image`, `frontend-image`)
- **Overlays:** Use `images:` transformer to inject actual image names
- **Patches:** Separate files for deploy/service modifications
- **ConfigMaps:** Environment-specific configurations in overlays
- **Network Configuration:** `hostNetwork: true` for direct port access
- **Automatic Ingestion:** Sample data ingested on first deployment

## Environment Variables Reference

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `OLLAMA_BASE_URL` | Ollama server URL | `http://localhost:11434` | Yes |
| `OLLAMA_MODEL` | LLM model for chat | `nemotron-3-nano:30b-cloud` | Yes |
| `OLLAMA_EMBEDDING_MODEL` | Embedding model | `nomic-embed-text` | Yes |
| `CHROMA_PERSIST_DIRECTORY` | Vector store path | `./chroma_db` | Yes |
| `DATABASE_URL` | Database connection | `sqlite+aiosqlite:///./hras.db` | Yes |
| `CORS_ORIGINS` | Allowed origins | `["http://localhost:3000"]` | No |

## Configuration Management

### 1. Environment-Specific Configurations

- **Development:** `.env` files with local settings
- **Staging:** ConfigMaps with pre-configured values
- **Production:** Secure secrets management (Vault, AWS Secrets Manager)

### 2. Configuration Validation

- `.env.example` files for template reference
- Validation scripts to check required variables
- Configuration precedence rules (env vars > command line > defaults)

## Data Ingestion System

### 1. Ingestion Pipeline

1. **Trigger:** Deployment process or manual command
2. **Components:**
   - UHRI Data Sources (API endpoints)
   - Document Processing Pipeline
   - Text Chunking and Embedding
   - Vector Store Indexing (ChromaDB)
3. **Status Tracking:** Progress monitoring and completion notifications

### 2. Ingestion Commands

```bash
# Ingest sample data (fast, good for testing)
make ingest

# Ingest full dataset (slower, for production)
make ingest use_sample=false

# Clear and re-ingest
make ingest-clear
```

## Monitoring and Health Checks

### 1. API Health Checks

```bash
# Basic health check
curl http://localhost:8000/health

# Detailed health check
curl http://localhost:8000/api/v1/admin/stats
```

### 2. Service Status

```bash
# Check all services in Kubernetes
make kind-status

# View running pods
kubectl get pods -A
```

## Security Considerations

### 1. Environment Security

- Do not commit sensitive data to version control
- Use .env.local for local secrets
- Rotate API keys and passwords regularly
- Use secure configuration management for production

### 2. Network Security

- Firewall rules for production deployments
- Network policies in Kubernetes
- SSL/TLS termination for external access
- Rate limiting for public APIs

## Scaling Strategies

### 1. Horizontal Scaling

- Stateless services for easy scaling
- Load balancing across instances
- Connection pooling for databases

### 2. Vertical Scaling

- Resource monitoring and alerts
- Auto-scaling based on metrics
- Performance testing for capacity planning

### 3. Database Scaling

- Connection limits and pooling
- Read replicas for heavy read workloads
- Caching strategies for frequent queries