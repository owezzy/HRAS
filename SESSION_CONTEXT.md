# HRAS Session Context

## Project Overview

**HRAS (Human Rights Advisory System)** - AI-powered advisory system for UN human rights officers.

| Component | Technology |
|-----------|------------|
| Backend | FastAPI, LangChain, LangGraph, Python 3.12+ |
| Frontend | Next.js 15, React 19, MUI 7, TailwindCSS 4 |
| LLM | Ollama + Nemotron 3 Nano (30B cloud) |
| Embeddings | nomic-embed-text (via Ollama) |
| Vector Store | ChromaDB |
| Data Source | UHRI (UN Human Rights Index) |

## Current State

- **Branch**: `develop`
- **Git Flow**: Initialized with `main` and `develop` branches
- **Release**: v0.1.0 (MVP1) tagged

## Completed Work

### 1. Ollama-Only Integration
- Removed OpenAI completely
- Backend uses `ChatOllama` exclusively
- Removed `langchain-openai` dependency

### 2. Kubernetes Setup (Ardan Labs Patterns)

**Directory Structure:**
```
k8s/
├── base/
│   ├── backend/
│   │   ├── kustomization.yaml
│   │   └── base-backend.yaml       # Deployment, Service, PVC
│   └── frontend/
│       ├── kustomization.yaml
│       └── base-frontend.yaml      # Deployment, Service
└── dev/
    ├── kind-config.yaml            # Port mappings (3000, 8000)
    ├── backend/
    │   ├── kustomization.yaml      # images transformer, patches
    │   ├── dev-backend-configmap.yaml
    │   ├── dev-backend-patch-deploy.yaml
    │   └── dev-backend-patch-service.yaml
    └── frontend/
        ├── kustomization.yaml
        ├── dev-frontend-configmap.yaml
        ├── dev-frontend-patch-deploy.yaml
        └── dev-frontend-patch-service.yaml
```

**Key Patterns Applied:**
- Per-service directories in `base/` and `dev/`
- Base uses placeholder images (`backend-image`, `frontend-image`)
- `images:` transformer swaps to actual image names
- Separate patch files for deployment and service modifications
- ConfigMap in overlay (environment-specific)
- `hostNetwork: true` for direct port access (no ingress for dev)

### 3. Makefile Targets

| Command | Description |
|---------|-------------|
| `make kind-create` | Create Kind cluster |
| `make kind-load` | Build and load images |
| `make kind-deploy` | Deploy backend + frontend |
| `make kind-deploy-backend` | Deploy backend only |
| `make kind-deploy-frontend` | Deploy frontend only |
| `make kind-status` | Show pods and services |
| `make kind-logs` | Tail all logs |
| `make kind-clean` | Remove from cluster |

### 4. Documentation
- README.md with full setup guide
- docs/API.md with endpoint documentation
- AGENTS.md with project conventions

## Environment Configuration

| Resource | Value |
|----------|-------|
| Namespace | `hras-system` |
| Backend URL | `http://localhost:8000` |
| Frontend URL | `http://localhost:3000` |
| Ollama URL (Kind) | `http://host.docker.internal:11434` |
| Ollama Model | `nemotron-3-nano:30b-cloud` |
| Embedding Model | `nomic-embed-text` |

## Key Files

| File | Purpose |
|------|---------|
| `/Makefile` | All build/dev/deploy commands |
| `/README.md` | Setup guide with K8s section |
| `/AGENTS.md` | Project conventions for AI agents |
| `/k8s/` | Kubernetes manifests (Ardan Labs pattern) |
| `/backend/` | FastAPI + LangChain/LangGraph |
| `/frontend/` | Next.js 15 + Fuse React |

## Validated

- ✅ `kubectl kustomize k8s/dev/backend` - builds correctly
- ✅ `kubectl kustomize k8s/dev/frontend` - builds correctly
- ✅ `kubectl apply --dry-run=client` - both pass

## Next Steps

1. Test Kind deployment end-to-end
2. Create `k8s/prod/` overlay for production clusters
3. Add observability (Prometheus, Grafana) following Ardan patterns
4. Add ingress for production deployments

## Quick Start

```bash
# Development (local)
make dev

# Kind (local Kubernetes)
make kind-create
make kind-load
make kind-deploy
make kind-status
```
