#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../config/deployment.env"

log_info() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] $1" | tee -a rollback.log
}

log_error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] $1" | tee -a rollback.log >&2
}

log_success() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [SUCCESS] $1" | tee -a rollback.log
}

list_available_backups() {
    log_info "Available backups:"

    local backups=()

    if [[ -d "/opt/hras/backups" ]]; then
        while IFS= read -r backup_file; do
            if [[ -n "$backup_file" ]]; then
                local backup_name
                backup_name=$(basename "$backup_file" .tar.gz)
                local backup_size
                backup_size=$(du -h "$backup_file" | cut -f1)
                local backup_date
                backup_date=$(stat -c %y "$backup_file" | cut -d' ' -f1)

                backups+=("$backup_name")
                echo "  $backup_name (${backup_size}, created: ${backup_date})"
            fi
        done < <(find /opt/hras/backups -name "*.tar.gz" -type f | sort -r)
    fi

    if [[ -n "${S3_BACKUP_BUCKET:-}" ]]; then
        log_info "S3 backups available:"
        aws s3 ls "s3://${S3_BACKUP_BUCKET}/${S3_BACKUP_PREFIX}/" --recursive | \
        grep "\.tar\.gz$" | sort -r | head -10 | \
        while read -r line; do
            local s3_path
            s3_path=$(echo "$line" | awk '{print $4}')
            local s3_size
            s3_size=$(echo "$line" | awk '{print $3}')
            local s3_date
            s3_date=$(echo "$line" | awk '{print $1}')
            echo "  S3: $(basename "$s3_path" .tar.gz) (${s3_size} bytes, ${s3_date})"
        done
    fi

    if [[ ${#backups[@]} -eq 0 ]]; then
        log_error "No local backups found"
        return 1
    fi

    echo "${backups[0]}"
}

download_s3_backup() {
    local backup_id=$1

    log_info "Downloading backup from S3: $backup_id"

    local s3_path="s3://${S3_BACKUP_BUCKET}/${S3_BACKUP_PREFIX}/${backup_id}.tar.gz"
    local local_path="/opt/hras/backups/${backup_id}.tar.gz"

    if aws s3 cp "$s3_path" "$local_path"; then
        log_success "Backup downloaded from S3"
        return 0
    else
        log_error "Failed to download backup from S3"
        return 1
    fi
}

validate_backup() {
    local backup_file=$1

    log_info "Validating backup: $backup_file"

    if [[ ! -f "$backup_file" ]]; then
        log_error "Backup file not found: $backup_file"
        return 1
    fi

    if ! tar -tzf "$backup_file" >/dev/null 2>&1; then
        log_error "Backup file is corrupted"
        return 1
    fi

    local temp_dir
    temp_dir=$(mktemp -d)

    if tar -xzf "$backup_file" -C "$temp_dir" 2>/dev/null; then
        local manifest_file="${temp_dir}/*/manifest.json"
        if [[ -f $manifest_file ]]; then
            local components
            components=$(jq -r '.components | to_entries[] | select(.value == true) | .key' "$manifest_file" 2>/dev/null)
            log_info "Backup contains: $(echo "$components" | tr '\n' ' ')"
        fi
        rm -rf "$temp_dir"
        log_success "Backup validation passed"
        return 0
    else
        rm -rf "$temp_dir"
        log_error "Failed to extract backup for validation"
        return 1
    fi
}

create_rollback_backup() {
    log_info "Creating rollback backup of current state..."

    local rollback_backup_dir="/opt/hras/backups/rollback_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$rollback_backup_dir"

    if [[ -d "/opt/hras/app" ]]; then
        tar -czf "${rollback_backup_dir}/current_app.tar.gz" -C /opt/hras app/
    fi

    if [[ "${USE_POSTGRES:-false}" == "true" ]]; then
        cd /opt/hras/app
        if docker-compose -f docker-compose.prod.yml ps -q postgres >/dev/null 2>&1; then
            docker-compose -f docker-compose.prod.yml exec -T postgres pg_dump \
                -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" | \
                gzip > "${rollback_backup_dir}/current_database.sql.gz"
        fi
    fi

    if [[ -d "/opt/hras/data/chroma" ]]; then
        tar -czf "${rollback_backup_dir}/current_vectorstore.tar.gz" -C /opt/hras/data chroma/
    fi

    echo "$(date -Iseconds)" > "${rollback_backup_dir}/timestamp"

    log_success "Rollback backup created: $rollback_backup_dir"
}

stop_services() {
    log_info "Stopping HRAS services..."

    cd /opt/hras/app

    if docker-compose -f docker-compose.prod.yml ps -q >/dev/null 2>&1; then
        docker-compose -f docker-compose.prod.yml down
        log_success "Docker services stopped"
    fi

    if systemctl is-active --quiet hras; then
        sudo systemctl stop hras
        log_success "HRAS systemd service stopped"
    fi
}

restore_application() {
    local backup_dir=$1

    log_info "Restoring application files..."

    if [[ -f "${backup_dir}/application.tar.gz" ]]; then
        rm -rf /opt/hras/app/*
        tar -xzf "${backup_dir}/application.tar.gz" -C /opt/hras/
        chown -R $USER:$USER /opt/hras/app
        log_success "Application files restored"
    else
        log_error "Application backup not found in ${backup_dir}"
        return 1
    fi
}

restore_database() {
    local backup_dir=$1

    if [[ "${USE_POSTGRES:-false}" != "true" ]]; then
        log_info "PostgreSQL not enabled, skipping database restore"
        return 0
    fi

    log_info "Restoring database..."

    cd /opt/hras/app

    docker-compose -f docker-compose.prod.yml up -d postgres

    sleep 30

    if [[ -f "${backup_dir}/database.dump.gz" ]]; then
        log_info "Restoring from custom format dump..."
        gunzip -c "${backup_dir}/database.dump.gz" | \
        docker-compose -f docker-compose.prod.yml exec -T postgres pg_restore \
            -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" --clean --if-exists
    elif [[ -f "${backup_dir}/database.sql.gz" ]]; then
        log_info "Restoring from SQL dump..."
        docker-compose -f docker-compose.prod.yml exec -T postgres psql \
            -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" -c "DROP SCHEMA public CASCADE; CREATE SCHEMA public;"

        gunzip -c "${backup_dir}/database.sql.gz" | \
        docker-compose -f docker-compose.prod.yml exec -T postgres psql \
            -U "${POSTGRES_USER}" -d "${POSTGRES_DB}"
    else
        log_error "Database backup not found in ${backup_dir}"
        return 1
    fi

    log_success "Database restored"
}

restore_vector_store() {
    local backup_dir=$1

    log_info "Restoring vector store..."

    if [[ -f "${backup_dir}/vectorstore.tar.gz" ]]; then
        rm -rf /opt/hras/data/chroma
        tar -xzf "${backup_dir}/vectorstore.tar.gz" -C /opt/hras/data/
        chown -R $USER:$USER /opt/hras/data/chroma
        log_success "Vector store restored"
    else
        log_info "Vector store backup not found, will need to re-ingest data"
    fi
}

restore_configuration() {
    local backup_dir=$1

    log_info "Restoring configuration files..."

    if [[ -d "${backup_dir}/config" ]]; then
        local config_files=(
            "hras:/etc/nginx/sites-available/"
            "hras.service:/etc/systemd/system/"
            "hras-healthcheck.service:/etc/systemd/system/"
            "hras-healthcheck.timer:/etc/systemd/system/"
            "jail.local:/etc/fail2ban/"
            "hras:/etc/logrotate.d/"
        )

        for config_mapping in "${config_files[@]}"; do
            local source_file="${config_mapping%%:*}"
            local dest_dir="${config_mapping##*:}"

            if [[ -f "${backup_dir}/config/${source_file}" ]]; then
                sudo cp "${backup_dir}/config/${source_file}" "${dest_dir}"
                log_info "Restored: ${source_file}"
            fi
        done

        if [[ -f "${backup_dir}/ssl.tar.gz" ]]; then
            rm -rf /opt/hras/ssl/*
            tar -xzf "${backup_dir}/ssl.tar.gz" -C /opt/hras/
            log_info "SSL certificates restored"
        fi

        sudo systemctl daemon-reload
        log_success "Configuration files restored"
    else
        log_warning "Configuration backup not found"
    fi
}

start_services() {
    log_info "Starting HRAS services..."

    cd /opt/hras/app

    docker-compose -f docker-compose.prod.yml up -d

    sleep 30

    if systemctl is-enabled --quiet hras; then
        sudo systemctl start hras
    fi

    sudo systemctl reload nginx

    log_success "Services started"
}

verify_rollback() {
    log_info "Verifying rollback..."

    local health_check_url="https://${DOMAIN}/health"
    local max_attempts=30
    local attempt=0

    while [[ $attempt -lt $max_attempts ]]; do
        if curl -sSf --max-time 10 "$health_check_url" >/dev/null 2>&1; then
            log_success "Application is responding"

            if "${SCRIPT_DIR}/health-check.sh" >/dev/null 2>&1; then
                log_success "Health check passed"
                return 0
            else
                log_warning "Health check failed, but application is responding"
                return 0
            fi
        fi

        attempt=$((attempt + 1))
        log_info "Waiting for application to respond (attempt ${attempt}/${max_attempts})..."
        sleep 10
    done

    log_error "Application not responding after rollback"
    return 1
}

perform_rollback() {
    local backup_id=${1:-""}

    if [[ -z "$backup_id" ]]; then
        log_info "No backup ID specified, finding latest backup..."
        backup_id=$(list_available_backups | tail -n1)

        if [[ -z "$backup_id" ]]; then
            log_error "No backups available for rollback"
            exit 1
        fi
    fi

    log_info "Rolling back to backup: $backup_id"

    local backup_file="/opt/hras/backups/${backup_id}.tar.gz"

    if [[ ! -f "$backup_file" ]]; then
        if [[ -n "${S3_BACKUP_BUCKET:-}" ]]; then
            download_s3_backup "$backup_id" || exit 1
        else
            log_error "Backup file not found and S3 not configured"
            exit 1
        fi
    fi

    if ! validate_backup "$backup_file"; then
        log_error "Backup validation failed"
        exit 1
    fi

    create_rollback_backup

    local temp_dir
    temp_dir=$(mktemp -d)
    tar -xzf "$backup_file" -C "$temp_dir"

    local backup_dir
    backup_dir=$(find "$temp_dir" -maxdepth 1 -type d -name "20*" | head -n1)

    if [[ -z "$backup_dir" ]]; then
        log_error "Unable to find backup directory in extracted files"
        rm -rf "$temp_dir"
        exit 1
    fi

    stop_services
    restore_application "$backup_dir"
    restore_database "$backup_dir"
    restore_vector_store "$backup_dir"
    restore_configuration "$backup_dir"
    start_services

    if verify_rollback; then
        log_success "Rollback completed successfully!"

        echo "
===========================================
HRAS Rollback Complete
===========================================

Rolled back to: $backup_id
Application URL: https://${DOMAIN}
Health Check: https://${DOMAIN}/health

Rollback backup created in case you need to revert this operation.

Next Steps:
1. Verify application functionality
2. Check logs for any issues
3. Monitor system performance
"
    else
        log_error "Rollback verification failed"
        exit 1
    fi

    rm -rf "$temp_dir"
}

show_usage() {
    echo "Usage: $0 [backup_id]"
    echo ""
    echo "Rollback HRAS to a previous backup state"
    echo ""
    echo "Options:"
    echo "  backup_id    Specific backup to rollback to (optional, defaults to latest)"
    echo ""
    echo "Examples:"
    echo "  $0                    # Rollback to latest backup"
    echo "  $0 20241215_143022    # Rollback to specific backup"
    echo ""
}

main() {
    case "${1:-}" in
        -h|--help)
            show_usage
            exit 0
            ;;
        --list)
            list_available_backups
            exit 0
            ;;
        *)
            log_info "Starting HRAS rollback process..."
            perform_rollback "$1"
            ;;
    esac
}

main "$@"
