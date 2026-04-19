#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
APP_DIR="${HRAS_APP_DIR:-/opt/hras}"
COMPOSE_FILE="zarf/docker/compose/docker-compose.hetzner.yml"

if [[ ! -f "${APP_DIR}/${COMPOSE_FILE}" ]]; then
    APP_DIR="${REPO_ROOT}"
fi

ENV_FILE="${HRAS_ENV_FILE:-${APP_DIR}/.env.hetzner}"
if [[ ! -f "${ENV_FILE}" ]]; then
    ENV_FILE="${REPO_ROOT}/.env.hetzner.example"
fi

# shellcheck disable=SC1090
source "${ENV_FILE}"

compose() {
    docker compose --env-file "${ENV_FILE}" -f "${APP_DIR}/${COMPOSE_FILE}" --profile full "$@"
}

log_info() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] $1"
}

log_error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] $1" >&2
}

log_success() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [SUCCESS] $1"
}

check_url() {
    local label=$1
    local url=$2
    if curl -sSf --max-time 15 "${url}" >/dev/null 2>&1; then
        log_success "${label} responded successfully"
        return 0
    fi

    log_error "${label} check failed: ${url}"
    return 1
}

check_ssl() {
    local cert_info
    cert_info=$(echo | openssl s_client -servername "${DOMAIN}" -connect "${DOMAIN}:443" 2>/dev/null | openssl x509 -noout -dates 2>/dev/null || true)

    if [[ -z "${cert_info}" ]]; then
        log_error "Unable to read SSL certificate for ${DOMAIN}"
        return 1
    fi

    local not_after
    not_after=$(printf '%s\n' "${cert_info}" | grep 'notAfter=' | cut -d= -f2)
    log_success "SSL certificate valid until ${not_after}"
}

check_docker_services() {
    local failed=0
    local services=(caddy postgres ollama backend prometheus grafana postgres-exporter loki promtail)
    local running_services
    running_services=$(compose ps --services --status running 2>/dev/null || true)

    for service in "${services[@]}"; do
        if printf '%s\n' "${running_services}" | grep -Fxq "${service}"; then
            log_success "${service} is running"
        else
            log_error "${service} is not running"
            failed=1
        fi
    done

    return ${failed}
}

check_database() {
    if compose exec -T postgres pg_isready -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" >/dev/null 2>&1; then
        log_success "Database is reachable"
        return 0
    fi

    log_error "Database connectivity check failed"
    return 1
}

main() {
    local failed=0

    check_docker_services || failed=1
    check_url "API health endpoint" "https://${DOMAIN}/health" || failed=1
    check_url "Admin stats endpoint" "https://${DOMAIN}/api/v1/admin/stats" || failed=1
    check_database || failed=1
    check_ssl || failed=1

    if [[ ${failed} -eq 0 ]]; then
        log_success "Hetzner deployment health checks passed"
        exit 0
    fi

    log_error "Hetzner deployment health checks failed"
    exit 1
}

main "$@"
