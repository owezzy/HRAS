# Docker Compose Deployment Guide

This guide explains how to use the new Docker Compose-based deployment workflow for HRAS production.

## Overview

The `deploy-production-docker.yml` workflow provides a simpler alternative to the existing Kubernetes-based deployment. It uses Docker Compose directly on EC2 for easier management and debugging.

## Workflow Features

### ✅ Automated Quality Gates
- Frontend linting and build validation
- Backend linting and test execution
- Code coverage reporting
- Fail-fast on quality issues

### 🚀 Zero-Downtime Deployment
- Graceful service shutdown with 30s timeout
- Docker image rebuilds with no-cache for latest code
- Health checks before marking deployment as successful
- Automatic rollback on failure

### 🔒 Security Best Practices
- SSH key-based authentication
- No hardcoded secrets in workflow
- Secure environment file generation on EC2
- Non-root container execution

### 📊 Comprehensive Monitoring
- Service health verification
- HTTP endpoint testing
- Docker Compose status reporting
- Slack notifications (optional)

## Deployment Process

### 1. Trigger Conditions
- **Automatic**: Push to `main` branch (when PRs are merged)
- **Manual**: Workflow dispatch with optional force deploy

### 2. Quality Gates Phase
```bash
Frontend: npm ci → lint → build
Backend:  uv sync → ruff check → pytest
```

### 3. Deployment Phase
```bash
SSH Setup → Sync Code → Docker Compose Deploy → Health Check
```

### 4. Verification Phase
```bash
API Health Check → Chat Endpoint Test → Admin Stats Test
```

## Services Deployed

The workflow deploys the full HRAS stack using Docker Compose:

| Service | Description | Health Check |
|---------|-------------|--------------|
| **Caddy** | Reverse proxy with TLS | `caddy version` |
| **Backend** | FastAPI application | `GET /health` |
| **PostgreSQL** | Database | `pg_isready` |
| **Ollama** | LLM inference engine | `ollama list` |
| **Prometheus** | Metrics collection | Port 9090 |
| **Grafana** | Monitoring dashboard | Port 3001 |

## Deployment Commands

The workflow executes these key commands on EC2:

```bash
# Stop existing services gracefully
docker compose --profile full down --timeout 30

# Build latest backend image (no cache)
docker compose --profile full build --no-cache backend

# Start all services with dependencies
docker compose --profile full up -d

# Wait for healthy status
timeout 120 bash -c 'until docker compose ps | grep -q "healthy"; do sleep 5; done'
```

## Rollback Strategy

### Automatic Rollback
- Triggers on deployment failure
- Stops current services
- Restores previous Docker Compose configuration
- Restarts with previous version

### Manual Rollback
```bash
# SSH to EC2
ssh ubuntu@18.215.166.248

# Navigate to deployment directory
cd /opt/hras

# Stop current services
docker compose --profile full down

# View available images
docker images | grep hras

# Rollback to previous image tag
docker tag hras-backend:previous hras-backend:latest
docker compose --profile full up -d
```

## Comparison: Docker vs K8s Workflows

| Feature | Docker Compose | Kubernetes (existing) |
|---------|----------------|----------------------|
| **Complexity** | Simple, direct | Complex, multi-stage |
| **Resource Usage** | Lighter | Heavier (K3s overhead) |
| **Debugging** | Easy (`docker logs`) | Complex (kubectl required) |
| **Scaling** | Manual | Automatic |
| **Dependencies** | Docker only | Docker + K3s + kubectl |
| **Monitoring** | Docker Compose health | K8s probes + metrics |

## When to Use Each Workflow

### Use Docker Compose (`deploy-production-docker.yml`) When:
- ✅ Single-server deployment
- ✅ Simpler operations and debugging needed
- ✅ Resource constraints (t3.small instance)
- ✅ Team prefers Docker Compose familiarity

### Use Kubernetes (`deploy-production.yml`) When:
- ✅ Multi-server deployment needed
- ✅ Auto-scaling requirements
- ✅ Complex service mesh requirements
- ✅ Team has K8s expertise

## Configuration Files

The deployment uses these key configuration files:

```bash
/opt/hras/
├── .env.prod                           # Generated during deployment
├── zarf/docker/compose/
│   └── docker-compose.yml              # Main compose file
├── zarf/docker/caddy/
│   └── Caddyfile                       # Reverse proxy config
└── zarf/monitoring/
    ├── prometheus.yml                  # Metrics config
    └── grafana/                        # Dashboard configs
```

## Environment Variables

The workflow generates this `.env.prod` file on EC2:

```bash
DATABASE_URL=postgresql+asyncpg://hras:${DB_PASSWORD}@postgres:5432/hras
OLLAMA_BASE_URL=http://ollama:11434
OLLAMA_MODEL=nemotron-3-nano:30b-cloud
OLLAMA_EMBEDDING_MODEL=nomic-embed-text
CHROMA_PERSIST_DIRECTORY=/app/chroma_db
POSTGRES_USER=hras
POSTGRES_PASSWORD=${DB_PASSWORD}
POSTGRES_DB=hras
DOMAIN=${DOMAIN}
LETSENCRYPT_EMAIL=${LETSENCRYPT_EMAIL}
```

## Monitoring Access

After deployment, monitoring is available via SSH tunnel:

```bash
# Grafana dashboard
ssh -L 3001:localhost:3001 ubuntu@18.215.166.248
# Access: http://localhost:3001

# Prometheus metrics
ssh -L 9090:localhost:9090 ubuntu@18.215.166.248
# Access: http://localhost:9090
```

## Troubleshooting

### Deployment Failures

1. **Check GitHub Actions logs**
   - Go to repository → Actions → Failed workflow
   - Review each step output for errors

2. **Check service status on EC2**
   ```bash
   ssh ubuntu@18.215.166.248
   cd /opt/hras
   docker compose --profile full ps
   docker compose --profile full logs
   ```

3. **Check individual service logs**
   ```bash
   docker logs hras-backend
   docker logs hras-caddy
   docker logs hras-postgres
   ```

### Common Issues

| Issue | Solution |
|-------|----------|
| SSH connection failure | Check `EC2_SSH_KEY` secret and EC2 security groups |
| Docker build failure | Check Dockerfile and build context |
| Database connection failure | Verify `DB_PASSWORD` secret and PostgreSQL health |
| SSL certificate issues | Check `DOMAIN` and `LETSENCRYPT_EMAIL` secrets |
| Health check timeout | Increase timeout or check service startup time |

### Emergency Procedures

**Stop all services:**
```bash
ssh ubuntu@18.215.166.248
cd /opt/hras
docker compose --profile full down
```

**View resource usage:**
```bash
docker stats
df -h
free -h
```

**Clean up Docker resources:**
```bash
docker system prune -a
docker volume prune
```
