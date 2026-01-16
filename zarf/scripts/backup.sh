#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../docker/config/deployment.env"

BACKUP_TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/opt/hras/backups/${BACKUP_TIMESTAMP}"
S3_BACKUP_PATH="s3://${S3_BACKUP_BUCKET}/${S3_BACKUP_PREFIX}/${BACKUP_TIMESTAMP}"

log_info() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] $1" | tee -a backup.log
}

log_error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] $1" | tee -a backup.log >&2
}

log_success() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [SUCCESS] $1" | tee -a backup.log
}

create_backup_directory() {
    log_info "Creating backup directory: ${BACKUP_DIR}"
    mkdir -p "${BACKUP_DIR}"
    echo "${BACKUP_TIMESTAMP}" > "${BACKUP_DIR}/timestamp"
    echo "${APP_VERSION:-unknown}" > "${BACKUP_DIR}/version"
}

backup_application_files() {
    log_info "Backing up application files..."

    if [[ -d "/opt/hras/app" ]]; then
        tar -czf "${BACKUP_DIR}/application.tar.gz" \
            --exclude='.git' \
            --exclude='node_modules' \
            --exclude='__pycache__' \
            --exclude='.pytest_cache' \
            --exclude='.mypy_cache' \
            --exclude='.ruff_cache' \
            -C /opt/hras app/

        log_success "Application files backed up"
    else
        log_error "Application directory not found"
        return 1
    fi
}

backup_database() {
    if [[ "${USE_POSTGRES:-false}" != "true" ]]; then
        log_info "PostgreSQL not enabled, skipping database backup"
        return 0
    fi

    log_info "Backing up PostgreSQL database..."

    cd /opt/hras/app

    if docker-compose -f zarf/docker/compose/docker-compose.prod.yml ps -q postgres >/dev/null 2>&1; then
        docker-compose -f zarf/docker/compose/docker-compose.prod.yml exec -T postgres pg_dump \
            -U "${POSTGRES_USER}" \
            -d "${POSTGRES_DB}" \
            --verbose \
            --no-password \
            --format=custom \
            --compress=9 \
            | gzip > "${BACKUP_DIR}/database.dump.gz"

        docker-compose -f zarf/docker/compose/docker-compose.prod.yml exec -T postgres pg_dump \
            -U "${POSTGRES_USER}" \
            -d "${POSTGRES_DB}" \
            --schema-only \
            --no-password \
            > "${BACKUP_DIR}/schema.sql"

        log_success "Database backed up"
    else
        log_error "PostgreSQL container not running"
        return 1
    fi
}

backup_vector_store() {
    log_info "Backing up vector store..."

    if [[ -d "/opt/hras/data/chroma" ]]; then
        tar -czf "${BACKUP_DIR}/vectorstore.tar.gz" \
            -C /opt/hras/data chroma/

        log_success "Vector store backed up"
    else
        log_info "Vector store directory not found, skipping"
    fi
}

backup_configuration() {
    log_info "Backing up configuration files..."

    local config_files=(
        "/etc/nginx/sites-available/hras"
        "/etc/systemd/system/hras.service"
        "/etc/systemd/system/hras-healthcheck.service"
        "/etc/systemd/system/hras-healthcheck.timer"
        "/etc/fail2ban/jail.local"
        "/etc/logrotate.d/hras"
    )

    mkdir -p "${BACKUP_DIR}/config"

    for config_file in "${config_files[@]}"; do
        if [[ -f "$config_file" ]]; then
            cp "$config_file" "${BACKUP_DIR}/config/"
            log_info "Backed up: $config_file"
        fi
    done

    if [[ -d "/opt/hras/ssl" ]]; then
        tar -czf "${BACKUP_DIR}/ssl.tar.gz" \
            -C /opt/hras ssl/
        log_info "SSL certificates backed up"
    fi

    log_success "Configuration files backed up"
}

backup_logs() {
    log_info "Backing up recent logs..."

    mkdir -p "${BACKUP_DIR}/logs"

    local log_dirs=(
        "/opt/hras/logs/app"
        "/opt/hras/logs/nginx"
    )

    for log_dir in "${log_dirs[@]}"; do
        if [[ -d "$log_dir" ]]; then
            find "$log_dir" -name "*.log*" -mtime -7 -type f | \
                tar -czf "${BACKUP_DIR}/logs/$(basename "$log_dir").tar.gz" -T -
            log_info "Backed up recent logs from $log_dir"
        fi
    done

    log_success "Logs backed up"
}

create_backup_manifest() {
    log_info "Creating backup manifest..."

    local manifest_file="${BACKUP_DIR}/manifest.json"

    cat > "$manifest_file" << EOF
{
    "backup_id": "${BACKUP_TIMESTAMP}",
    "timestamp": "$(date -Iseconds)",
    "domain": "${DOMAIN}",
    "app_version": "${APP_VERSION:-unknown}",
    "components": {
        "application": $(if [[ -f "${BACKUP_DIR}/application.tar.gz" ]]; then echo "true"; else echo "false"; fi),
        "database": $(if [[ -f "${BACKUP_DIR}/database.dump.gz" ]]; then echo "true"; else echo "false"; fi),
        "vectorstore": $(if [[ -f "${BACKUP_DIR}/vectorstore.tar.gz" ]]; then echo "true"; else echo "false"; fi),
        "configuration": $(if [[ -d "${BACKUP_DIR}/config" ]]; then echo "true"; else echo "false"; fi),
        "ssl": $(if [[ -f "${BACKUP_DIR}/ssl.tar.gz" ]]; then echo "true"; else echo "false"; fi),
        "logs": $(if [[ -d "${BACKUP_DIR}/logs" ]]; then echo "true"; else echo "false"; fi)
    },
    "files": []
}
EOF

    find "${BACKUP_DIR}" -type f | while read -r file; do
        local relative_path="${file#$BACKUP_DIR/}"
        local file_size
        file_size=$(stat -c%s "$file")
        local file_hash
        file_hash=$(sha256sum "$file" | cut -d' ' -f1)

        jq --arg path "$relative_path" \
           --arg size "$file_size" \
           --arg hash "$file_hash" \
           '.files += [{"path": $path, "size": ($size | tonumber), "sha256": $hash}]' \
           "$manifest_file" > "${manifest_file}.tmp"

        mv "${manifest_file}.tmp" "$manifest_file"
    done

    log_success "Backup manifest created"
}

upload_to_s3() {
    if [[ -z "${S3_BACKUP_BUCKET:-}" ]]; then
        log_info "S3 backup not configured, skipping upload"
        return 0
    fi

    log_info "Uploading backup to S3..."

    if ! command -v aws >/dev/null 2>&1; then
        log_error "AWS CLI not installed, cannot upload to S3"
        return 1
    fi

    if aws s3 sync "${BACKUP_DIR}/" "${S3_BACKUP_PATH}/" --storage-class STANDARD_IA; then
        log_success "Backup uploaded to S3: ${S3_BACKUP_PATH}"

        echo "${S3_BACKUP_PATH}" > "${BACKUP_DIR}/s3_location"
    else
        log_error "Failed to upload backup to S3"
        return 1
    fi
}

compress_local_backup() {
    log_info "Compressing local backup..."

    local compressed_backup="/opt/hras/backups/${BACKUP_TIMESTAMP}.tar.gz"

    tar -czf "$compressed_backup" -C /opt/hras/backups "${BACKUP_TIMESTAMP}/"

    if [[ -f "$compressed_backup" ]]; then
        rm -rf "${BACKUP_DIR}"
        log_success "Local backup compressed: $compressed_backup"
    else
        log_error "Failed to compress local backup"
        return 1
    fi
}

cleanup_old_backups() {
    log_info "Cleaning up old local backups..."

    find /opt/hras/backups -name "*.tar.gz" -type f -mtime +${BACKUP_RETENTION_DAYS:-30} -delete
    find /opt/hras/backups -type d -empty -delete

    if [[ -n "${S3_BACKUP_BUCKET:-}" ]]; then
        log_info "Cleaning up old S3 backups..."

        local cutoff_date
        cutoff_date=$(date -d "${BACKUP_RETENTION_DAYS:-30} days ago" +%Y%m%d)

        aws s3 ls "s3://${S3_BACKUP_BUCKET}/${S3_BACKUP_PREFIX}/" | \
        while read -r line; do
            local backup_date
            backup_date=$(echo "$line" | awk '{print $2}' | cut -d'/' -f1 | cut -d'_' -f1)

            if [[ -n "$backup_date" ]] && [[ "$backup_date" < "$cutoff_date" ]]; then
                aws s3 rm "s3://${S3_BACKUP_BUCKET}/${S3_BACKUP_PREFIX}/${backup_date}_"* --recursive
                log_info "Deleted old S3 backup: $backup_date"
            fi
        done
    fi

    log_success "Old backups cleaned up"
}

verify_backup() {
    log_info "Verifying backup integrity..."

    local backup_file="/opt/hras/backups/${BACKUP_TIMESTAMP}.tar.gz"

    if [[ ! -f "$backup_file" ]]; then
        log_error "Backup file not found: $backup_file"
        return 1
    fi

    if tar -tzf "$backup_file" >/dev/null 2>&1; then
        local backup_size
        backup_size=$(du -h "$backup_file" | cut -f1)
        log_success "Backup verification passed, size: $backup_size"
        return 0
    else
        log_error "Backup verification failed - file is corrupted"
        return 1
    fi
}

send_backup_notification() {
    if [[ -z "${ALERTMANAGER_WEBHOOK_URL:-}" ]]; then
        return 0
    fi

    local status=$1
    local message=$2

    local payload
    payload=$(cat << EOF
{
    "receiver": "hras-backup",
    "status": "$status",
    "alerts": [
        {
            "status": "$status",
            "labels": {
                "alertname": "HRASBackup",
                "service": "hras-backup",
                "instance": "${DOMAIN}",
                "severity": "$status"
            },
            "annotations": {
                "summary": "$message",
                "description": "HRAS backup ${status} on ${DOMAIN}",
                "timestamp": "$(date -Iseconds)"
            }
        }
    ]
}
EOF
)

    curl -sSf -X POST \
        -H "Content-Type: application/json" \
        -d "$payload" \
        "${ALERTMANAGER_WEBHOOK_URL}" >/dev/null 2>&1 || true
}

main() {
    log_info "Starting HRAS backup process..."

    local backup_success=true

    create_backup_directory || backup_success=false

    if $backup_success; then
        backup_application_files || backup_success=false
        backup_database || backup_success=false
        backup_vector_store || backup_success=false
        backup_configuration || backup_success=false
        backup_logs || backup_success=false
        create_backup_manifest || backup_success=false
    fi

    if $backup_success; then
        upload_to_s3 || backup_success=false
        compress_local_backup || backup_success=false
    fi

    if $backup_success && verify_backup; then
        cleanup_old_backups

        local backup_size
        backup_size=$(du -h "/opt/hras/backups/${BACKUP_TIMESTAMP}.tar.gz" | cut -f1)

        log_success "Backup completed successfully!"

        send_backup_notification "resolved" "Backup completed successfully (${backup_size})"

        echo "
===========================================
HRAS Backup Complete
===========================================

Backup ID: ${BACKUP_TIMESTAMP}
Local Location: /opt/hras/backups/${BACKUP_TIMESTAMP}.tar.gz
$(if [[ -n "${S3_BACKUP_BUCKET:-}" ]]; then echo "S3 Location: ${S3_BACKUP_PATH}"; fi)
Size: ${backup_size}

Components Backed Up:
- Application files
$(if [[ "${USE_POSTGRES:-false}" == "true" ]]; then echo "- Database"; fi)
- Vector store (if exists)
- Configuration files
- SSL certificates
- Recent logs (last 7 days)

Retention: ${BACKUP_RETENTION_DAYS:-30} days
"
        exit 0
    else
        log_error "Backup failed!"
        send_backup_notification "firing" "Backup failed - check logs for details"
        exit 1
    fi
}

main "$@"
