#!/bin/bash

set -euo pipefail

BACKUP_TYPE=${1:-full}
RETENTION_DAYS=${RETENTION_DAYS:-30}
S3_BUCKET=${S3_BACKUP_BUCKET:-}
BACKUP_DIR="/opt/hras/backups"
DEPLOYMENT_DIR="/opt/hras"

echo "💾 Starting HRAS backup process..."
echo "  Type: $BACKUP_TYPE"
echo "  Retention: $RETENTION_DAYS days"
echo "  S3 Bucket: ${S3_BUCKET:-none}"

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="hras_${BACKUP_TYPE}_${TIMESTAMP}"
LOCAL_BACKUP_PATH="$BACKUP_DIR/$BACKUP_NAME"

mkdir -p "$LOCAL_BACKUP_PATH"
cd "$DEPLOYMENT_DIR"

echo "📋 Creating backup manifest..."
cat > "$LOCAL_BACKUP_PATH/backup_info.json" << EOF
{
  "backup_name": "$BACKUP_NAME",
  "backup_type": "$BACKUP_TYPE",
  "timestamp": "$TIMESTAMP",
  "hostname": "$(hostname)",
  "version": "$(git -C /opt/hras rev-parse HEAD 2>/dev/null || echo 'unknown')"
}
EOF

case $BACKUP_TYPE in
  full|database)
    echo "🗄️ Backing up PostgreSQL database..."
    POSTGRES_PASSWORD=$(grep POSTGRES_PASSWORD .env | cut -d= -f2)
    POSTGRES_USER=$(grep POSTGRES_USER .env | cut -d= -f2)
    POSTGRES_DB=$(grep POSTGRES_DB .env | cut -d= -f2)

    docker compose exec -T postgres pg_dump \
      -U "$POSTGRES_USER" \
      -d "$POSTGRES_DB" \
      --clean --create --if-exists \
      > "$LOCAL_BACKUP_PATH/database.sql"

    echo "✅ Database backup completed"
    ;;
esac

case $BACKUP_TYPE in
  full|data)
    echo "📂 Backing up application data..."

    if docker volume ls | grep -q hras_app_data; then
      docker run --rm \
        -v hras_app_data:/data \
        -v "$LOCAL_BACKUP_PATH":/backup \
        alpine tar czf /backup/app_data.tar.gz -C /data .
    fi

    if docker volume ls | grep -q hras_postgres_data; then
      docker run --rm \
        -v hras_postgres_data:/data \
        -v "$LOCAL_BACKUP_PATH":/backup \
        alpine tar czf /backup/postgres_data.tar.gz -C /data .
    fi

    echo "✅ Data backup completed"
    ;;
esac

case $BACKUP_TYPE in
  full|config)
    echo "⚙️ Backing up configuration files..."

    cp docker-compose.yml "$LOCAL_BACKUP_PATH/"
    cp .env "$LOCAL_BACKUP_PATH/"

    if [[ -f "health-check.sh" ]]; then
      cp health-check.sh "$LOCAL_BACKUP_PATH/"
    fi

    if [[ -f "rollback.sh" ]]; then
      cp rollback.sh "$LOCAL_BACKUP_PATH/"
    fi

    if [[ -d "monitoring" ]]; then
      tar czf "$LOCAL_BACKUP_PATH/monitoring_config.tar.gz" monitoring/
    fi

    echo "✅ Configuration backup completed"
    ;;
esac

case $BACKUP_TYPE in
  full|logs)
    echo "📄 Backing up logs..."

    if [[ -d "logs" ]]; then
      tar czf "$LOCAL_BACKUP_PATH/application_logs.tar.gz" logs/
    fi

    if [[ -d "/var/log/hras" ]]; then
      sudo tar czf "$LOCAL_BACKUP_PATH/system_logs.tar.gz" -C /var/log hras/
    fi

    docker compose logs > "$LOCAL_BACKUP_PATH/docker_logs.txt" 2>&1 || true

    echo "✅ Logs backup completed"
    ;;
esac

echo "🔍 Generating backup verification..."
find "$LOCAL_BACKUP_PATH" -type f -exec sha256sum {} \; > "$LOCAL_BACKUP_PATH/checksums.txt"

BACKUP_SIZE=$(du -sh "$LOCAL_BACKUP_PATH" | cut -f1)
echo "📏 Backup size: $BACKUP_SIZE"

if [[ -n "$S3_BUCKET" ]] && command -v aws > /dev/null 2>&1; then
    echo "☁️ Uploading to S3..."

    tar czf "$LOCAL_BACKUP_PATH.tar.gz" -C "$BACKUP_DIR" "$BACKUP_NAME"

    aws s3 cp "$LOCAL_BACKUP_PATH.tar.gz" \
        "s3://$S3_BUCKET/hras-backups/$BACKUP_NAME.tar.gz" \
        --storage-class STANDARD_IA

    rm "$LOCAL_BACKUP_PATH.tar.gz"

    echo "✅ S3 upload completed"
fi

echo "🧹 Cleaning up old backups (keeping last $RETENTION_DAYS days)..."
find "$BACKUP_DIR" -type d -name "hras_*" -mtime +$RETENTION_DAYS -exec rm -rf {} \; 2>/dev/null || true

if [[ -n "$S3_BUCKET" ]] && command -v aws > /dev/null 2>&1; then
    CUTOFF_DATE=$(date -d "$RETENTION_DAYS days ago" +%Y-%m-%d)
    aws s3 ls "s3://$S3_BUCKET/hras-backups/" | \
        awk '$1 < "'$CUTOFF_DATE'" {print $4}' | \
        xargs -I {} aws s3 rm "s3://$S3_BUCKET/hras-backups/{}" || true
fi

echo "✅ Backup completed successfully!"
echo "📍 Local backup location: $LOCAL_BACKUP_PATH"
echo "📊 Backup contents:"
ls -la "$LOCAL_BACKUP_PATH"

echo "$(date): $BACKUP_TYPE backup completed - $LOCAL_BACKUP_PATH ($BACKUP_SIZE)" >> "$BACKUP_DIR/backup.log"
