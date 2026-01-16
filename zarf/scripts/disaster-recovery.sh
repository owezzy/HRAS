#!/bin/bash

set -euo pipefail

BACKUP_PATH=${1:-}
S3_BUCKET=${S3_BACKUP_BUCKET:-}
RESTORE_TYPE=${2:-full}

if [[ -z "$BACKUP_PATH" ]]; then
    echo "❌ Usage: $0 <backup_path_or_s3_key> [restore_type]"
    echo ""
    echo "Examples:"
    echo "  $0 /opt/hras/backups/hras_full_20240115_120000"
    echo "  $0 s3://bucket/hras-backups/backup.tar.gz"
    echo "  $0 hras_full_20240115_120000 database"
    exit 1
fi

DEPLOYMENT_DIR="/opt/hras"
BACKUP_DIR="/opt/hras/backups"
TEMP_RESTORE_DIR="/tmp/hras-restore-$$"

mkdir -p "$TEMP_RESTORE_DIR"

echo "🔄 Starting HRAS disaster recovery..."
echo "  Backup: $BACKUP_PATH"
echo "  Type: $RESTORE_TYPE"

if [[ "$BACKUP_PATH" =~ ^s3:// ]]; then
    echo "☁️ Downloading backup from S3..."
    aws s3 cp "$BACKUP_PATH" "$TEMP_RESTORE_DIR/backup.tar.gz"
    tar xzf "$TEMP_RESTORE_DIR/backup.tar.gz" -C "$TEMP_RESTORE_DIR"
    BACKUP_EXTRACT_DIR=$(find "$TEMP_RESTORE_DIR" -type d -name "hras_*" | head -1)
    BACKUP_PATH="$BACKUP_EXTRACT_DIR"
elif [[ "$BACKUP_PATH" =~ ^/ ]]; then
    if [[ ! -d "$BACKUP_PATH" ]]; then
        echo "❌ Backup directory not found: $BACKUP_PATH"
        exit 1
    fi
else
    BACKUP_PATH="$BACKUP_DIR/$BACKUP_PATH"
    if [[ ! -d "$BACKUP_PATH" ]]; then
        echo "❌ Backup directory not found: $BACKUP_PATH"
        exit 1
    fi
fi

echo "📋 Verifying backup integrity..."
if [[ -f "$BACKUP_PATH/checksums.txt" ]]; then
    cd "$BACKUP_PATH"
    if sha256sum -c checksums.txt --quiet; then
        echo "✅ Backup integrity verified"
    else
        echo "⚠️ Backup integrity check failed, proceeding anyway..."
    fi
    cd "$DEPLOYMENT_DIR"
else
    echo "⚠️ No checksum file found, skipping integrity check"
fi

if [[ -f "$BACKUP_PATH/backup_info.json" ]]; then
    echo "📊 Backup information:"
    cat "$BACKUP_PATH/backup_info.json" | jq .
fi

case $RESTORE_TYPE in
    full|services)
        echo "🛑 Stopping HRAS services..."
        docker compose down --timeout 30 || true
        ;;
esac

case $RESTORE_TYPE in
    full|database)
        if [[ -f "$BACKUP_PATH/database.sql" ]]; then
            echo "🗄️ Restoring PostgreSQL database..."

            docker compose up -d postgres
            echo "⏳ Waiting for PostgreSQL to be ready..."
            sleep 30

            POSTGRES_PASSWORD=$(grep POSTGRES_PASSWORD "$BACKUP_PATH/.env" | cut -d= -f2)
            POSTGRES_USER=$(grep POSTGRES_USER "$BACKUP_PATH/.env" | cut -d= -f2)
            POSTGRES_DB=$(grep POSTGRES_DB "$BACKUP_PATH/.env" | cut -d= -f2)

            docker compose exec -T postgres psql \
                -U "$POSTGRES_USER" \
                -d postgres \
                -c "DROP DATABASE IF EXISTS $POSTGRES_DB;"

            docker compose exec -T postgres psql \
                -U "$POSTGRES_USER" \
                -d postgres < "$BACKUP_PATH/database.sql"

            echo "✅ Database restore completed"
        else
            echo "⚠️ No database backup found, skipping database restore"
        fi
        ;;
esac

case $RESTORE_TYPE in
    full|data)
        echo "📂 Restoring application data..."

        if [[ -f "$BACKUP_PATH/app_data.tar.gz" ]]; then
            docker volume create hras_app_data || true
            docker run --rm \
                -v hras_app_data:/data \
                -v "$BACKUP_PATH":/backup \
                alpine sh -c "cd /data && tar xzf /backup/app_data.tar.gz"
            echo "✅ Application data restored"
        fi

        if [[ -f "$BACKUP_PATH/postgres_data.tar.gz" ]]; then
            docker compose down postgres || true
            docker volume create hras_postgres_data || true
            docker run --rm \
                -v hras_postgres_data:/data \
                -v "$BACKUP_PATH":/backup \
                alpine sh -c "cd /data && tar xzf /backup/postgres_data.tar.gz"
            echo "✅ PostgreSQL data restored"
        fi
        ;;
esac

case $RESTORE_TYPE in
    full|config)
        echo "⚙️ Restoring configuration files..."

        if [[ -f "$BACKUP_PATH/docker-compose.yml" ]]; then
            cp "$BACKUP_PATH/docker-compose.yml" "$DEPLOYMENT_DIR/"
        fi

        if [[ -f "$BACKUP_PATH/.env" ]]; then
            cp "$BACKUP_PATH/.env" "$DEPLOYMENT_DIR/"
        fi

        if [[ -f "$BACKUP_PATH/health-check.sh" ]]; then
            cp "$BACKUP_PATH/health-check.sh" "$DEPLOYMENT_DIR/"
            chmod +x "$DEPLOYMENT_DIR/health-check.sh"
        fi

        if [[ -f "$BACKUP_PATH/rollback.sh" ]]; then
            cp "$BACKUP_PATH/rollback.sh" "$DEPLOYMENT_DIR/"
            chmod +x "$DEPLOYMENT_DIR/rollback.sh"
        fi

        if [[ -f "$BACKUP_PATH/monitoring_config.tar.gz" ]]; then
            tar xzf "$BACKUP_PATH/monitoring_config.tar.gz" -C "$DEPLOYMENT_DIR/"
        fi

        echo "✅ Configuration restored"
        ;;
esac

case $RESTORE_TYPE in
    full|services)
        echo "🚀 Starting HRAS services..."
        docker compose up -d

        echo "⏳ Waiting for services to be healthy..."
        timeout 120 bash -c 'until docker compose exec backend python -c "import requests; requests.get(\"http://localhost:8000/health\")" > /dev/null 2>&1; do sleep 5; done'

        echo "🔍 Running post-restore health check..."
        if [[ -f "$DEPLOYMENT_DIR/health-check.sh" ]]; then
            "$DEPLOYMENT_DIR/health-check.sh"
        fi
        ;;
esac

echo "🧹 Cleaning up temporary files..."
rm -rf "$TEMP_RESTORE_DIR"

echo "✅ Disaster recovery completed successfully!"
echo ""
echo "📊 Restoration summary:"
echo "  Backup source: $BACKUP_PATH"
echo "  Restore type: $RESTORE_TYPE"
echo "  Completion time: $(date)"
echo ""
echo "🔍 Verification steps:"
echo "  1. Check service status: docker compose ps"
echo "  2. Test application: curl -f https://$(grep DOMAIN .env | cut -d= -f2)/health"
echo "  3. Review logs: docker compose logs"

echo "$(date): Disaster recovery completed - $BACKUP_PATH ($RESTORE_TYPE)" >> "$BACKUP_DIR/restore.log"
