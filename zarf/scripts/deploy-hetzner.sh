#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
DEFAULT_APP_DIR="/opt/hras"
COMPOSE_FILE="zarf/docker/compose/docker-compose.hetzner.yml"
BACKUP_ROOT="${DEFAULT_APP_DIR}/backups"
COMMAND="${1:-deploy}"
ROLLBACK_TRIGGERED=false

resolve_app_dir() {
    if [[ -n "${HRAS_APP_DIR:-}" && -f "${HRAS_APP_DIR}/${COMPOSE_FILE}" ]]; then
        printf '%s\n' "${HRAS_APP_DIR}"
        return 0
    fi

    if [[ -f "${DEFAULT_APP_DIR}/${COMPOSE_FILE}" ]]; then
        printf '%s\n' "${DEFAULT_APP_DIR}"
        return 0
    fi

    printf '%s\n' "${REPO_ROOT}"
}

APP_DIR="$(resolve_app_dir)"
ENV_FILE="${HRAS_ENV_FILE:-${APP_DIR}/.env.hetzner}"

if [[ ! -f "${ENV_FILE}" ]]; then
    if [[ -f "${REPO_ROOT}/.env.hetzner" ]]; then
        ENV_FILE="${REPO_ROOT}/.env.hetzner"
    else
        log_missing_env() {
            echo "No .env.hetzner file found. Copy .env.hetzner.example to .env.hetzner and configure it first." >&2
        }

        log_missing_env
        exit 1
    fi
fi

# shellcheck disable=SC1090
source "${ENV_FILE}"

DEPLOYMENT_LOG="${APP_DIR}/logs/app/deployment-hetzner.log"
mkdir -p "$(dirname "${DEPLOYMENT_LOG}")"
BACKUP_DIR="${BACKUP_ROOT}/$(date +%Y%m%d_%H%M%S)"
HEALTH_CHECK_URL="https://${DOMAIN}/health"
HEALTH_CHECK_TIMEOUT="${HEALTH_CHECK_TIMEOUT:-300}"

compose() {
    docker compose --env-file "${ENV_FILE}" -f "${APP_DIR}/${COMPOSE_FILE}" --profile full "$@"
}

log_info() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] $1" | tee -a "${DEPLOYMENT_LOG}"
}

log_error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] $1" | tee -a "${DEPLOYMENT_LOG}" >&2
}

log_success() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [SUCCESS] $1" | tee -a "${DEPLOYMENT_LOG}"
}

cleanup_on_exit() {
    local exit_code=$?

    if [[ ${exit_code} -ne 0 ]] && [[ "${ROLLBACK_TRIGGERED}" != "true" ]] && [[ "${COMMAND}" == "deploy" ]] && [[ "${ROLLBACK_ON_FAILURE:-true}" == "true" ]]; then
        log_error "Deployment failed with exit code ${exit_code}. Attempting rollback..."
        ROLLBACK_TRIGGERED=true
        trap - EXIT
        rollback_deployment || true
        exit ${exit_code}
    fi
}

trap cleanup_on_exit EXIT

validate_environment() {
    local required_vars=(
        DOMAIN
        APP_NAME
        APP_VERSION
        DATABASE_URL
        POSTGRES_USER
        POSTGRES_PASSWORD
        POSTGRES_DB
        CORS_ORIGINS
        TRUSTED_HOSTS
        GRAFANA_ADMIN_PASSWORD
    )

    local var
    for var in "${required_vars[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            log_error "Required environment variable ${var} is not set"
            exit 1
        fi
    done

    if ! command -v docker >/dev/null 2>&1; then
        log_error "Docker is not installed"
        exit 1
    fi

    if ! docker compose version >/dev/null 2>&1; then
        log_error "Docker Compose plugin is not installed"
        exit 1
    fi

    compose config >/dev/null
    log_success "Environment validation passed"
}

create_backup() {
    if [[ "${BACKUP_BEFORE_DEPLOY:-true}" != "true" ]]; then
        log_info "Skipping backup because BACKUP_BEFORE_DEPLOY=false"
        return 0
    fi

    log_info "Creating deployment backup at ${BACKUP_DIR}..."
    mkdir -p "${BACKUP_DIR}"

    tar \
        --exclude='./backups' \
        --exclude='./logs' \
        --exclude='./.git' \
        -czf "${BACKUP_DIR}/app.tar.gz" \
        -C "${APP_DIR}" .

    cp "${ENV_FILE}" "${BACKUP_DIR}/.env.hetzner"

    if compose ps postgres >/dev/null 2>&1; then
        compose exec -T postgres pg_dump -U "${POSTGRES_USER}" "${POSTGRES_DB}" | gzip > "${BACKUP_DIR}/database.sql.gz"
    fi

    docker run --rm \
        -v hras_chroma_data:/source:ro \
        -v "${BACKUP_DIR}:/backup" \
        alpine:3.20 \
        sh -c 'tar -czf /backup/chroma.tar.gz -C /source . || true'

    log_success "Backup created"
}

build_and_start() {
    log_info "Building and starting Hetzner stack..."
    cd "${APP_DIR}"
    compose up -d --build --remove-orphans
    log_success "Stack started"
}

wait_for_health_check() {
    log_info "Waiting for ${HEALTH_CHECK_URL} to become healthy..."

    local deadline=$(( $(date +%s) + HEALTH_CHECK_TIMEOUT ))

    while [[ $(date +%s) -lt ${deadline} ]]; do
        if curl -sSf --max-time 10 "${HEALTH_CHECK_URL}" >/dev/null 2>&1; then
            log_success "Health check passed"
            return 0
        fi

        sleep 10
    done

    log_error "Health check did not pass within ${HEALTH_CHECK_TIMEOUT} seconds"
    return 1
}

run_database_migrations() {
    log_info "Running database migrations..."
    compose exec -T backend alembic upgrade head
    log_success "Database migrations completed"
}

ingest_vector_data() {
    log_info "Checking whether vector store ingestion is required..."

    local stats_url="https://${DOMAIN}/api/v1/admin/stats"
    local document_count
    document_count=$(curl -sSf "${stats_url}" | jq -r '.document_count // .count // 0' 2>/dev/null || echo 0)

    if [[ "${document_count}" =~ ^[0-9]+$ ]] && [[ "${document_count}" -gt 0 ]]; then
        log_info "Vector store already contains ${document_count} documents. Skipping ingestion."
        return 0
    fi

    log_info "Vector store is empty. Starting ingestion..."
    curl -sSf -X POST \
        -H 'Content-Type: application/json' \
        -d '{"clear_existing": false, "use_sample": true}' \
        "https://${DOMAIN}/api/v1/admin/ingest" >/dev/null

    log_success "Vector data ingestion triggered"
}

verify_deployment() {
    local endpoints=(
        "https://${DOMAIN}/health"
        "https://${DOMAIN}/api/v1/admin/stats"
        "https://${DOMAIN}/docs"
    )

    local endpoint
    for endpoint in "${endpoints[@]}"; do
        log_info "Verifying endpoint ${endpoint}"
        curl -sSf --max-time 30 "${endpoint}" >/dev/null
    done

    curl -sSf -X POST \
        -H 'Content-Type: application/json' \
        -d '{"message": "Hello, test deployment"}' \
        "https://${DOMAIN}/api/v1/chat" >/dev/null

    log_success "Deployment verification passed"
}

cleanup_old_backups() {
    if [[ -d "${BACKUP_ROOT}" ]]; then
        find "${BACKUP_ROOT}" -mindepth 1 -maxdepth 1 -type d -mtime +"${BACKUP_RETENTION_DAYS:-30}" -exec rm -rf {} +
    fi
}

rollback_deployment() {
    local latest_backup
    latest_backup=$(find "${BACKUP_ROOT}" -mindepth 1 -maxdepth 1 -type d | sort -r | head -n 1)

    if [[ -z "${latest_backup}" ]]; then
        log_error "No backup available for rollback"
        exit 1
    fi

    log_info "Rolling back using ${latest_backup}"
    cd "${APP_DIR}"
    compose down --remove-orphans || true

    tar -xzf "${latest_backup}/app.tar.gz" -C "${APP_DIR}"

    if [[ -f "${latest_backup}/.env.hetzner" ]]; then
        cp "${latest_backup}/.env.hetzner" "${APP_DIR}/.env.hetzner"
        ENV_FILE="${APP_DIR}/.env.hetzner"
    fi

    compose up -d postgres

    local retries=0
    until compose exec -T postgres pg_isready -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" >/dev/null 2>&1; do
        retries=$((retries + 1))
        if [[ ${retries} -ge 30 ]]; then
            log_error "PostgreSQL did not become ready during rollback"
            exit 1
        fi

        sleep 2
    done

    if [[ -f "${latest_backup}/database.sql.gz" ]]; then
        gunzip -c "${latest_backup}/database.sql.gz" | compose exec -T postgres psql -U "${POSTGRES_USER}" -d "${POSTGRES_DB}"
    fi

    if [[ -f "${latest_backup}/chroma.tar.gz" ]]; then
        docker run --rm \
            -v hras_chroma_data:/target \
            -v "${latest_backup}:/backup" \
            alpine:3.20 \
            sh -c 'rm -rf /target/* && tar -xzf /backup/chroma.tar.gz -C /target'
    fi

    compose up -d --build --remove-orphans
    wait_for_health_check
    log_success "Rollback completed"
}

main() {
    case "${COMMAND}" in
        deploy)
            log_info "Starting Hetzner deployment for ${APP_NAME}:${APP_VERSION}"
            validate_environment
            create_backup
            build_and_start
            wait_for_health_check
            run_database_migrations
            ingest_vector_data
            verify_deployment
            cleanup_old_backups
            log_success "Hetzner deployment completed successfully"
            ;;
        rollback)
            rollback_deployment
            ;;
        health-check)
            "${SCRIPT_DIR}/health-check-hetzner.sh"
            ;;
        *)
            log_error "Unknown command: ${COMMAND}. Use deploy, rollback, or health-check."
            exit 1
            ;;
    esac
}

main "$@"
