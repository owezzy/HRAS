#!/bin/bash

set -euo pipefail

BACKEND_IMAGE=${BACKEND_IMAGE:-}
FRONTEND_IMAGE=${FRONTEND_IMAGE:-}
IMAGE_TAG=${IMAGE_TAG:-latest}
DOMAIN=${DOMAIN:-localhost}

if [[ -z "$BACKEND_IMAGE" ]] || [[ -z "$FRONTEND_IMAGE" ]]; then
    echo "❌ BACKEND_IMAGE and FRONTEND_IMAGE environment variables are required"
    exit 1
fi

DEPLOYMENT_DIR="/opt/hras"
BACKUP_DIR="/opt/hras/backups"
COMPOSE_FILE="$DEPLOYMENT_DIR/docker-compose.yml"

echo "🚀 Starting HRAS deployment..."
echo "  Backend Image: $BACKEND_IMAGE"
echo "  Frontend Image: $FRONTEND_IMAGE"
echo "  Domain: $DOMAIN"

cd "$DEPLOYMENT_DIR"

echo "💾 Creating backup of current deployment..."
if [[ -f "$COMPOSE_FILE" ]]; then
    BACKUP_NAME="backup-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$BACKUP_DIR/$BACKUP_NAME"

    cp docker-compose.yml "$BACKUP_DIR/$BACKUP_NAME/" || true
    cp .env "$BACKUP_DIR/$BACKUP_NAME/" || true

    if docker compose ps -q | grep -q .; then
        docker compose ps > "$BACKUP_DIR/$BACKUP_NAME/containers.txt"
        echo "$(date): Backup created at $BACKUP_DIR/$BACKUP_NAME" >> "$BACKUP_DIR/backup.log"
    fi
fi

echo "📝 Creating environment file..."
cat > .env << EOF
# Application Configuration
BACKEND_IMAGE=$BACKEND_IMAGE
FRONTEND_IMAGE=$FRONTEND_IMAGE
DOMAIN=$DOMAIN

# Database Configuration
DATABASE_URL=${DATABASE_URL:-sqlite+aiosqlite:///./data/hras.db}
POSTGRES_DB=${POSTGRES_DB:-hras}
POSTGRES_USER=${POSTGRES_USER:-hras}
POSTGRES_PASSWORD=${POSTGRES_PASSWORD:-$(openssl rand -base64 32)}

# AI Configuration
OLLAMA_BASE_URL=${OLLAMA_BASE_URL:-http://host.docker.internal:11434}
OLLAMA_MODEL=${OLLAMA_MODEL:-nemotron-3-nano:30b-cloud}
OLLAMA_EMBEDDING_MODEL=${OLLAMA_EMBEDDING_MODEL:-nomic-embed-text}

# Application Settings
CORS_ORIGINS=["https://$DOMAIN"]
USE_POSTGRES=true
USE_ASYNC_TOOLS=true

# Security
JWT_SECRET_KEY=$(openssl rand -base64 64)

# Monitoring
PROMETHEUS_METRICS_PORT=9090
GRAFANA_ADMIN_PASSWORD=${GRAFANA_ADMIN_PASSWORD:-$(openssl rand -base64 16)}

# Paths
CHROMA_PERSIST_DIRECTORY=/app/data/chroma_db
LOG_LEVEL=${LOG_LEVEL:-INFO}
EOF

echo "🐳 Creating Docker Compose configuration..."
cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  postgres:
    image: postgres:15-alpine
    container_name: hras-postgres
    environment:
      POSTGRES_DB: ${POSTGRES_DB}
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./data/postgres-backups:/backups
    ports:
      - "5432:5432"
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER} -d ${POSTGRES_DB}"]
      interval: 10s
      timeout: 5s
      retries: 5
    restart: unless-stopped
    networks:
      - hras-network

  backend:
    image: ${BACKEND_IMAGE}
    container_name: hras-backend
    depends_on:
      postgres:
        condition: service_healthy
    environment:
      - DATABASE_URL=postgresql+asyncpg://${POSTGRES_USER}:${POSTGRES_PASSWORD}@postgres:5432/${POSTGRES_DB}
      - OLLAMA_BASE_URL=${OLLAMA_BASE_URL}
      - OLLAMA_MODEL=${OLLAMA_MODEL}
      - OLLAMA_EMBEDDING_MODEL=${OLLAMA_EMBEDDING_MODEL}
      - CHROMA_PERSIST_DIRECTORY=${CHROMA_PERSIST_DIRECTORY}
      - CORS_ORIGINS=${CORS_ORIGINS}
      - USE_POSTGRES=${USE_POSTGRES}
      - USE_ASYNC_TOOLS=${USE_ASYNC_TOOLS}
      - LOG_LEVEL=${LOG_LEVEL}
    volumes:
      - app_data:/app/data
      - ./logs:/app/logs
    ports:
      - "8000:8000"
    healthcheck:
      test: ["CMD", "python", "-c", "import requests; requests.get('http://localhost:8000/health')"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s
    restart: unless-stopped
    networks:
      - hras-network
    logging:
      driver: "json-file"
      options:
        max-size: "100m"
        max-file: "3"

  frontend:
    image: ${FRONTEND_IMAGE}
    container_name: hras-frontend
    depends_on:
      backend:
        condition: service_healthy
    environment:
      - NEXT_PUBLIC_API_URL=https://${DOMAIN}/api
      - NODE_ENV=production
    ports:
      - "3000:3000"
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3000/"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
    restart: unless-stopped
    networks:
      - hras-network
    logging:
      driver: "json-file"
      options:
        max-size: "100m"
        max-file: "3"

  # Data ingestion job (runs once)
  ingest:
    image: ${BACKEND_IMAGE}
    container_name: hras-ingest
    depends_on:
      backend:
        condition: service_healthy
    environment:
      - DATABASE_URL=postgresql+asyncpg://${POSTGRES_USER}:${POSTGRES_PASSWORD}@postgres:5432/${POSTGRES_DB}
      - OLLAMA_BASE_URL=${OLLAMA_BASE_URL}
      - OLLAMA_MODEL=${OLLAMA_MODEL}
      - OLLAMA_EMBEDDING_MODEL=${OLLAMA_EMBEDDING_MODEL}
      - CHROMA_PERSIST_DIRECTORY=${CHROMA_PERSIST_DIRECTORY}
    volumes:
      - app_data:/app/data
    command: |
      sh -c "
        echo 'Waiting for backend to be ready...'
        sleep 60
        echo 'Starting data ingestion...'
        python -c \"
        import requests
        import time
        import sys

        max_retries = 10
        for i in range(max_retries):
            try:
                response = requests.post('http://backend:8000/api/v1/admin/ingest', timeout=300)
                if response.status_code == 200:
                    print('✅ Data ingestion completed successfully')
                    sys.exit(0)
                else:
                    print(f'❌ Ingestion failed with status {response.status_code}')
                    print(response.text)
            except Exception as e:
                print(f'⏳ Ingestion attempt {i+1}/{max_retries} failed: {e}')
                if i < max_retries - 1:
                    time.sleep(30)

        print('❌ Data ingestion failed after all retries')
        sys.exit(1)
        \"
      "
    restart: "no"
    networks:
      - hras-network

volumes:
  postgres_data:
    driver: local
  app_data:
    driver: local

networks:
  hras-network:
    driver: bridge
EOF

echo "🔄 Pulling latest images..."
docker compose pull

echo "🛑 Gracefully stopping existing containers..."
if docker compose ps -q | grep -q .; then
    docker compose down --timeout 30
fi

echo "🆙 Starting services..."
docker compose up -d postgres

echo "⏳ Waiting for database to be ready..."
timeout 60 bash -c 'until docker compose exec postgres pg_isready -U $POSTGRES_USER -d $POSTGRES_DB; do sleep 2; done'

echo "🚀 Starting application services..."
docker compose up -d backend frontend

echo "⏳ Waiting for services to be healthy..."
timeout 120 bash -c 'until docker compose exec backend python -c "import requests; requests.get(\"http://localhost:8000/health\")" > /dev/null 2>&1; do sleep 5; done'

echo "📊 Running data ingestion..."
docker compose up ingest

echo "🧹 Cleaning up old images..."
docker image prune -f

echo "📋 Creating health check script..."
cat > health-check.sh << 'EOF'
#!/bin/bash

echo "🔍 HRAS Health Check"
echo "===================="

echo ""
echo "📊 Container Status:"
docker compose ps

echo ""
echo "🔗 Service Health:"

if curl -f http://localhost:8000/health > /dev/null 2>&1; then
    echo "✅ Backend: Healthy"
else
    echo "❌ Backend: Unhealthy"
fi

if curl -f http://localhost:3000/ > /dev/null 2>&1; then
    echo "✅ Frontend: Healthy"
else
    echo "❌ Frontend: Unhealthy"
fi

echo ""
echo "🎯 External Health:"

if curl -f https://$DOMAIN/health > /dev/null 2>&1; then
    echo "✅ External Backend: Healthy"
else
    echo "❌ External Backend: Unhealthy"
fi

if curl -f https://$DOMAIN/ > /dev/null 2>&1; then
    echo "✅ External Frontend: Healthy"
else
    echo "❌ External Frontend: Unhealthy"
fi

echo ""
echo "📈 Resource Usage:"
docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}"
EOF

chmod +x health-check.sh

echo "🔄 Creating rollback script..."
cat > rollback.sh << 'EOF'
#!/bin/bash

set -euo pipefail

BACKUP_DIR="/opt/hras/backups"

echo "🔄 HRAS Rollback Script"
echo "======================"

if [[ ! -d "$BACKUP_DIR" ]]; then
    echo "❌ No backups found in $BACKUP_DIR"
    exit 1
fi

echo ""
echo "📂 Available backups:"
ls -la "$BACKUP_DIR"

LATEST_BACKUP=$(ls -1t "$BACKUP_DIR" | head -1)

if [[ -z "$LATEST_BACKUP" ]]; then
    echo "❌ No backup directories found"
    exit 1
fi

echo ""
echo "🔄 Rolling back to: $LATEST_BACKUP"

if [[ ! -f "$BACKUP_DIR/$LATEST_BACKUP/docker-compose.yml" ]]; then
    echo "❌ Backup $LATEST_BACKUP does not contain docker-compose.yml"
    exit 1
fi

echo "🛑 Stopping current services..."
docker compose down --timeout 30

echo "📋 Restoring configuration files..."
cp "$BACKUP_DIR/$LATEST_BACKUP/docker-compose.yml" .
if [[ -f "$BACKUP_DIR/$LATEST_BACKUP/.env" ]]; then
    cp "$BACKUP_DIR/$LATEST_BACKUP/.env" .
fi

echo "🆙 Starting restored services..."
docker compose up -d

echo "⏳ Waiting for services..."
sleep 30

echo "🔍 Health check after rollback..."
./health-check.sh

echo "✅ Rollback complete!"
echo "$(date): Rolled back to $LATEST_BACKUP" >> "$BACKUP_DIR/rollback.log"
EOF

chmod +x rollback.sh

echo "⏳ Final health check..."
sleep 10
./health-check.sh

echo "✅ Deployment complete!"
echo ""
echo "🌐 Application URLs:"
echo "  Frontend: https://$DOMAIN"
echo "  Backend API: https://$DOMAIN/api"
echo "  Health Check: https://$DOMAIN/health"
echo ""
echo "📊 Management Commands:"
echo "  Health Check: ./health-check.sh"
echo "  Rollback: ./rollback.sh"
echo "  Logs: docker compose logs -f"
echo "  Restart: docker compose restart"
