#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../docker/config/deployment.env"

DEPLOYMENT_LOG="/opt/hras/logs/app/deployment.log"
BACKUP_DIR="/opt/hras/backups/$(date +%Y%m%d_%H%M%S)"
HEALTH_CHECK_URL="https://${DOMAIN}/health"
HEALTH_CHECK_TIMEOUT=${HEALTH_CHECK_TIMEOUT:-300}

log_info() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] $1" | tee -a "${DEPLOYMENT_LOG}"
}

log_error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] $1" | tee -a "${DEPLOYMENT_LOG}" >&2
}

log_success() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [SUCCESS] $1" | tee -a "${DEPLOYMENT_LOG}"
}

log_warning() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [WARNING] $1" | tee -a "${DEPLOYMENT_LOG}"
}

cleanup_on_exit() {
    local exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        log_error "Deployment failed with exit code $exit_code"
        if [[ "${ROLLBACK_ON_FAILURE:-true}" == "true" ]]; then
            log_info "Initiating automatic rollback..."
            rollback_deployment
        fi
    fi
}

trap cleanup_on_exit EXIT

validate_environment() {
    log_info "Validating deployment environment..."

    local required_vars=(
        "DOMAIN"
        "APP_NAME"
        "APP_VERSION"
        "BACKEND_PORT"
    )

    for var in "${required_vars[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            log_error "Required environment variable $var is not set"
            exit 1
        fi
    done

    if ! command -v docker >/dev/null 2>&1; then
        log_error "Docker is not installed or not in PATH"
        exit 1
    fi

    if ! command -v docker-compose >/dev/null 2>&1; then
        log_error "Docker Compose is not installed or not in PATH"
        exit 1
    fi

    if ! systemctl is-active --quiet nginx; then
        log_error "Nginx is not running"
        exit 1
    fi

    log_success "Environment validation passed"
}

create_backup() {
    if [[ "${BACKUP_BEFORE_DEPLOY:-true}" != "true" ]]; then
        log_info "Skipping backup (disabled in configuration)"
        return 0
    fi

    log_info "Creating deployment backup..."

    mkdir -p "${BACKUP_DIR}"

    if [[ -d "/opt/hras/app" ]]; then
        log_info "Backing up application files..."
        tar -czf "${BACKUP_DIR}/app.tar.gz" -C /opt/hras app/ || {
            log_warning "Failed to backup application files"
        }
    fi

    if systemctl is-active --quiet postgresql && [[ "${USE_POSTGRES:-false}" == "true" ]]; then
        log_info "Backing up PostgreSQL database..."
        docker exec hras_postgres_1 pg_dump -U "${POSTGRES_USER}" "${POSTGRES_DB}" | gzip > "${BACKUP_DIR}/database.sql.gz" || {
            log_warning "Failed to backup database"
        }
    fi

    if [[ -d "/opt/hras/data/chroma" ]]; then
        log_info "Backing up vector database..."
        tar -czf "${BACKUP_DIR}/vectordb.tar.gz" -C /opt/hras/data chroma/ || {
            log_warning "Failed to backup vector database"
        }
    fi

    echo "$(date -Iseconds)" > "${BACKUP_DIR}/timestamp"
    echo "${APP_VERSION}" > "${BACKUP_DIR}/version"

    log_success "Backup created at ${BACKUP_DIR}"
}

pull_latest_code() {
    log_info "Pulling latest application code..."

    cd /opt/hras/app

    if [[ -d ".git" ]]; then
        log_info "Updating from Git repository..."
        git fetch origin
        git reset --hard origin/main
    else
        log_error "Git repository not found in /opt/hras/app"
        exit 1
    fi

    log_success "Code updated successfully"
}

build_docker_images() {
    log_info "Building Docker images..."

    cd /opt/hras/app

    export DOCKER_BUILDKIT=1

    if ! docker-compose -f zarf/docker/compose/docker-compose.prod.yml build --no-cache; then
        log_error "Failed to build Docker images"
        exit 1
    fi

    log_success "Docker images built successfully"
}

perform_rolling_deployment() {
    log_info "Performing rolling deployment..."

    cd /opt/hras/app

    local services=("backend" "postgres" "redis")

    for service in "${services[@]}"; do
        if docker-compose -f zarf/docker/compose/docker-compose.prod.yml ps -q "$service" >/dev/null 2>&1; then
            log_info "Rolling update for service: $service"

            docker-compose -f zarf/docker/compose/docker-compose.prod.yml up -d --no-deps "$service"

            if [[ "$service" == "backend" ]]; then
                log_info "Waiting for backend service to be healthy..."
                wait_for_health_check
            else
                sleep 10
            fi
        else
            log_info "Starting new service: $service"
            docker-compose -f zarf/docker/compose/docker-compose.prod.yml up -d "$service"
        fi
    done

    log_success "Rolling deployment completed"
}

perform_blue_green_deployment() {
    log_info "Performing blue-green deployment..."

    cd /opt/hras/app

    local new_compose_file="docker-compose.blue-green.yml"
    local current_color
    local new_color

    if docker-compose -f zarf/docker/compose/docker-compose.prod.yml ps -q backend-green >/dev/null 2>&1; then
        current_color="green"
        new_color="blue"
    else
        current_color="blue"
        new_color="green"
    fi

    log_info "Current environment: $current_color, deploying to: $new_color"

    sed "s/SERVICE_COLOR/$new_color/g" docker-compose.blue-green.template.yml > "$new_compose_file"

    docker-compose -f "$new_compose_file" up -d

    log_info "Waiting for new environment to be healthy..."
    HEALTH_CHECK_URL="https://${DOMAIN}:808${new_color: -1}/health"
    wait_for_health_check

    log_info "Switching traffic to new environment..."
    update_nginx_upstream "$new_color"

    log_info "Stopping old environment..."
    docker-compose -f zarf/docker/compose/docker-compose.prod.yml down

    mv "$new_compose_file" docker-compose.prod.yml

    log_success "Blue-green deployment completed"
}

update_nginx_upstream() {
    local color=$1
    local port="808${color: -1}"

    log_info "Updating Nginx upstream to use $color environment (port $port)"

    sudo sed -i "s/server 127.0.0.1:[0-9]*/server 127.0.0.1:$port/" /etc/nginx/sites-available/hras
    sudo nginx -t && sudo systemctl reload nginx
}

wait_for_health_check() {
    log_info "Waiting for application to be healthy..."

    local start_time=$(date +%s)
    local timeout=$((start_time + HEALTH_CHECK_TIMEOUT))

    while [[ $(date +%s) -lt $timeout ]]; do
        if curl -sSf --max-time 10 "${HEALTH_CHECK_URL}" >/dev/null 2>&1; then
            log_success "Application is healthy"
            return 0
        fi

        log_info "Application not ready yet, waiting..."
        sleep 10
    done

    log_error "Application failed to become healthy within ${HEALTH_CHECK_TIMEOUT} seconds"
    return 1
}

run_database_migrations() {
    if [[ "${USE_POSTGRES:-false}" != "true" ]]; then
        log_info "PostgreSQL not enabled, skipping migrations"
        return 0
    fi

    log_info "Running database migrations..."

    cd /opt/hras/app

    if ! docker-compose -f zarf/docker/compose/docker-compose.prod.yml exec -T backend alembic upgrade head; then
        log_error "Database migration failed"
        exit 1
    fi

    log_success "Database migrations completed"
}

ingest_vector_data() {
    log_info "Checking if vector data ingestion is needed..."

    if curl -sSf "${HEALTH_CHECK_URL%/health}/api/v1/admin/stats" | jq -e '.document_count > 0' >/dev/null 2>&1; then
        log_info "Vector data already exists, skipping ingestion"
        return 0
    fi

    log_info "Ingesting vector data..."

    if ! curl -sSf -X POST "${HEALTH_CHECK_URL%/health}/api/v1/admin/ingest"; then
        log_error "Vector data ingestion failed"
        exit 1
    fi

    log_success "Vector data ingestion completed"
}

verify_deployment() {
    log_info "Verifying deployment..."

    local endpoints=(
        "${HEALTH_CHECK_URL}"
        "https://${DOMAIN}/api/v1/admin/stats"
    )

    for endpoint in "${endpoints[@]}"; do
        log_info "Testing endpoint: $endpoint"

        if ! curl -sSf --max-time 30 "$endpoint" >/dev/null; then
            log_error "Endpoint verification failed: $endpoint"
            return 1
        fi
    done

    log_info "Testing application functionality..."

    local test_payload='{"message": "Test deployment message"}'
    if ! curl -sSf -X POST \
        -H "Content-Type: application/json" \
        -d "$test_payload" \
        "https://${DOMAIN}/api/v1/chat" >/dev/null; then
        log_error "Application functionality test failed"
        return 1
    fi

    log_success "Deployment verification passed"
}

cleanup_old_resources() {
    log_info "Cleaning up old Docker resources..."

    docker image prune -f
    docker container prune -f
    docker volume prune -f

    log_info "Cleaning up old backups..."

    find /opt/hras/backups -type d -mtime +${BACKUP_RETENTION_DAYS:-30} -exec rm -rf {} + 2>/dev/null || true

    log_success "Cleanup completed"
}

rollback_deployment() {
    log_error "Rolling back deployment..."

    local latest_backup
    latest_backup=$(find /opt/hras/backups -maxdepth 1 -type d -name "20*" | sort -r | head -n1)

    if [[ -z "$latest_backup" ]]; then
        log_error "No backup found for rollback"
        exit 1
    fi

    log_info "Rolling back to backup: $latest_backup"

    cd /opt/hras/app
    docker-compose -f zarf/docker/compose/docker-compose.prod.yml down

    if [[ -f "$latest_backup/app.tar.gz" ]]; then
        log_info "Restoring application files..."
        rm -rf /opt/hras/app/*
        tar -xzf "$latest_backup/app.tar.gz" -C /opt/hras/
    fi

    if [[ -f "$latest_backup/database.sql.gz" ]] && [[ "${USE_POSTGRES:-false}" == "true" ]]; then
        log_info "Restoring database..."
        gunzip -c "$latest_backup/database.sql.gz" | docker exec -i hras_postgres_1 psql -U "${POSTGRES_USER}" -d "${POSTGRES_DB}"
    fi

    if [[ -f "$latest_backup/vectordb.tar.gz" ]]; then
        log_info "Restoring vector database..."
        rm -rf /opt/hras/data/chroma
        tar -xzf "$latest_backup/vectordb.tar.gz" -C /opt/hras/data/
    fi

    cd /opt/hras/app
    docker-compose -f zarf/docker/compose/docker-compose.prod.yml up -d

    log_success "Rollback completed"
}

main() {
    log_info "Starting HRAS deployment process..."
    log_info "Version: ${APP_VERSION}"
    log_info "Strategy: ${DEPLOYMENT_STRATEGY:-rolling}"

    validate_environment
    create_backup
    pull_latest_code
    build_docker_images

    case "${DEPLOYMENT_STRATEGY:-rolling}" in
        "rolling")
            perform_rolling_deployment
            ;;
        "blue-green")
            perform_blue_green_deployment
            ;;
        *)
            log_error "Unknown deployment strategy: ${DEPLOYMENT_STRATEGY:-rolling}"
            exit 1
            ;;
    esac

    run_database_migrations
    ingest_vector_data
    verify_deployment
    cleanup_old_resources

    log_success "Deployment completed successfully!"

    echo "
===========================================
HRAS Deployment Complete
===========================================

Application Information:
- Version: ${APP_VERSION}
- URL: https://${DOMAIN}
- Health Check: ${HEALTH_CHECK_URL}
- Strategy: ${DEPLOYMENT_STRATEGY:-rolling}

Backup Information:
- Backup Directory: ${BACKUP_DIR}
- Retention: ${BACKUP_RETENTION_DAYS:-30} days

Monitoring:
- Application logs: /opt/hras/logs/app/
- Deployment log: ${DEPLOYMENT_LOG}
- System status: systemctl status hras

Next Steps:
1. Monitor application health
2. Check logs for any issues
3. Verify all functionality works correctly
"
}

main "$@"
