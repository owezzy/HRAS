#!/bin/bash
set -euo pipefail

# HRAS Production Deployment Script
# This script deploys HRAS backend with Nginx reverse proxy to production

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
COMPOSE_FILE="$PROJECT_ROOT/docker-compose.prod.yml"
ENV_FILE="$PROJECT_ROOT/.env.prod"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_prerequisites() {
    log_info "Checking prerequisites..."

    command -v docker >/dev/null 2>&1 || { log_error "Docker is required but not installed. Aborting."; exit 1; }
    command -v docker compose >/dev/null 2>&1 || { log_error "Docker Compose is required but not installed. Aborting."; exit 1; }

    if [[ ! -f "$ENV_FILE" ]]; then
        log_error "Environment file $ENV_FILE not found. Please copy .env.prod.example and configure it."
        exit 1
    fi

    log_info "Prerequisites check completed."
}

create_directories() {
    log_info "Creating required directories..."

    source "$ENV_FILE"

    sudo mkdir -p "${DATA_PATH:-./data}"/{backend,postgres,redis,prometheus,loki,grafana,alertmanager}
    sudo mkdir -p "${LOGS_PATH:-./data/logs}"/{nginx,backend,postgres,redis,certbot}
    sudo mkdir -p "${SSL_CERT_PATH:-./data/certbot}"/{data,challenges}

    sudo chown -R 1000:1000 "${DATA_PATH:-./data}/backend"
    sudo chown -R 70:70 "${DATA_PATH:-./data}/postgres"
    sudo chown -R 999:999 "${DATA_PATH:-./data}/redis"
    sudo chown -R 65534:65534 "${DATA_PATH:-./data}/prometheus"
    sudo chown -R 10001:10001 "${DATA_PATH:-./data}/loki"
    sudo chown -R 472:472 "${DATA_PATH:-./data}/grafana"
    sudo chown -R 65534:65534 "${DATA_PATH:-./data}/alertmanager"

    log_info "Directories created and permissions set."
}

setup_ssl() {
    log_info "Setting up SSL certificates..."

    if docker compose -f "$COMPOSE_FILE" --profile init up certbot-init; then
        log_info "SSL certificates obtained successfully."
    else
        log_warn "SSL certificate setup failed. You may need to configure DNS first."
    fi
}

deploy_backend() {
    log_info "Deploying HRAS backend services..."

    cd "$PROJECT_ROOT"

    # Build and start core services
    docker compose -f "$COMPOSE_FILE" build backend
    docker compose -f "$COMPOSE_FILE" up -d nginx backend

    # Wait for backend to be healthy
    log_info "Waiting for backend to be healthy..."
    timeout=60
    while ! docker compose -f "$COMPOSE_FILE" ps backend | grep -q "healthy" && [ $timeout -gt 0 ]; do
        sleep 2
        timeout=$((timeout - 2))
    done

    if [ $timeout -le 0 ]; then
        log_error "Backend failed to become healthy within 60 seconds."
        docker compose -f "$COMPOSE_FILE" logs backend
        exit 1
    fi

    log_info "Backend is healthy and running."
}

deploy_database() {
    local profile="$1"

    if [[ "$profile" == "postgres" ]]; then
        log_info "Deploying PostgreSQL database..."
        docker compose -f "$COMPOSE_FILE" --profile postgres up -d postgres

        # Wait for postgres to be ready
        log_info "Waiting for PostgreSQL to be ready..."
        timeout=30
        while ! docker compose -f "$COMPOSE_FILE" exec postgres pg_isready -U "${POSTGRES_USER:-hras}" && [ $timeout -gt 0 ]; do
            sleep 2
            timeout=$((timeout - 2))
        done

        if [ $timeout -le 0 ]; then
            log_error "PostgreSQL failed to start within 30 seconds."
            exit 1
        fi

        log_info "PostgreSQL is ready."
    fi
}

deploy_monitoring() {
    log_info "Deploying monitoring stack..."

    docker compose -f "$COMPOSE_FILE" --profile monitoring up -d prometheus loki grafana alertmanager promtail

    log_info "Monitoring stack deployed."
    log_info "Grafana: http://localhost:${GRAFANA_PORT:-3001}"
    log_info "Prometheus: http://localhost:${PROMETHEUS_PORT:-9090}"
}

deploy_certbot() {
    log_info "Starting SSL certificate renewal daemon..."
    docker compose -f "$COMPOSE_FILE" up -d certbot
}

verify_deployment() {
    log_info "Verifying deployment..."

    source "$ENV_FILE"

    # Check backend health
    if curl -f "https://${DOMAIN}/health" >/dev/null 2>&1; then
        log_info "✓ Backend health check passed"
    else
        log_warn "✗ Backend health check failed"
    fi

    # Check SSL certificate
    if echo | openssl s_client -servername "${DOMAIN}" -connect "${DOMAIN}:443" 2>/dev/null | openssl x509 -noout -dates 2>/dev/null; then
        log_info "✓ SSL certificate is valid"
    else
        log_warn "✗ SSL certificate check failed"
    fi

    log_info "Deployment verification completed."
}

show_status() {
    log_info "Current deployment status:"
    docker compose -f "$COMPOSE_FILE" ps

    log_info "\nLog locations:"
    source "$ENV_FILE"
    echo "  Nginx logs: ${LOGS_PATH:-./data/logs}/nginx/"
    echo "  Backend logs: ${LOGS_PATH:-./data/logs}/backend/"
    echo "  SSL logs: ${LOGS_PATH:-./data/logs}/certbot/"
}

show_help() {
    cat << EOF
HRAS Production Deployment Script

Usage: $0 [OPTIONS] COMMAND

Commands:
    deploy          Deploy the full HRAS stack
    deploy-backend  Deploy only backend services (nginx + backend)
    deploy-db       Deploy database (requires --postgres flag)
    deploy-monitor  Deploy monitoring stack
    ssl-init        Initialize SSL certificates
    ssl-daemon      Start SSL renewal daemon
    verify          Verify deployment health
    status          Show current status
    help            Show this help message

Options:
    --postgres      Include PostgreSQL database
    --redis         Include Redis cache
    --monitoring    Include monitoring stack (Prometheus, Grafana, etc.)
    --ssl-init      Initialize SSL certificates before deployment

Examples:
    $0 deploy --postgres --monitoring --ssl-init
    $0 deploy-backend
    $0 verify
    $0 status

EOF
}

main() {
    local cmd=""
    local include_postgres=false
    local include_redis=false
    local include_monitoring=false
    local init_ssl=false

    while [[ $# -gt 0 ]]; do
        case $1 in
            --postgres)
                include_postgres=true
                shift
                ;;
            --redis)
                include_redis=true
                shift
                ;;
            --monitoring)
                include_monitoring=true
                shift
                ;;
            --ssl-init)
                init_ssl=true
                shift
                ;;
            deploy|deploy-backend|deploy-db|deploy-monitor|ssl-init|ssl-daemon|verify|status|help)
                cmd="$1"
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done

    if [[ -z "$cmd" ]]; then
        show_help
        exit 1
    fi

    case $cmd in
        help)
            show_help
            ;;
        deploy)
            check_prerequisites
            create_directories

            if [[ "$init_ssl" == true ]]; then
                setup_ssl
            fi

            if [[ "$include_postgres" == true ]]; then
                deploy_database "postgres"
            fi

            if [[ "$include_redis" == true ]]; then
                docker compose -f "$COMPOSE_FILE" --profile redis up -d redis
            fi

            deploy_backend
            deploy_certbot

            if [[ "$include_monitoring" == true ]]; then
                deploy_monitoring
            fi

            verify_deployment
            show_status
            ;;
        deploy-backend)
            check_prerequisites
            create_directories
            deploy_backend
            deploy_certbot
            show_status
            ;;
        deploy-db)
            check_prerequisites
            if [[ "$include_postgres" == true ]]; then
                deploy_database "postgres"
            else
                log_error "No database type specified. Use --postgres flag."
                exit 1
            fi
            ;;
        deploy-monitor)
            check_prerequisites
            deploy_monitoring
            ;;
        ssl-init)
            check_prerequisites
            setup_ssl
            ;;
        ssl-daemon)
            check_prerequisites
            deploy_certbot
            ;;
        verify)
            verify_deployment
            ;;
        status)
            show_status
            ;;
    esac
}

# Run main function with all arguments
main "$@"
