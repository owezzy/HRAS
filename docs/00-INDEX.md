# HRAS Documentation Hub

Welcome to the **Human Rights Advisory System (HRAS)** documentation. This AI-powered advisory system helps UN human rights officers access and analyze UHRI documents through intelligent conversational interfaces.

> **Version:** 0.2.0 | **Last Updated:** January 2026

---

## Quick Navigation

### Getting Started
| Document | Description |
|----------|-------------|
| [User Guide](getting-started/USER_GUIDE.md) | How to ask questions and use the system |

### Architecture & Design
| Document | Description |
|----------|-------------|
| [Architecture](architecture/ARCHITECTURE.md) | System design, data flow, multi-agent setup |
| [AI/ML Pipeline](architecture/AI_ML.md) | RAG system, embeddings, prompt engineering |

### Development
| Document | Description |
|----------|-------------|
| [Development Guide](development/DEVELOPMENT.md) | Setup, coding standards, workflows |
| [Configuration](development/CONFIGURATION.md) | Environment variables, settings |

### Deployment
| Document | Description |
|----------|-------------|
| [Deployment Overview](deployment/DEPLOYMENT.md) | All deployment options summary |
| [Docker Compose](deployment/docker/DOCKER-COMPOSE-EC2-DEPLOYMENT.md) | Production Docker deployment |
| [Kubernetes](deployment/kubernetes/KUBERNETES.md) | Kind & K3s deployment |
| [AWS EC2](deployment/aws/EC2_DEPLOYMENT.md) | Backend on EC2 |
| [AWS Amplify](deployment/aws/AMPLIFY_DEPLOYMENT.md) | Frontend on Amplify |
| [Monitoring](deployment/aws/MONITORING_SETUP.md) | Prometheus & Grafana setup |

### Operations
| Document | Description |
|----------|-------------|
| [Troubleshooting](operations/TROUBLESHOOTING.md) | Common issues, debugging, recovery |
| [AWS Troubleshooting](deployment/aws/AWS_TROUBLESHOOTING.md) | AWS-specific issues |
| [Security Checklist](operations/SECURITY_CHECKLIST.md) | Production security hardening |

### Reference
| Document | Description |
|----------|-------------|
| [API Reference](reference/API.md) | REST endpoints, examples, testing |

---

## Start Here Based on Your Role

### I want to run HRAS locally
1. Check [Prerequisites](deployment/DEPLOYMENT.md#prerequisites)
2. Follow [Development Setup](development/DEVELOPMENT.md)
3. Run `make dev` and visit http://localhost:3000

### I want to deploy HRAS in production
1. Review [Deployment Overview](deployment/DEPLOYMENT.md)
2. Follow [EC2 Deployment](deployment/aws/EC2_DEPLOYMENT.md) for backend
3. Follow [Amplify Deployment](deployment/aws/AMPLIFY_DEPLOYMENT.md) for frontend
4. Set up [Monitoring](deployment/aws/MONITORING_SETUP.md)

### I want to contribute code
1. Read [Development Setup](development/DEVELOPMENT.md)
2. Study [Architecture](architecture/ARCHITECTURE.md)
3. Follow commit conventions in [Development Guide](development/DEVELOPMENT.md#commit-conventions)

### I want to use HRAS to answer questions
1. Start with [User Guide](getting-started/USER_GUIDE.md)

---

## Technology Stack

| Layer | Technology | Version |
|-------|------------|---------|
| Frontend | Next.js + React + MUI + TailwindCSS | 15 / 19 / 7 / 4 |
| Backend | Python + FastAPI + LangChain | 3.12+ / 0.115+ / 0.3+ |
| AI/LLM | Ollama + Nemotron 3 Nano | Latest |
| Embeddings | nomic-embed-text (via Ollama) | Latest |
| Vector Store | ChromaDB | 0.5+ |
| Orchestration | LangGraph (Multi-agent) | 0.2+ |
| Database | PostgreSQL (optional) | 17 |
| Monitoring | Prometheus + Grafana | Latest |

---

## Key Features

- **Intelligent Document Search**: Semantic search across UN human rights documents
- **Conversational AI**: Natural language Q&A with source citations
- **Multi-Agent System**: Specialized agents for retrieval, generation, and validation
- **Source Attribution**: Every answer includes document references
- **Fast Deployment**: Docker Compose with automatic data ingestion
- **Full Observability**: Prometheus metrics + Grafana dashboards

---

## Need Help?

- **Found a bug?** Check [Troubleshooting](operations/TROUBLESHOOTING.md)
- **AWS issues?** See [AWS Troubleshooting](deployment/aws/AWS_TROUBLESHOOTING.md)
- **Feature request?** Open a GitHub issue
