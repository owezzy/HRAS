.PHONY: help dev prod build clean clean-cache install lint test frontend-dev backend-dev frontend-build backend-build ingest ingest-clear db-stats \
	db-up db-down db-migrate db-upgrade db-downgrade db-revision db-history \
	docker-build docker-build-backend docker-build-fast docker-build-backend-fast \
	kind-create kind-delete kind-load kind-load-fast kind-deploy kind-dev-up kind-deploy-backend kind-deploy-postgres kind-status kind-logs kind-logs-backend kind-clean \
	k3s-setup k3s-deploy k3s-status k3s-logs k3s-teardown \
	monitoring-deploy monitoring-undeploy monitoring-status monitoring-logs monitoring-port-forward monitoring-grafana monitoring-prometheus \
	deploy-setup deploy-ssl deploy-production deploy-rollback deploy-backup deploy-health-check deploy-monitoring deploy-status deploy-logs

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
	@echo "Database:"
	@echo "  db-up            Start PostgreSQL container"
	@echo "  db-down          Stop PostgreSQL container"
	@echo "  db-migrate       Create new Alembic migration"
	@echo "  db-upgrade       Run migrations to head"
	@echo "  db-downgrade     Rollback last migration"
	@echo "  db-history       Show migration history"
	@echo ""
	@echo "Utilities:"
	@echo "  clean            Clean build artifacts"
	@echo "  clean-cache      Clean all caches (Docker, npm, uv, build artifacts)"
	@echo "  format           Format code in both frontend and backend"
	@echo ""
	@echo "Docker:"
	@echo "  docker-build          Build backend Docker image"
	@echo "  docker-build-backend  Build backend Docker image"
	@echo "  docker-build-fast     Build backend image with optimizations (faster builds)"
	@echo ""
	@echo "Kind (Local Kubernetes - Development):"
	@echo "  kind-create          Create Kind cluster with local-path-provisioner wait"
	@echo "  kind-delete          Delete Kind cluster"
	@echo "  kind-load            Build and load backend image using ctr import"
	@echo "  kind-load-fast       Build optimized backend image and load using ctr import"
	@echo "  kind-deploy          Deploy postgres and backend (includes auto-ingestion)"
	@echo "  kind-dev-up          Complete setup: cluster, images, app, and monitoring"
	@echo "  kind-deploy-postgres Deploy PostgreSQL database"
	@echo "  kind-deploy-backend  Deploy backend only"
	@echo "  kind-status          Show pods, services, and monitoring status"
	@echo "  kind-logs            Tail all logs"
	@echo "  kind-logs-backend    Tail backend logs"
	@echo "  kind-clean           Remove HRAS, monitoring, and delete Kind cluster"
	@echo ""
	@echo "K3s (Production - EC2):"
	@echo "  k3s-setup            Install K3s on EC2 instance"
	@echo "  k3s-deploy           Deploy HRAS to K3s cluster"
	@echo "  k3s-status           Show K3s cluster and pod status"
	@echo "  k3s-logs             Tail HRAS logs in K3s"
	@echo "  k3s-teardown         Remove K3s and all resources from EC2"
	@echo ""
	@echo "Monitoring:"
	@echo "  monitoring-deploy    Deploy Prometheus, Grafana, Alertmanager stack"
	@echo "  monitoring-delete    Remove monitoring stack from cluster"
	@echo "  monitoring-status    Show monitoring pods and services"
	@echo "  monitoring-logs      Tail monitoring component logs"
	@echo "  monitoring-grafana   Port-forward to Grafana (http://localhost:30031)"
	@echo "  monitoring-prometheus Port-forward to Prometheus (http://localhost:9090)"
	@echo ""
	@echo "AWS EC2 Production Deployment:"
	@echo "  deploy-aws-setup     Set up AWS infrastructure (EC2, Security Groups, S3)"
	@echo "  deploy-setup         Set up EC2 instance for production deployment"
	@echo "  deploy-ssl           Configure SSL certificates with Let's Encrypt"
	@echo "  deploy-production    Deploy application to production (with backup)"
	@echo "  deploy-rollback      Rollback to previous deployment"
	@echo "  deploy-backup        Create manual backup"
	@echo "  deploy-health-check  Run comprehensive health check"
	@echo "  deploy-monitoring    Set up production monitoring stack"
	@echo "  deploy-status        Show production deployment status"
	@echo "  deploy-logs          View production application logs"

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
	cd backend && uv sync --all-groups

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

clean-cache:
	@echo "Cleaning all caches (Docker, npm, uv, build artifacts)..."
	@make clean
	@echo "Cleaning Docker build cache..."
	docker builder prune -f 2>/dev/null || true
	@echo "Cleaning npm cache..."
	cd frontend && npm cache clean --force 2>/dev/null || true
	@echo "Cleaning uv cache..."
	cd backend && uv cache clean 2>/dev/null || true
	@echo "Cache cleanup complete."

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
# Database Management
# =============================================================================

db-up:
	@echo "Starting PostgreSQL..."
	docker compose -f zarf/docker/compose/docker-compose.yml up -d postgres
	@echo "PostgreSQL is running on localhost:5433"

db-down:
	@echo "Stopping PostgreSQL..."
	docker compose -f zarf/docker/compose/docker-compose.yml down postgres

db-migrate:
	@echo "Creating new migration..."
	@read -p "Migration message: " msg; \
	cd backend && uv run alembic revision --autogenerate -m "$$msg"

db-upgrade:
	@echo "Running migrations..."
	cd backend && uv run alembic upgrade head

db-downgrade:
	@echo "Rolling back last migration..."
	cd backend && uv run alembic downgrade -1

db-history:
	@echo "Migration history:"
	cd backend && uv run alembic history

# =============================================================================
# Variables
# =============================================================================

# Docker & Registry
DOCKER_REGISTRY ?= localhost
IMAGE_TAG ?= latest

# Kind Cluster
KIND_CLUSTER_NAME ?= hras
KIND_IMAGE ?= kindest/node:v1.29.0

# Application Images (frontend deployed via AWS Amplify)
HRAS_BACKEND_IMAGE = $(DOCKER_REGISTRY)/hras-backend:$(IMAGE_TAG)

# =============================================================================
# Docker
# =============================================================================

docker-build: docker-build-backend
	@echo "Docker images built."

docker-build-fast: docker-build-backend-fast
	@echo "Docker images built with optimizations."

docker-build-backend:
	@echo "Building backend Docker image..."
	docker build -f zarf/docker/dockerfile.backend -t $(HRAS_BACKEND_IMAGE) .

docker-build-backend-fast:
	@echo "Building backend Docker image with optimizations..."
	DOCKER_BUILDKIT=1 docker build \
		--build-arg BUILDKIT_INLINE_CACHE=1 \
		--cache-from $(HRAS_BACKEND_IMAGE) \
		-f zarf/docker/dockerfile.backend \
		-t $(HRAS_BACKEND_IMAGE) \
		.

# =============================================================================
# Kind (Local Kubernetes - Development)
# =============================================================================

kind-create:
	@echo "Creating Kind cluster '$(KIND_CLUSTER_NAME)'..."
	@if kind get clusters | grep -q "^$(KIND_CLUSTER_NAME)$$"; then \
		echo "Cluster '$(KIND_CLUSTER_NAME)' already exists."; \
	else \
		kind create cluster \
			--image $(KIND_IMAGE) \
			--name $(KIND_CLUSTER_NAME) \
			--config zarf/k8s/dev/kind-config.yaml; \
	fi
	@echo "Waiting for local-path-provisioner to be ready..."
	kubectl wait --timeout=120s --namespace=local-path-storage \
		--for=condition=Available deployment/local-path-provisioner
	@echo "Kind cluster '$(KIND_CLUSTER_NAME)' is ready."

kind-delete:
	@echo "Deleting Kind cluster '$(KIND_CLUSTER_NAME)'..."
	kind delete cluster --name $(KIND_CLUSTER_NAME)

kind-load: docker-build
	@echo "Loading Docker images into Kind cluster using ctr import..."
	docker save $(HRAS_BACKEND_IMAGE) | docker exec -i $(KIND_CLUSTER_NAME)-control-plane ctr --namespace=k8s.io images import -
	@echo "Images loaded into Kind cluster."

kind-load-fast: docker-build-fast
	@echo "Loading optimized Docker images into Kind cluster using ctr import..."
	docker save $(HRAS_BACKEND_IMAGE) | docker exec -i $(KIND_CLUSTER_NAME)-control-plane ctr --namespace=k8s.io images import -
	@echo "Optimized images loaded into Kind cluster."

kind-dev-up:
	@echo "🚀 Setting up HRAS development environment..."
	@make kind-create
	@make kind-load-fast
	@make kind-deploy
	@make monitoring-deploy
	@echo ""
	@echo "🎉 HRAS Development Environment Ready!"
	@echo ""
	@echo "Application:"
	@echo "  Backend API: http://localhost:8000"
	@echo "  Health:      http://localhost:8000/health"
	@echo ""
	@echo "Note: Frontend is deployed separately on AWS Amplify."
	@echo ""
	@echo "Monitoring (via NodePort):"
	@echo "  Grafana:      http://localhost:30031 (admin/CHANGE_ME_IN_PRODUCTION)"
	@echo "  Prometheus:   http://localhost:30090"
	@echo "  Alertmanager: http://localhost:30093"
	@echo ""
	@echo "📊 Check status: make kind-status"
	@echo "📝 View logs:    make kind-logs"
	@echo "🧹 Clean up:     make kind-clean"

kind-deploy-namespace:
	@echo "Creating namespace..."
	kubectl apply -f zarf/k8s/dev/namespace.yaml

kind-deploy-backend: kind-deploy-namespace
	@echo "Deploying backend to Kind cluster..."
	kubectl apply -k zarf/k8s/dev/backend
	@echo "Waiting for backend deployment..."
	kubectl wait --namespace hras-system \
		--for=condition=available deployment/backend \
		--timeout=120s || true

kind-deploy-postgres: kind-deploy-namespace
	@echo "Deploying PostgreSQL to Kind cluster..."
	kubectl apply -k zarf/k8s/dev/postgres
	@echo "Waiting for PostgreSQL to be ready..."
	kubectl wait --namespace hras-system \
		--for=condition=ready pod \
		-l app=postgres \
		--timeout=120s || true
	@echo "PostgreSQL deployed and ready."

kind-deploy: kind-deploy-namespace kind-deploy-postgres kind-deploy-backend
	@echo ""
	@echo "HRAS deployed to Kind cluster '$(KIND_CLUSTER_NAME)'."
	@echo "Backend API: http://localhost:8000"
	@echo "PostgreSQL:  localhost:30432"
	@echo ""
	@echo "Note: Frontend is deployed separately on AWS Amplify."
	@echo "Note: Data ingestion job runs automatically on first deployment."
	@echo "Check ingestion status: kubectl get jobs -n hras-system"

kind-status:
	@echo "=== HRAS Pods ==="
	kubectl get pods -n hras-system -o wide
	@echo ""
	@echo "=== HRAS Services ==="
	kubectl get services -n hras-system
	@echo ""
	@echo "=== Ingestion Jobs ==="
	kubectl get jobs -n hras-system
	@echo ""
	@echo "=== Monitoring Pods ==="
	kubectl get pods -n monitoring -o wide 2>/dev/null || echo "(monitoring namespace not found)"
	@echo ""
	@echo "=== Monitoring Services ==="
	kubectl get services -n monitoring 2>/dev/null || echo "(monitoring namespace not found)"

kind-logs:
	@echo "Tailing logs from HRAS pods (Ctrl+C to stop)..."
	kubectl logs -n hras-system -l app=backend -f --prefix --max-log-requests=10

kind-logs-backend:
	@echo "Tailing backend logs..."
	kubectl logs -n hras-system -l app=backend -f

kind-clean:
	@echo "Removing HRAS resources, monitoring, and deleting Kind cluster..."
	kubectl delete -k zarf/k8s/dev/monitoring --ignore-not-found || true
	kubectl delete -k zarf/k8s/dev/backend --ignore-not-found || true
	kubectl delete -k zarf/k8s/dev/postgres --ignore-not-found || true
	kind delete cluster --name $(KIND_CLUSTER_NAME)
	@echo "Kind cluster '$(KIND_CLUSTER_NAME)' deleted."

# =============================================================================
# K3s (Production - EC2)
# =============================================================================

k3s-setup:
	@echo "Setting up K3s on EC2 instance..."
	@if [ ! -f "zarf/scripts/k3s-setup.sh" ]; then \
		echo "Error: zarf/scripts/k3s-setup.sh not found."; \
		exit 1; \
	fi
	chmod +x zarf/scripts/k3s-setup.sh
	./zarf/scripts/k3s-setup.sh

k3s-deploy:
	@echo "Deploying HRAS to K3s cluster..."
	@if [ ! -f "zarf/scripts/k3s-deploy.sh" ]; then \
		echo "Error: zarf/scripts/k3s-deploy.sh not found."; \
		exit 1; \
	fi
	chmod +x zarf/scripts/k3s-deploy.sh
	./zarf/scripts/k3s-deploy.sh

k3s-status:
	@echo "=== K3s Cluster Status ==="
	kubectl get nodes -o wide
	@echo ""
	@echo "=== HRAS Pods ==="
	kubectl get pods -n hras-system -o wide
	@echo ""
	@echo "=== HRAS Services ==="
	kubectl get services -n hras-system
	@echo ""
	@echo "=== Ingress ==="
	kubectl get ingress -n hras-system
	@echo ""
	@echo "=== Ingestion Jobs ==="
	kubectl get jobs -n hras-system

k3s-logs:
	@echo "Tailing HRAS logs in K3s (Ctrl+C to stop)..."
	kubectl logs -n hras-system -l app=backend -f --prefix --max-log-requests=10

k3s-teardown:
	@echo "Tearing down K3s and all resources..."
	@if [ ! -f "zarf/scripts/k3s-teardown.sh" ]; then \
		echo "Error: zarf/scripts/k3s-teardown.sh not found."; \
		exit 1; \
	fi
	chmod +x zarf/scripts/k3s-teardown.sh
	./zarf/scripts/k3s-teardown.sh

# =============================================================================
# Monitoring
# =============================================================================

monitoring-deploy:
	@echo "Deploying monitoring stack (Prometheus, Grafana, Alertmanager)..."
	kubectl apply -k zarf/k8s/dev/monitoring
	@echo "Waiting for monitoring components to be ready..."
	kubectl wait --namespace monitoring \
		--for=condition=Available deployment/prometheus \
		--timeout=120s || true
	kubectl wait --namespace monitoring \
		--for=condition=Available deployment/grafana \
		--timeout=120s || true
	kubectl wait --namespace monitoring \
		--for=condition=Available deployment/alertmanager \
		--timeout=120s || true
	@echo "✅ Monitoring stack deployed successfully!"
	@echo "Grafana: http://localhost:30031 (admin/CHANGE_ME_IN_PRODUCTION)"
	@echo "Prometheus: http://localhost:30090"
	@echo "Alertmanager: http://localhost:30093"

monitoring-delete:
	@echo "Removing monitoring stack from cluster..."
	kubectl delete -k zarf/k8s/dev/monitoring --ignore-not-found || true
	@echo "Monitoring stack removed."

monitoring-status:
	@echo "=== Monitoring Pods ==="
	kubectl get pods -n monitoring -o wide
	@echo ""
	@echo "=== Monitoring Services ==="
	kubectl get services -n monitoring

monitoring-logs:
	@echo "Viewing monitoring component logs (Ctrl+C to stop)..."
	kubectl logs -n monitoring -l app.kubernetes.io/name=prometheus -f --prefix &
	kubectl logs -n monitoring -l app.kubernetes.io/name=grafana -f --prefix &
	kubectl logs -n monitoring -l app.kubernetes.io/name=alertmanager -f --prefix

monitoring-port-forward:
	@echo "Forwarding monitoring ports..."
	@echo "Grafana:   http://localhost:30031"
	@echo "Prometheus: http://localhost:30090"
	@echo "Press Ctrl+C to stop port forwarding"
	kubectl port-forward -n monitoring svc/grafana 30031:3000 &
	kubectl port-forward -n monitoring svc/prometheus 30090:9090

monitoring-grafana:
	@echo "Accessing Grafana dashboard..."
	@echo "Grafana will be available at http://localhost:30031"
	@echo "Username: admin"
	@echo "Password: CHANGE_ME_IN_PRODUCTION"
	@echo "Press Ctrl+C to stop"
	kubectl port-forward -n monitoring svc/grafana 30031:3000

monitoring-prometheus:
	@echo "Accessing Prometheus UI..."
	@echo "Prometheus will be available at http://localhost:9090"
	@echo "Press Ctrl+C to stop"
	kubectl port-forward -n monitoring svc/prometheus 9090:9090

# =============================================================================
# AWS EC2 Production Deployment
# =============================================================================

# Deployment Configuration
DEPLOY_SCRIPTS_DIR = zarf/scripts
DEPLOY_CONFIG_DIR = zarf/docker/config

deploy-setup:
	@echo "Setting up EC2 instance for HRAS production deployment..."
	@if [ ! -f "$(DEPLOY_CONFIG_DIR)/deployment.env" ]; then \
		echo "Error: deployment.env not found. Please copy deployment.env.example to deployment.env and configure it."; \
		exit 1; \
	fi
	chmod +x $(DEPLOY_SCRIPTS_DIR)/*.sh
	$(DEPLOY_SCRIPTS_DIR)/setup-server.sh

deploy-aws-setup:
	@echo "Setting up AWS infrastructure for HRAS..."
	@if [ ! -f "$(DEPLOY_CONFIG_DIR)/deployment.env" ]; then \
		echo "Error: deployment.env not found. Please copy deployment.env.example to deployment.env and configure it."; \
		exit 1; \
	fi
	chmod +x $(DEPLOY_SCRIPTS_DIR)/*.sh
	$(DEPLOY_SCRIPTS_DIR)/setup-aws.sh

deploy-ssl:
	@echo "Configuring SSL certificates..."
	@if [ ! -f "$(DEPLOY_CONFIG_DIR)/deployment.env" ]; then \
		echo "Error: deployment.env not found. Please run 'make deploy-setup' first."; \
		exit 1; \
	fi
	$(DEPLOY_SCRIPTS_DIR)/setup-ssl.sh

deploy-production:
	@echo "Deploying HRAS to production..."
	@if [ ! -f "$(DEPLOY_CONFIG_DIR)/deployment.env" ]; then \
		echo "Error: deployment.env not found. Please run 'make deploy-setup' first."; \
		exit 1; \
	fi
	$(DEPLOY_SCRIPTS_DIR)/deploy.sh

deploy-rollback:
	@echo "Rolling back HRAS deployment..."
	@read -p "Enter backup ID to rollback to (or press Enter for latest): " backup_id; \
	$(DEPLOY_SCRIPTS_DIR)/rollback.sh $$backup_id

deploy-backup:
	@echo "Creating HRAS backup..."
	$(DEPLOY_SCRIPTS_DIR)/backup.sh

deploy-health-check:
	@echo "Running HRAS health check..."
	$(DEPLOY_SCRIPTS_DIR)/health-check.sh

deploy-monitoring:
	@echo "Setting up production monitoring..."
	$(DEPLOY_SCRIPTS_DIR)/setup-monitoring.sh

deploy-status:
	@echo "Checking HRAS production status..."
	@echo "=== System Services ==="
	@systemctl status hras.service nginx.service docker.service --no-pager || true
	@echo ""
	@echo "=== Docker Containers ==="
	@cd /opt/hras/app && docker compose -f zarf/docker/compose/docker-compose.prod.yml ps || true
	@echo ""
	@echo "=== Resource Usage ==="
	@echo "CPU Usage: $$(top -bn1 | grep "Cpu(s)" | awk '{print $$2}' | sed 's/%us,//')%"
	@echo "Memory Usage: $$(free | grep Mem | awk '{printf "%.1f", ($$3/$$2) * 100.0}')%"
	@echo "Disk Usage: $$(df /opt/hras | awk 'NR==2 {print $$5}')"
	@echo ""
	@echo "=== SSL Certificate ==="
	@if [ -f "/opt/hras/ssl/fullchain.pem" ]; then \
		openssl x509 -in /opt/hras/ssl/fullchain.pem -noout -dates; \
	else \
		echo "SSL certificate not found"; \
	fi

deploy-logs:
	@echo "Viewing HRAS production logs..."
	@echo "Press Ctrl+C to stop..."
	@tail -f /opt/hras/logs/app/*.log

# Deployment helpers
deploy-ssh:
	@if [ -z "$(EC2_HOST)" ]; then \
		echo "Error: EC2_HOST not set in deployment.env"; \
		exit 1; \
	fi
	@ssh -i $(EC2_SSH_KEY_PATH) $(EC2_USER)@$(EC2_HOST)

deploy-sync-scripts:
	@echo "Syncing deployment scripts to server..."
	@if [ -z "$(EC2_HOST)" ]; then \
		echo "Error: EC2_HOST not set in deployment.env"; \
		exit 1; \
	fi
	@rsync -avz -e "ssh -i $(EC2_SSH_KEY_PATH)" \
		$(DEPLOY_SCRIPTS_DIR)/ $(DEPLOY_CONFIG_DIR)/ \
		$(EC2_USER)@$(EC2_HOST):/tmp/hras-deploy/
	@ssh -i $(EC2_SSH_KEY_PATH) $(EC2_USER)@$(EC2_HOST) \
		"sudo mkdir -p /opt/hras/zarf && sudo cp -r /tmp/hras-deploy/* /opt/hras/zarf/ && sudo chmod +x /opt/hras/zarf/scripts/*.sh"

deploy-remote-setup:
	@echo "Running remote server setup..."
	@make deploy-sync-scripts
	@ssh -i $(EC2_SSH_KEY_PATH) $(EC2_USER)@$(EC2_HOST) \
		"cd /opt/hras/zarf && sudo ./scripts/setup-server.sh"

deploy-remote-deploy:
	@echo "Running remote deployment..."
	@make deploy-sync-scripts
	@ssh -i $(EC2_SSH_KEY_PATH) $(EC2_USER)@$(EC2_HOST) \
		"cd /opt/hras/zarf && sudo ./scripts/deploy.sh"

deploy-remote-health:
	@echo "Running remote health check..."
	@ssh -i $(EC2_SSH_KEY_PATH) $(EC2_USER)@$(EC2_HOST) \
		"cd /opt/hras/zarf && ./scripts/health-check.sh"

# =============================================================================
# Production Docker Compose Deployment
# =============================================================================

prod-deploy:
	@echo "Deploying HRAS backend to production with Docker Compose..."
	@if [ ! -f ".env.prod" ]; then \
		echo "Error: .env.prod not found. Please copy .env.prod.example and configure it."; \
		exit 1; \
	fi
	./zarf/scripts/deploy.sh deploy-backend

prod-deploy-full:
	@echo "Deploying full HRAS stack to production..."
	@if [ ! -f ".env.prod" ]; then \
		echo "Error: .env.prod not found. Please copy .env.prod.example and configure it."; \
		exit 1; \
	fi
	./zarf/scripts/deploy.sh deploy --postgres --monitoring --ssl-init

prod-ssl-init:
	@echo "Initializing SSL certificates..."
	./zarf/scripts/setup-ssl.sh

prod-status:
	@echo "Production deployment status:"
	@docker compose -f zarf/docker/compose/docker-compose.prod.yml ps
	@echo ""
	@echo "Health check:"
	@./zarf/scripts/health-check.sh --verbose

prod-logs:
	@echo "Following production logs (Ctrl+C to stop)..."
	@docker compose -f zarf/docker/compose/docker-compose.prod.yml logs -f

prod-health:
	@echo "Running production health checks..."
	@./zarf/scripts/health-check.sh --verbose

prod-stop:
	@echo "Stopping production services..."
	@docker compose -f zarf/docker/compose/docker-compose.prod.yml down

prod-clean:
	@echo "Cleaning production deployment..."
	@docker compose -f zarf/docker/compose/docker-compose.prod.yml down -v
	@docker system prune -f

prod-backup:
	@echo "Creating production backup..."
	@timestamp=$$(date +%Y%m%d_%H%M%S); \
	if [ -f zarf/docker/compose/docker-compose.prod.yml ]; then \
		docker compose -f zarf/docker/compose/docker-compose.prod.yml exec backend tar -czf /app/data/backup_$$timestamp.tar.gz -C /app/data chroma_db || true; \
		if docker compose -f zarf/docker/compose/docker-compose.prod.yml ps postgres | grep -q "Up"; then \
			docker compose -f zarf/docker/compose/docker-compose.prod.yml exec postgres pg_dump -U $${POSTGRES_USER:-hras} $${POSTGRES_DB:-hras} > backup_$$timestamp.sql || true; \
		fi; \
		echo "Backup created: backup_$$timestamp"; \
	else \
		echo "Production environment not found"; \
	fi

prod-update:
	@echo "Updating production deployment..."
	@docker compose -f zarf/docker/compose/docker-compose.prod.yml pull
	@docker compose -f zarf/docker/compose/docker-compose.prod.yml up -d --force-recreate
	@echo "Update completed"

prod-monitoring:
	@echo "Starting production monitoring stack..."
	@docker compose -f zarf/docker/compose/docker-compose.prod.yml --profile monitoring up -d
	@echo "Monitoring stack started:"
	@echo "  Grafana:      http://localhost:3001"
	@echo "  Prometheus:   http://localhost:9090"
	@echo "  Loki:         http://localhost:3100"
	@echo "  AlertManager: http://localhost:9093"
