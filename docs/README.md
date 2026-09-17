# HRAS Documentation

Welcome to the **Human Rights Advisory System (HRAS)** documentation. This AI-powered system helps UN human rights officers access and analyze UHRI documents through intelligent conversations.

## Documentation Structure

```
docs/
├── README.md                      # This file - documentation overview
├── 00-INDEX.md                    # Quick navigation hub
│
├── getting-started/               # For new users
│   └── USER_GUIDE.md              # How to use the system
│
├── architecture/                  # System design
│   ├── ARCHITECTURE.md            # Overall system architecture
│   └── AI_ML.md                   # RAG pipeline & AI/ML details
│
├── development/                   # For contributors
│   ├── DEVELOPMENT.md             # Dev environment setup & workflow
│   └── CONFIGURATION.md           # Environment variables & settings
│
├── deployment/                    # Deployment guides
│   ├── DEPLOYMENT.md              # Deployment overview
│   ├── docker/
│   │   └── DOCKER-COMPOSE-EC2-DEPLOYMENT.md
│   ├── kubernetes/
│   │   └── KUBERNETES.md          # Kind & K3s deployment
  │   └── aws/
  │       ├── EC2_DEPLOYMENT.md      # Legacy: backend on EC2
  │       ├── MONITORING_SETUP.md    # Legacy: Prometheus & Grafana
  │       └── AWS_TROUBLESHOOTING.md # Legacy: AWS-specific issues
│
├── operations/                    # For operators
│   ├── TROUBLESHOOTING.md         # Common issues & solutions
│   └── SECURITY_CHECKLIST.md      # Production security
│
└── reference/                     # API & technical reference
    └── API.md                     # REST API documentation
```

## Quick Links by Role

### I'm a User
- [User Guide](getting-started/USER_GUIDE.md) - How to ask questions and use the system

### I'm a Developer
- [Development Setup](development/DEVELOPMENT.md) - Local environment setup
- [Configuration](development/CONFIGURATION.md) - Environment variables
- [Architecture](architecture/ARCHITECTURE.md) - System design overview
- [API Reference](reference/API.md) - REST endpoints

  ### I'm an Operator/DevOps
  - **[Railway Deployment](deployment/RAILWAY.md)** - **Start here** for the current setup
  - [Deployment Overview](deployment/DEPLOYMENT.md) - Legacy deployment options
  - [EC2 Guide](deployment/aws/EC2_DEPLOYMENT.md) - Legacy AWS backend guide
  - [Docker Compose](deployment/docker/DOCKER-COMPOSE-EC2-DEPLOYMENT.md) - Legacy Docker deployment
  - [Kubernetes](deployment/kubernetes/KUBERNETES.md) - Alternative K8s (Kind/K3s)
- [Troubleshooting](operations/TROUBLESHOOTING.md) - Common issues
- [Security Checklist](operations/SECURITY_CHECKLIST.md) - Production hardening

## Technology Stack

| Layer | Technology |
|-------|------------|
| Frontend | Next.js 15, React 19, MUI 7, TailwindCSS 4 |
| Backend | Python 3.12+, FastAPI, LangChain, LangGraph |
| AI/LLM | Ollama + Nemotron 3 Nano (30B cloud model) |
| Embeddings | nomic-embed-text (via Ollama) |
| Vector Store | ChromaDB |
| Database | PostgreSQL 17 (optional, SQLite default) |
| Monitoring | Prometheus, Grafana |

## Quick Start

```bash
# Clone and install
git clone https://github.com/owezzy/HRAS.git
cd HRAS
make install

# Start development
make dev

# Or use Docker Compose (full stack)
docker compose -f zarf/docker/compose/docker-compose.yml --profile full up -d
```

## Production Deployment

**Production runs on Railway and deploys automatically on push to `main`.**

- **Backend**: FastAPI container, ChromaDB on a persistent volume
- **Frontend**: Next.js standalone container
- **AI**: DeepSeek for chat, Cloudflare Workers AI for embeddings
- **Observability**: LangSmith tracing

**See:** [Railway Deployment Guide](deployment/RAILWAY.md)

**Production URLs:**

- Frontend: https://hras.owenadirah.com
- API: https://backend-production-f15e.up.railway.app

## Getting Help

- Check [Troubleshooting](operations/TROUBLESHOOTING.md) for common issues
- Review [AWS Troubleshooting](deployment/aws/AWS_TROUBLESHOOTING.md) for cloud-specific problems
- Open an issue on GitHub for bugs or feature requests
