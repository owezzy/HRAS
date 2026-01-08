.PHONY: help dev prod build clean install lint test frontend-dev backend-dev frontend-build backend-build ingest ingest-clear db-stats \
	docker-build docker-build-backend docker-build-frontend \
	kind-create kind-delete kind-load kind-deploy kind-status kind-logs kind-clean

# Default target
help:
	@echo "HRAS - Human Rights Advisory System"
	@echo ""
	@echo "Usage: make [target]"
	@echo ""
	@echo "Development:"
	@echo "  dev              Run both frontend and backend in development mode"
	@echo "  frontend-dev     Run frontend only (Next.js with Turbopack)"
	@echo "  backend-dev      Run backend only (FastAPI with hot reload)"
	@echo ""
	@echo "Production:"
	@echo "  prod             Run both frontend and backend in production mode"
	@echo "  frontend-prod    Run frontend in production mode"
	@echo "  backend-prod     Run backend in production mode"
	@echo ""
	@echo "Build:"
	@echo "  build            Build both frontend and backend"
	@echo "  frontend-build   Build frontend for production"
	@echo ""
	@echo "Quality:"
	@echo "  lint             Run linters for both frontend and backend"
	@echo "  frontend-lint    Run ESLint on frontend"
	@echo "  backend-lint     Run ruff on backend"
	@echo "  test             Run tests for both frontend and backend"
	@echo "  backend-test     Run pytest on backend"
	@echo ""
	@echo "Setup:"
	@echo "  install          Install dependencies for both frontend and backend"
	@echo "  frontend-install Install frontend dependencies"
	@echo "  backend-install  Install backend dependencies"
	@echo ""
	@echo "Data:"
	@echo "  ingest           Ingest UHRI data into vector store"
	@echo "  ingest-clear     Clear and re-ingest UHRI data"
	@echo "  db-stats         Show vector store statistics"
	@echo ""
	@echo "Utilities:"
	@echo "  clean            Clean build artifacts"
	@echo "  format           Format code in both frontend and backend"
	@echo ""
	@echo "Docker:"
	@echo "  docker-build          Build all Docker images"
	@echo "  docker-build-backend  Build backend Docker image"
	@echo "  docker-build-frontend Build frontend Docker image"
	@echo ""
	@echo "Kind (Local Kubernetes):"
	@echo "  kind-create       Create Kind cluster with ingress support"
	@echo "  kind-delete       Delete Kind cluster"
	@echo "  kind-load         Load Docker images into Kind cluster"
	@echo "  kind-deploy       Deploy HRAS to Kind cluster"
	@echo "  kind-status       Show status of HRAS pods and services"
	@echo "  kind-logs         Tail logs from HRAS pods"
	@echo "  kind-clean        Remove HRAS resources from cluster"

# =============================================================================
# Development
# =============================================================================

dev:
	@echo "Starting HRAS in development mode..."
	@make -j2 frontend-dev backend-dev

frontend-dev:
	@echo "Starting frontend (Next.js with Turbopack)..."
	cd frontend && npm run dev

backend-dev:
	@echo "Starting backend (FastAPI with hot reload)..."
	cd backend && PYTHONPATH=. uv run uvicorn src.app.main:app --reload --host 0.0.0.0 --port 8000

# =============================================================================
# Production
# =============================================================================

prod:
	@echo "Starting HRAS in production mode..."
	@make -j2 frontend-prod backend-prod

frontend-prod: frontend-build
	@echo "Starting frontend in production mode..."
	cd frontend && npm run start

backend-prod:
	@echo "Starting backend in production mode..."
	cd backend && PYTHONPATH=. uv run uvicorn src.app.main:app --host 0.0.0.0 --port 8000 --workers 4

# =============================================================================
# Build
# =============================================================================

build: frontend-build
	@echo "Build complete."

frontend-build:
	@echo "Building frontend..."
	cd frontend && npm run build

# =============================================================================
# Quality
# =============================================================================

lint: frontend-lint backend-lint
	@echo "Linting complete."

frontend-lint:
	@echo "Linting frontend..."
	cd frontend && npm run lint

backend-lint:
	@echo "Linting backend..."
	cd backend && uv run ruff check src

test: backend-test
	@echo "Tests complete."

backend-test:
	@echo "Running backend tests..."
	cd backend && uv run pytest

# =============================================================================
# Setup
# =============================================================================

install: frontend-install backend-install
	@echo "All dependencies installed."

frontend-install:
	@echo "Installing frontend dependencies..."
	cd frontend && npm install

backend-install:
	@echo "Installing backend dependencies..."
	cd backend && uv sync

# =============================================================================
# Utilities
# =============================================================================

clean:
	@echo "Cleaning build artifacts..."
	rm -rf frontend/.next
	rm -rf frontend/node_modules/.cache
	rm -rf backend/.pytest_cache
	rm -rf backend/.mypy_cache
	rm -rf backend/.ruff_cache
	find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
	@echo "Clean complete."

format: frontend-format backend-format
	@echo "Formatting complete."

frontend-format:
	@echo "Formatting frontend..."
	cd frontend && npm run lint:fix

backend-format:
	@echo "Formatting backend..."
	cd backend && uv run ruff format src
	cd backend && uv run ruff check --fix src

# =============================================================================
# Data Management
# =============================================================================

ingest:
	@echo "Ingesting UHRI data into vector store..."
	curl -X POST http://localhost:8000/api/v1/admin/ingest

ingest-clear:
	@echo "Clearing and re-ingesting UHRI data..."
	curl -X POST "http://localhost:8000/api/v1/admin/ingest?clear_existing=true"

db-stats:
	@echo "Fetching vector store statistics..."
	curl -s http://localhost:8000/api/v1/admin/stats | python3 -m json.tool

# =============================================================================
# Docker
# =============================================================================

DOCKER_REGISTRY ?= localhost
IMAGE_TAG ?= latest

docker-build: docker-build-backend docker-build-frontend
	@echo "All Docker images built."

docker-build-backend:
	@echo "Building backend Docker image..."
	docker build -t $(DOCKER_REGISTRY)/hras-backend:$(IMAGE_TAG) ./backend

docker-build-frontend:
	@echo "Building frontend Docker image..."
	docker build -t $(DOCKER_REGISTRY)/hras-frontend:$(IMAGE_TAG) ./frontend

# =============================================================================
# Kind (Local Kubernetes)
# =============================================================================

KIND_CLUSTER_NAME ?= hras

kind-create:
	@echo "Creating Kind cluster '$(KIND_CLUSTER_NAME)'..."
	@if kind get clusters | grep -q "^$(KIND_CLUSTER_NAME)$$"; then \
		echo "Cluster '$(KIND_CLUSTER_NAME)' already exists."; \
	else \
		kind create cluster --name $(KIND_CLUSTER_NAME) --config=k8s/kind-config.yaml; \
	fi
	@echo "Kind cluster '$(KIND_CLUSTER_NAME)' is ready."

kind-delete:
	@echo "Deleting Kind cluster '$(KIND_CLUSTER_NAME)'..."
	kind delete cluster --name $(KIND_CLUSTER_NAME)

kind-load: docker-build
	@echo "Loading Docker images into Kind cluster..."
	kind load docker-image $(DOCKER_REGISTRY)/hras-backend:$(IMAGE_TAG) --name $(KIND_CLUSTER_NAME)
	kind load docker-image $(DOCKER_REGISTRY)/hras-frontend:$(IMAGE_TAG) --name $(KIND_CLUSTER_NAME)
	@echo "Images loaded into Kind cluster."

kind-deploy:
	@echo "Deploying HRAS to Kind cluster (includes Nginx Ingress Controller)..."
	kubectl apply -k k8s/overlays/kind
	@echo "Waiting for Ingress Controller to be ready..."
	kubectl wait --namespace ingress-nginx \
		--for=condition=ready pod \
		--selector=app.kubernetes.io/component=controller \
		--timeout=180s || true
	@echo "Waiting for HRAS deployments to be ready..."
	kubectl wait --namespace hras \
		--for=condition=available deployment/hras-backend \
		--timeout=120s || true
	kubectl wait --namespace hras \
		--for=condition=available deployment/hras-frontend \
		--timeout=120s || true
	@echo ""
	@echo "HRAS deployed. Access at: http://localhost"
	@echo "API available at: http://localhost/api"
	@echo ""
	@echo "Note: Add '127.0.0.1 hras.example.com' to /etc/hosts if using the ingress hostname."

kind-status:
	@echo "=== HRAS Pods ==="
	kubectl get pods -n hras -o wide
	@echo ""
	@echo "=== HRAS Services ==="
	kubectl get services -n hras
	@echo ""
	@echo "=== HRAS Ingress ==="
	kubectl get ingress -n hras

kind-logs:
	@echo "Tailing logs from HRAS pods (Ctrl+C to stop)..."
	kubectl logs -n hras -l app.kubernetes.io/part-of=hras -f --prefix --max-log-requests=10

kind-logs-backend:
	@echo "Tailing backend logs..."
	kubectl logs -n hras -l app.kubernetes.io/name=hras-backend -f

kind-logs-frontend:
	@echo "Tailing frontend logs..."
	kubectl logs -n hras -l app.kubernetes.io/name=hras-frontend -f

kind-clean:
	@echo "Removing HRAS resources from cluster..."
	kubectl delete -k k8s/overlays/kind --ignore-not-found
