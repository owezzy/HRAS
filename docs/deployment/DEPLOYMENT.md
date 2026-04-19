# HRAS Deployment Guide

Complete guide for deploying HRAS in local development, Docker, Kubernetes, and AWS production environments.

## Overview

HRAS can be deployed in multiple configurations:

| Environment | Use Case | Complexity | Cost |
|-------------|----------|------------|------|
| **Local Development** | Development and testing | Low | $0 |
| **Docker Compose** | Simple deployments, dev/staging | Low | $0-25/mo |
| **Kind (Kubernetes)** | Local K8s testing | Medium | $0 |
| **AWS Production** | Current production setup | Medium | ~$25/mo |
| **K3s (Kubernetes)** | Alternative production | Medium | ~$25/mo |

## Current Production Architecture

**HRAS is currently deployed with AWS Amplify + Hetzner:**

```
Frontend: AWS Amplify (Next.js 15)
  ↓ HTTPS
Backend: Hetzner + Caddy + Docker
  • Caddy reverse proxy with Let's Encrypt TLS
  • FastAPI backend in Docker
  • PostgreSQL database
  • Ollama local LLM
  • Prometheus + Grafana (SSH tunnel access)
```

**Production URLs:**
- Frontend: https://hras.owezzy.tech
- API: https://hetzner-api.hras.owezzy.tech
- Monitoring: SSH tunnel only (secure)

**See: [Hetzner Production Deployment](#hetzner-production-deployment)**

---

## Local Development Setup

### Prerequisites

- Node.js >= 22.12.0
- Python 3.12+
- [uv](https://docs.astral.sh/uv/) (Python package manager)
- [Ollama](https://ollama.com/) installed and running

### Quick Start

```bash
# Clone repository
git clone https://github.com/owezzy/HRAS.git
cd HRAS

# Install dependencies
make install

# Configure environment
cp backend/.env.example backend/.env

# Set up Ollama
ollama serve                    # Terminal 1
ollama login                    # Required for cloud models
ollama pull nomic-embed-text

# Run development servers
make dev                        # Frontend + backend
# Frontend: http://localhost:3000
# Backend:  http://localhost:8000

# Ingest sample data (first time only)
make ingest
```

### Environment Configuration

**Backend (.env)**
```env
OLLAMA_BASE_URL=http://localhost:11434
OLLAMA_MODEL=nemotron-3-nano:30b-cloud
OLLAMA_EMBEDDING_MODEL=nomic-embed-text
CHROMA_PERSIST_DIRECTORY=./chroma_db
DATABASE_URL=sqlite+aiosqlite:///./hras.db
CORS_ORIGINS=["http://localhost:3000"]
```

**Frontend (.env.local)**
```env
NEXT_PUBLIC_API_URL=http://localhost:8000
```

---

## Docker Compose Deployment

For simple containerized deployments without Kubernetes.

### Quick Start

```bash
# Build backend image
make docker-build-backend

# Start full stack (backend + postgres + monitoring)
docker compose -f zarf/docker/compose/docker-compose.yml --profile full up -d

# Verify services
docker compose -f zarf/docker/compose/docker-compose.yml ps

# Access:
# Backend: http://localhost:8000
# Grafana: http://localhost:3001
# Prometheus: http://localhost:9090
```

### Architecture

```
docker compose
├── backend (FastAPI + Ollama)
├── postgres (database)
├── prometheus (metrics)
└── grafana (dashboards)
```

**See: [Docker Compose EC2 Deployment](./docker/DOCKER-COMPOSE-EC2-DEPLOYMENT.md)** for production setup.

---

## Kind (Kubernetes) Deployment

For local Kubernetes testing and development.

### Prerequisites

- Docker running
- [kind](https://kind.sigs.k8s.io/) installed
- kubectl installed
- Ollama running on host machine

### Quick Start

```bash
# Create Kind cluster
make kind-create

# Build and load backend image
make kind-load

# Deploy backend + postgres (auto-ingests data)
make kind-deploy

# Check status
make kind-status

# Access:
# Backend API: http://localhost:8000
# PostgreSQL:  localhost:30432
```

### Kubernetes Structure

```
zarf/k8s/
├── base/              # Base Kustomize manifests
│   ├── backend/       # Backend Deployment/Service/PVC
│   ├── postgres/      # PostgreSQL StatefulSet
│   ├── monitoring/    # Prometheus/Grafana/Alertmanager
│   └── ingress/       # Nginx Ingress
└── dev/               # Kind overlay
    ├── backend/       # Dev ConfigMap/patches
    ├── postgres/      # Dev patches
    └── monitoring/    # Dev NodePort services
```

**See: [Kubernetes Deployment](./kubernetes/KUBERNETES.md)** for details.

---

## AWS Production Deployment

Legacy production path with Amplify frontend + EC2 backend.

### Architecture Overview

```
┌──────────────────────────────────────────────┐
│ AWS Amplify (Frontend)                       │
│ https://hras.owezzy.tech                     │
│ • Next.js SSR with CDN                       │
│ • Auto-deploy on push to main               │
└──────────────────────────────────────────────┘
                   │ HTTPS API calls
                   ▼
┌──────────────────────────────────────────────┐
│ AWS EC2 (Backend)                            │
│ https://api.hras.owezzy.tech                 │
│ • Caddy reverse proxy (TLS via Let's Encrypt)│
│ • Docker: FastAPI + PostgreSQL + Ollama     │
│ • Prometheus + Grafana (SSH tunnel)         │
└──────────────────────────────────────────────┘
```

### Deployment Steps

1. **[Deploy Backend to EC2](./aws/EC2_DEPLOYMENT.md)**
   - Launch EC2 instance (t3.small)
   - Install Docker and dependencies
   - Deploy backend with Docker Compose
   - Configure Caddy with Let's Encrypt TLS
   - Set up monitoring stack

2. **[Deploy Frontend to Amplify](./aws/AMPLIFY_DEPLOYMENT.md)**
   - Connect GitHub repository
   - Configure build settings
   - Add custom domain (hras.owezzy.tech)
   - Configure CORS with backend

3. **[Configure Monitoring](./aws/MONITORING_SETUP.md)**
   - Access Grafana via SSH tunnel
   - Configure alerting rules
   - Set up backup strategy

### Monthly Cost

| Service | Cost |
|---------|------|
| EC2 t3.small | $15.18 |
| EBS 20GB | $2.00 |
| Elastic IP | $3.65 |
| Data transfer | $2-5 |
| **AWS Amplify** | Free tier |
| **LLM inference** | $0 (local) |
| **Total** | **~$25/mo** |

---

## Hetzner Production Deployment

Hetzner is supported as a monolith API deployment using Docker Compose, Caddy, and the GitHub Actions workflow in `.github/workflows/deploy-hetzner.yml`.

### Architecture Overview

```text
AWS Amplify (Frontend)
  https://hras.owezzy.tech
        ↓ HTTPS API calls
Hetzner (Backend)
  https://hetzner-api.hras.owezzy.tech
  • Caddy reverse proxy (Let's Encrypt TLS)
  • Docker Compose monolith API stack
  • FastAPI backend + PostgreSQL + Ollama
  • Prometheus + Grafana + Loki
```

### Deployment Steps

1. Copy `.env.hetzner.example` to `.env.hetzner`
2. Fill in required secrets and domain values
3. Keep list fields as valid JSON arrays:

```env
CORS_ORIGINS=["https://hras.owezzy.tech"]
TRUSTED_HOSTS=["localhost","127.0.0.1","backend","backend:8000","hetzner-api.hras.example.com"]
```

4. Prepare the server:

```bash
make deploy-hetzner-setup
```

5. Deploy the API stack:

```bash
make deploy-hetzner-production
```

6. Verify the deployment:

```bash
curl https://hetzner-api.hras.owezzy.tech/health
curl https://hetzner-api.hras.owezzy.tech/docs
curl https://hetzner-api.hras.owezzy.tech/redoc
curl https://hetzner-api.hras.owezzy.tech/api/v1/admin/stats
curl -X POST https://hetzner-api.hras.owezzy.tech/api/v1/chat \
  -H 'Content-Type: application/json' \
  -d '{"message":"Hello, test deployment"}'
```

### CI/CD Notes

- `.github/workflows/deploy-hetzner.yml` now generates `.env.hetzner` on the GitHub runner, validates `CORS_ORIGINS` and `TRUSTED_HOSTS` as JSON arrays, and only then copies the file to `/opt/hras/.env.hetzner`.
- `zarf/scripts/deploy-hetzner.sh` performs the same JSON validation before `docker compose` starts the stack.
- Production OpenAPI docs are enabled through `DOCS_ENABLED=true`, so `/docs`, `/redoc`, and `/openapi.json` are available on the live Hetzner API.
- LangSmith production tracing is active when `USE_LANGSMITH_TRACING=true` and `LANGSMITH_API_KEY` is present in the Hetzner environment.
- If those values are malformed, FastAPI startup fails with `pydantic_settings.exceptions.SettingsError` while parsing `cors_origins`.

---
## K3s Production (Alternative)

Lightweight Kubernetes for production (alternative to current Caddy+Docker setup).

### Quick Start

```bash
# SSH to EC2 instance
ssh -i ~/.ssh/your-key.pem ubuntu@your-ec2-ip

# Clone repository
git clone https://github.com/owezzy/HRAS.git
cd HRAS

# Install K3s
./zarf/scripts/k3s-setup.sh

# Deploy HRAS
./zarf/scripts/k3s-deploy.sh

# Check status
kubectl get pods -n hras-system
```

**See: [Kubernetes Deployment](./kubernetes/KUBERNETES.md)** for full K3s guide.

---

## Data Ingestion

HRAS requires UHRI documents to be ingested into the vector store before use.

### Commands

```bash
# Ingest sample data (fast, good for dev/testing)
make ingest

# Ingest full dataset (slower, for production)
curl -X POST "http://localhost:8000/api/v1/admin/ingest?use_sample=false"

# Clear and re-ingest
make ingest-clear

# Verify ingestion
make db-stats
# or
curl http://localhost:8000/api/v1/admin/stats
```

### Automatic Ingestion

- **Kind**: Kubernetes Job runs on deployment
- **Docker Compose**: Run manually after startup
- **Production**: Run manually after deployment

---

## Monitoring

### Prometheus + Grafana Stack

All deployment options include monitoring:

**Components:**
- Prometheus: Metrics collection
- Grafana: Visualization dashboards
- AlertManager: Alert routing (optional)

**Access:**
- **Local/Kind**: http://localhost:9090, http://localhost:3001
- **Production**: SSH tunnel only (secure)

```bash
# SSH tunnel for production monitoring
ssh -i ~/.ssh/your-key.pem -L 3001:localhost:3001 -L 9090:localhost:9090 ubuntu@<ec2-ip>

# Then access:
# Grafana:    http://localhost:3001
# Prometheus: http://localhost:9090
```

**Key Metrics:**
- HTTP request rates and latency
- RAG query performance (P50, P95, P99)
- LLM inference times
- Vector store operations
- Database connection health
- Error rates by component

**See: [Monitoring Setup](./aws/MONITORING_SETUP.md)**

---

## Health Checks

### API Health Endpoints

```bash
# Basic health check
curl http://localhost:8000/health

# Detailed stats (vector store, etc.)
curl http://localhost:8000/api/v1/admin/stats

# Production
curl https://hetzner-api.hras.owezzy.tech/health
```

### Service Status

```bash
# Docker Compose
docker compose ps

# Kubernetes
make kind-status
# or
kubectl get pods -n hras-system

# Production EC2
docker compose -f zarf/docker/compose/docker-compose.yml ps
```

---

## Environment Variables Reference

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `OLLAMA_BASE_URL` | Ollama server URL | `http://localhost:11434` | Yes |
| `OLLAMA_MODEL` | LLM model | `nemotron-3-nano:30b-cloud` | Yes |
| `OLLAMA_EMBEDDING_MODEL` | Embedding model | `nomic-embed-text` | Yes |
| `CHROMA_PERSIST_DIRECTORY` | Vector store path | `./chroma_db` | Yes |
| `DATABASE_URL` | Database connection | `sqlite+aiosqlite:///./hras.db` | Yes |
| `CORS_ORIGINS` | Allowed origins | `["http://localhost:3000"]` | No |
| `USE_POSTGRES` | Enable PostgreSQL | `false` | No |

**See: [Configuration Guide](../development/CONFIGURATION.md)** for complete reference.

---

## Security Considerations

### Development
- Use `.env.local` for local secrets
- Never commit `.env` files
- Use sample data only

### Production
- Rotate API keys regularly
- Use Secrets Manager (AWS) or Vault
- Restrict security group ports (only 22, 80, 443)
- Access monitoring via SSH tunnel only
- Enable HTTPS with Let's Encrypt
- Configure CORS for Amplify domain only
- Run containers as non-root users

**See: [Security Checklist](../operations/SECURITY_CHECKLIST.md)**

---

## Troubleshooting

### Common Issues

**Ollama Connection Failed:**
```bash
# Check Ollama is running
ollama serve

# Verify models are pulled
ollama list

# Test connection
curl http://localhost:11434/api/tags
```

**Vector Store Empty:**
```bash
# Re-ingest data
make ingest-clear

# Verify documents
make db-stats
```

**CORS Errors (Production):**
- Verify `CORS_ORIGINS` includes Amplify domain
- Restart backend after config change

**Monitoring Not Accessible:**
- Use SSH tunnel, don't expose ports publicly
- Check ports 3001/9090 are NOT in security group

**See: [Troubleshooting Guide](../operations/TROUBLESHOOTING.md)**

---

## Scaling Strategies

### Horizontal Scaling
- Load balancer + multiple backend instances
- Managed database (RDS PostgreSQL)
- Redis for caching

### Vertical Scaling
- Larger EC2 instance for Ollama models
- More memory for vector store
- SSD for faster disk I/O

### Cost Optimization
- Use Ollama locally (no API costs)
- AWS Amplify free tier for frontend
- Single EC2 for low-traffic (~$25/mo)

---

## Next Steps

**For Development:**
- Follow [Development Guide](../development/DEVELOPMENT.md)
- Set up local environment
- Run tests with `make test`

**For Production:**
1. [Deploy Backend (EC2)](./aws/EC2_DEPLOYMENT.md)
2. [Deploy Frontend (Amplify)](./aws/AMPLIFY_DEPLOYMENT.md)
3. [Configure Monitoring](./aws/MONITORING_SETUP.md)
4. [Review Security](../operations/SECURITY_CHECKLIST.md)

**For Operators:**
- Review [Troubleshooting](../operations/TROUBLESHOOTING.md)
- Set up monitoring alerts
- Configure automated backups
- Plan scaling strategy
