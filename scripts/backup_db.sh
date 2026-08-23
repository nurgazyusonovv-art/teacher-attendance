#!/usr/bin/env bash
set -e

BACKUP_DIR="./backups"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_FILE="${BACKUP_DIR}/teacher_db_backup_${TIMESTAMP}.sql.gz"

mkdir -p "$BACKUP_DIR"

echo "=== Starting database backup ==="
docker compose exec -T postgres pg_dump -U teacher_user -d teacher_attendance_db | gzip > "$BACKUP_FILE"

echo "=== Backup completed: ${BACKUP_FILE} ==="
# Retain backups for 14 days
find "$BACKUP_DIR" -type f -name "*.sql.gz" -mtime +14 -exec rm {} \;
echo "=== Old backups cleaned up ==="
