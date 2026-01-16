#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../config/deployment.env"

HEALTH_CHECK_URL="https://${DOMAIN}/health"
METRICS_URL="https://${DOMAIN}/metrics"

log_info() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] $1"
}

log_error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] $1" >&2
}

log_success() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [SUCCESS] $1"
}

check_service_health() {
    local service_name=$1
    local health_url=$2
    local timeout=${3:-30}

    log_info "Checking health of $service_name..."

    if timeout "$timeout" curl -sSf "$health_url" >/dev/null 2>&1; then
        log_success "$service_name is healthy"
        return 0
    else
        log_error "$service_name health check failed"
        return 1
    fi
}

check_ssl_certificate() {
    log_info "Checking SSL certificate..."

    local cert_info
    cert_info=$(echo | openssl s_client -servername "${DOMAIN}" -connect "${DOMAIN}:443" 2>/dev/null | openssl x509 -noout -dates 2>/dev/null)

    if [[ -n "$cert_info" ]]; then
        local not_after
        not_after=$(echo "$cert_info" | grep "notAfter" | cut -d= -f2)
        local expiry_date
        expiry_date=$(date -d "$not_after" +%s)
        local current_date
        current_date=$(date +%s)
        local days_until_expiry
        days_until_expiry=$(( (expiry_date - current_date) / 86400 ))

        if [[ $days_until_expiry -gt 30 ]]; then
            log_success "SSL certificate is valid for $days_until_expiry days"
            return 0
        elif [[ $days_until_expiry -gt 7 ]]; then
            log_info "SSL certificate expires in $days_until_expiry days (renewing soon)"
            return 0
        else
            log_error "SSL certificate expires in $days_until_expiry days (CRITICAL)"
            return 1
        fi
    else
        log_error "Unable to retrieve SSL certificate information"
        return 1
    fi
}

check_docker_services() {
    log_info "Checking Docker services..."

    cd /opt/hras/app

    local services
    services=$(docker-compose -f docker-compose.prod.yml config --services)
    local failed_services=()

    for service in $services; do
        if docker-compose -f docker-compose.prod.yml ps -q "$service" >/dev/null 2>&1; then
            local status
            status=$(docker-compose -f docker-compose.prod.yml ps "$service" --format "table {{.Status}}" | tail -n +2)
            if [[ "$status" =~ Up|running ]]; then
                log_success "Service $service is running"
            else
                log_error "Service $service is not running: $status"
                failed_services+=("$service")
            fi
        else
            log_error "Service $service not found"
            failed_services+=("$service")
        fi
    done

    if [[ ${#failed_services[@]} -eq 0 ]]; then
        return 0
    else
        log_error "Failed services: ${failed_services[*]}"
        return 1
    fi
}

check_system_resources() {
    log_info "Checking system resources..."

    local cpu_usage
    cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | sed 's/%us,//')

    local memory_usage
    memory_usage=$(free | grep Mem | awk '{printf "%.1f", ($3/$2) * 100.0}')

    local disk_usage
    disk_usage=$(df /opt/hras | awk 'NR==2 {print $5}' | sed 's/%//')

    log_info "CPU usage: ${cpu_usage}%"
    log_info "Memory usage: ${memory_usage}%"
    log_info "Disk usage: ${disk_usage}%"

    local issues=0

    if (( $(echo "$memory_usage > 80" | bc -l) )); then
        log_error "High memory usage: ${memory_usage}%"
        issues=$((issues + 1))
    fi

    if [[ $disk_usage -gt 80 ]]; then
        log_error "High disk usage: ${disk_usage}%"
        issues=$((issues + 1))
    fi

    if [[ $issues -eq 0 ]]; then
        log_success "System resources are within normal limits"
        return 0
    else
        return 1
    fi
}

check_database_connectivity() {
    if [[ "${USE_POSTGRES:-false}" != "true" ]]; then
        log_info "PostgreSQL not enabled, skipping database check"
        return 0
    fi

    log_info "Checking database connectivity..."

    cd /opt/hras/app

    if docker-compose -f docker-compose.prod.yml exec -T postgres pg_isready -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" >/dev/null 2>&1; then
        log_success "Database is accessible"

        local connection_count
        connection_count=$(docker-compose -f docker-compose.prod.yml exec -T postgres psql -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" -t -c "SELECT count(*) FROM pg_stat_activity;" | tr -d ' ')

        log_info "Active database connections: $connection_count"

        if [[ $connection_count -lt 100 ]]; then
            return 0
        else
            log_error "High number of database connections: $connection_count"
            return 1
        fi
    else
        log_error "Database connectivity check failed"
        return 1
    fi
}

check_vector_store() {
    log_info "Checking vector store..."

    local stats_response
    if stats_response=$(curl -sSf "${HEALTH_CHECK_URL%/health}/api/v1/admin/stats" 2>/dev/null); then
        local document_count
        document_count=$(echo "$stats_response" | jq -r '.document_count // 0')

        if [[ $document_count -gt 0 ]]; then
            log_success "Vector store contains $document_count documents"
            return 0
        else
            log_error "Vector store is empty"
            return 1
        fi
    else
        log_error "Unable to retrieve vector store statistics"
        return 1
    fi
}

check_log_files() {
    log_info "Checking log files..."

    local log_dirs=(
        "/opt/hras/logs/app"
        "/opt/hras/logs/nginx"
    )

    local issues=0

    for log_dir in "${log_dirs[@]}"; do
        if [[ -d "$log_dir" ]]; then
            local log_size
            log_size=$(du -sh "$log_dir" | cut -f1)
            log_info "Log directory $log_dir size: $log_size"

            local large_files
            large_files=$(find "$log_dir" -type f -size +100M 2>/dev/null | wc -l)
            if [[ $large_files -gt 0 ]]; then
                log_error "Found $large_files log files larger than 100MB in $log_dir"
                issues=$((issues + 1))
            fi
        else
            log_error "Log directory $log_dir not found"
            issues=$((issues + 1))
        fi
    done

    if [[ $issues -eq 0 ]]; then
        log_success "Log files are within normal limits"
        return 0
    else
        return 1
    fi
}

check_network_connectivity() {
    log_info "Checking network connectivity..."

    local external_hosts=(
        "8.8.8.8"
        "1.1.1.1"
        "github.com"
    )

    for host in "${external_hosts[@]}"; do
        if ping -c 1 -W 5 "$host" >/dev/null 2>&1; then
            log_success "Network connectivity to $host: OK"
        else
            log_error "Network connectivity to $host: FAILED"
            return 1
        fi
    done

    return 0
}

check_security_status() {
    log_info "Checking security status..."

    local issues=0

    if ! sudo ufw status | grep -q "Status: active"; then
        log_error "UFW firewall is not active"
        issues=$((issues + 1))
    else
        log_success "UFW firewall is active"
    fi

    if ! systemctl is-active --quiet fail2ban; then
        log_error "Fail2ban is not running"
        issues=$((issues + 1))
    else
        log_success "Fail2ban is running"
    fi

    local failed_login_attempts
    failed_login_attempts=$(sudo journalctl -u ssh --since "24 hours ago" | grep "Failed password" | wc -l)
    log_info "Failed SSH login attempts (last 24h): $failed_login_attempts"

    if [[ $failed_login_attempts -gt 100 ]]; then
        log_error "High number of failed SSH login attempts: $failed_login_attempts"
        issues=$((issues + 1))
    fi

    if [[ $issues -eq 0 ]]; then
        log_success "Security status is good"
        return 0
    else
        return 1
    fi
}

generate_health_report() {
    local timestamp
    timestamp=$(date -Iseconds)
    local report_file="/opt/hras/logs/app/health-report-${timestamp}.json"

    log_info "Generating detailed health report..."

    local health_data='{
        "timestamp": "'$timestamp'",
        "domain": "'${DOMAIN}'",
        "version": "'${APP_VERSION:-unknown}'",
        "checks": {}
    }'

    local checks=(
        "service_health"
        "ssl_certificate"
        "docker_services"
        "system_resources"
        "database_connectivity"
        "vector_store"
        "log_files"
        "network_connectivity"
        "security_status"
    )

    for check in "${checks[@]}"; do
        local result="false"
        if "check_${check}" >/dev/null 2>&1; then
            result="true"
        fi
        health_data=$(echo "$health_data" | jq ".checks.${check} = $result")
    done

    echo "$health_data" > "$report_file"
    log_success "Health report saved to $report_file"
}

main() {
    log_info "Starting HRAS health check..."

    local failed_checks=0
    local total_checks=9

    local checks=(
        "check_service_health HRAS $HEALTH_CHECK_URL"
        "check_ssl_certificate"
        "check_docker_services"
        "check_system_resources"
        "check_database_connectivity"
        "check_vector_store"
        "check_log_files"
        "check_network_connectivity"
        "check_security_status"
    )

    for check_cmd in "${checks[@]}"; do
        if ! eval "$check_cmd"; then
            failed_checks=$((failed_checks + 1))
        fi
    done

    generate_health_report

    local health_score
    health_score=$(( (total_checks - failed_checks) * 100 / total_checks ))

    echo "
===========================================
HRAS Health Check Summary
===========================================
Total Checks: $total_checks
Passed: $((total_checks - failed_checks))
Failed: $failed_checks
Health Score: ${health_score}%

Status: $(if [[ $failed_checks -eq 0 ]]; then echo "HEALTHY"; elif [[ $health_score -gt 70 ]]; then echo "WARNING"; else echo "CRITICAL"; fi)
"

    if [[ $failed_checks -eq 0 ]]; then
        log_success "All health checks passed"
        exit 0
    elif [[ $health_score -gt 70 ]]; then
        log_error "$failed_checks checks failed, but system is still operational"
        exit 1
    else
        log_error "$failed_checks checks failed, system may be in critical state"
        exit 2
    fi
}

main "$@"
