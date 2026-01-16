#!/bin/bash
set -euo pipefail

# HRAS Health Check Script for Route53 and Monitoring
# This script performs comprehensive health checks on the HRAS deployment

# Configuration
DOMAIN="${DOMAIN:-localhost}"
HEALTH_TOKEN="${HEALTH_CHECK_TOKEN:-}"
TIMEOUT=10
VERBOSE=false

# Exit codes
EXIT_OK=0
EXIT_WARNING=1
EXIT_CRITICAL=2
EXIT_UNKNOWN=3

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_ok() {
    echo -e "${GREEN}[OK]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_critical() {
    echo -e "${RED}[CRITICAL]${NC} $1"
}

log_info() {
    if [[ "$VERBOSE" == true ]]; then
        echo -e "[INFO] $1"
    fi
}

check_backend_health() {
    local url="https://${DOMAIN}/health"
    if [[ -n "$HEALTH_TOKEN" ]]; then
        url="${url}?token=${HEALTH_TOKEN}"
    fi

    log_info "Checking backend health at $url"

    local response
    if response=$(curl -s --max-time "$TIMEOUT" "$url" 2>/dev/null); then
        if echo "$response" | grep -q "healthy\|ok" 2>/dev/null; then
            log_ok "Backend health check passed"
            return $EXIT_OK
        else
            log_critical "Backend health check failed: Invalid response"
            return $EXIT_CRITICAL
        fi
    else
        log_critical "Backend health check failed: Connection error"
        return $EXIT_CRITICAL
    fi
}

check_ssl_certificate() {
    log_info "Checking SSL certificate for $DOMAIN"

    local cert_info
    if cert_info=$(echo | openssl s_client -servername "$DOMAIN" -connect "${DOMAIN}:443" 2>/dev/null | openssl x509 -noout -dates 2>/dev/null); then
        local expiry_date
        expiry_date=$(echo "$cert_info" | grep "notAfter" | cut -d= -f2)

        local expiry_timestamp
        expiry_timestamp=$(date -d "$expiry_date" +%s 2>/dev/null)
        local current_timestamp
        current_timestamp=$(date +%s)
        local days_until_expiry=$(( (expiry_timestamp - current_timestamp) / 86400 ))

        if [[ $days_until_expiry -lt 0 ]]; then
            log_critical "SSL certificate has expired"
            return $EXIT_CRITICAL
        elif [[ $days_until_expiry -lt 7 ]]; then
            log_warn "SSL certificate expires in $days_until_expiry days"
            return $EXIT_WARNING
        elif [[ $days_until_expiry -lt 30 ]]; then
            log_warn "SSL certificate expires in $days_until_expiry days"
            return $EXIT_WARNING
        else
            log_ok "SSL certificate valid for $days_until_expiry days"
            return $EXIT_OK
        fi
    else
        log_critical "SSL certificate check failed"
        return $EXIT_CRITICAL
    fi
}

check_api_endpoints() {
    log_info "Checking API endpoints"

    local base_url="https://${DOMAIN}"
    local endpoints=("/" "/docs" "/openapi.json")
    local failed=0

    for endpoint in "${endpoints[@]}"; do
        local url="${base_url}${endpoint}"
        local status

        if status=$(curl -s -o /dev/null -w "%{http_code}" --max-time "$TIMEOUT" "$url" 2>/dev/null); then
            case $status in
                200|301|302|404)
                    log_info "Endpoint $endpoint: HTTP $status (OK)"
                    ;;
                *)
                    log_warn "Endpoint $endpoint: HTTP $status"
                    ((failed++))
                    ;;
            esac
        else
            log_warn "Endpoint $endpoint: Connection failed"
            ((failed++))
        fi
    done

    if [[ $failed -eq 0 ]]; then
        log_ok "All API endpoints accessible"
        return $EXIT_OK
    elif [[ $failed -lt ${#endpoints[@]} ]]; then
        log_warn "$failed of ${#endpoints[@]} endpoints failed"
        return $EXIT_WARNING
    else
        log_critical "All API endpoints failed"
        return $EXIT_CRITICAL
    fi
}

check_response_time() {
    log_info "Checking response time"

    local url="https://${DOMAIN}/health"
    local response_time

    if response_time=$(curl -s -o /dev/null -w "%{time_total}" --max-time "$TIMEOUT" "$url" 2>/dev/null); then
        local time_ms
        time_ms=$(echo "$response_time * 1000" | bc -l | cut -d. -f1)

        if [[ $time_ms -lt 1000 ]]; then
            log_ok "Response time: ${time_ms}ms"
            return $EXIT_OK
        elif [[ $time_ms -lt 5000 ]]; then
            log_warn "Response time: ${time_ms}ms (slow)"
            return $EXIT_WARNING
        else
            log_critical "Response time: ${time_ms}ms (too slow)"
            return $EXIT_CRITICAL
        fi
    else
        log_critical "Response time check failed"
        return $EXIT_CRITICAL
    fi
}

check_docker_services() {
    log_info "Checking Docker services"

    if ! command -v docker >/dev/null 2>&1; then
        log_warn "Docker not available for service check"
        return $EXIT_WARNING
    fi

    local compose_file="docker-compose.prod.yml"
    if [[ ! -f "$compose_file" ]]; then
        log_warn "Docker Compose file not found"
        return $EXIT_WARNING
    fi

    local services=("nginx" "backend")
    local failed=0

    for service in "${services[@]}"; do
        if docker compose -f "$compose_file" ps "$service" | grep -q "Up" 2>/dev/null; then
            log_info "Service $service: Running"
        else
            log_warn "Service $service: Not running"
            ((failed++))
        fi
    done

    if [[ $failed -eq 0 ]]; then
        log_ok "All core services running"
        return $EXIT_OK
    else
        log_warn "$failed of ${#services[@]} services not running"
        return $EXIT_WARNING
    fi
}

run_all_checks() {
    local overall_status=$EXIT_OK
    local checks=()

    echo "HRAS Health Check Report"
    echo "========================"
    echo "Domain: $DOMAIN"
    echo "Timestamp: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
    echo ""

    # Run all checks
    check_backend_health
    local backend_status=$?
    checks+=("Backend Health:$backend_status")

    check_ssl_certificate
    local ssl_status=$?
    checks+=("SSL Certificate:$ssl_status")

    check_api_endpoints
    local api_status=$?
    checks+=("API Endpoints:$api_status")

    check_response_time
    local response_status=$?
    checks+=("Response Time:$response_status")

    check_docker_services
    local docker_status=$?
    checks+=("Docker Services:$docker_status")

    # Determine overall status
    for check in "${checks[@]}"; do
        local status=${check#*:}
        if [[ $status -eq $EXIT_CRITICAL ]]; then
            overall_status=$EXIT_CRITICAL
        elif [[ $status -eq $EXIT_WARNING && $overall_status -ne $EXIT_CRITICAL ]]; then
            overall_status=$EXIT_WARNING
        fi
    done

    echo ""
    echo "Overall Status:"
    case $overall_status in
        $EXIT_OK)
            log_ok "All systems operational"
            ;;
        $EXIT_WARNING)
            log_warn "Some issues detected"
            ;;
        $EXIT_CRITICAL)
            log_critical "Critical issues detected"
            ;;
    esac

    return $overall_status
}

show_help() {
    cat << EOF
HRAS Health Check Script

Usage: $0 [OPTIONS] [CHECK]

Options:
    -d, --domain DOMAIN     Domain to check (default: localhost)
    -t, --token TOKEN       Health check token
    -v, --verbose           Verbose output
    -h, --help             Show this help

Checks:
    all                    Run all health checks (default)
    backend               Backend health only
    ssl                   SSL certificate only
    api                   API endpoints only
    response              Response time only
    docker                Docker services only

Examples:
    $0 --domain api.hras.com --token secret123
    $0 --verbose backend
    $0 ssl

Exit Codes:
    0 - OK
    1 - Warning
    2 - Critical
    3 - Unknown

EOF
}

main() {
    local check_type="all"

    while [[ $# -gt 0 ]]; do
        case $1 in
            -d|--domain)
                DOMAIN="$2"
                shift 2
                ;;
            -t|--token)
                HEALTH_TOKEN="$2"
                shift 2
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            all|backend|ssl|api|response|docker)
                check_type="$1"
                shift
                ;;
            *)
                echo "Unknown option: $1"
                show_help
                exit $EXIT_UNKNOWN
                ;;
        esac
    done

    case $check_type in
        all)
            run_all_checks
            ;;
        backend)
            check_backend_health
            ;;
        ssl)
            check_ssl_certificate
            ;;
        api)
            check_api_endpoints
            ;;
        response)
            check_response_time
            ;;
        docker)
            check_docker_services
            ;;
        *)
            echo "Unknown check type: $check_type"
            show_help
            exit $EXIT_UNKNOWN
            ;;
    esac
}

main "$@"
