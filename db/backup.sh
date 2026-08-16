#!/bin/bash

set -euo pipefail

DB_NAME="appdb"
BACKUP_DIR="/data/backups"
RETENTION_DAYS=7

usage() {
    echo "Usage: $0"
    echo
    echo "Backup PostgreSQL database '$DB_NAME' to '$BACKUP_DIR'."
    echo "Backups older than $RETENTION_DAYS days are removed."
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
fi

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
FINAL_FILE="${BACKUP_DIR}/${DB_NAME}_${TIMESTAMP}.sql.gz"
TEMP_FILE="${BACKUP_DIR}/.${DB_NAME}_${TIMESTAMP}.tmp.sql.gz"

cleanup() {
    rm -f "$TEMP_FILE"
}

trap cleanup EXIT

trap 'echo "[ERROR] Backup failed at line $LINENO." >&2' ERR

mkdir -p "$BACKUP_DIR"

echo "[INFO] Starting PostgreSQL backup..."
echo "[INFO] Database: $DB_NAME"
echo "[INFO] Output: $FINAL_FILE"

sudo -u postgres pg_dump --clean --if-exists -d "$DB_NAME" | gzip > "$TEMP_FILE"

mv "$TEMP_FILE" "$FINAL_FILE"

echo "[INFO] Backup completed successfully."

find "$BACKUP_DIR" \
    -type f \
    -name "${DB_NAME}_*.sql.gz" \
    -mtime +"$RETENTION_DAYS" \
    -delete

echo "[INFO] Retention policy: ${RETENTION_DAYS} days"
echo "[INFO] Current backups:"
ls -lh "$BACKUP_DIR"
