#!/bin/bash

set -euo pipefail

DB_NAME="appdb"
BACKUP_DIR="/data/backups"
RETENTION_DAYS=7

APP_SOURCE="/opt/myapp/app.py"
STATUS_SOURCE="/var/www/status.lab.local"

REMOTE_USER="phat"
REMOTE_HOST="172.31.2.78"
REMOTE_DIR="/backup"
SSH_KEY="/home/phat/.ssh/backup_ed25519"

usage() {
    echo "Usage: $0"
    echo
    echo "Backup PostgreSQL database and web content."
    echo "Output directory: $BACKUP_DIR"
    echo "Retention: $RETENTION_DAYS days"
    echo "Remote backup: ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_DIR}"
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
fi

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_NAME="capstone_backup_${TIMESTAMP}.tar.gz"
FINAL_FILE="${BACKUP_DIR}/${BACKUP_NAME}"
TEMP_DIR=$(mktemp -d)
TEMP_ARCHIVE="${BACKUP_DIR}/.${BACKUP_NAME}.tmp"

cleanup() {
    rm -rf "$TEMP_DIR"
    rm -f "$TEMP_ARCHIVE"
}

trap cleanup EXIT
trap 'echo "[ERROR] Backup failed at line $LINENO." >&2' ERR

mkdir -p "$BACKUP_DIR"

echo "[INFO] Starting backup..."
echo "[INFO] Database: $DB_NAME"
echo "[INFO] Application source: $APP_SOURCE"
echo "[INFO] Static site: $STATUS_SOURCE"
echo "[INFO] Output: $FINAL_FILE"

mkdir -p "$TEMP_DIR/database"
mkdir -p "$TEMP_DIR/web/app"
mkdir -p "$TEMP_DIR/web/status"

echo "[INFO] Dumping PostgreSQL database..."
sudo -u postgres pg_dump \
    --clean \
    --if-exists \
    -d "$DB_NAME" \
    | tee "$TEMP_DIR/database/appdb.sql" > /dev/null

echo "[INFO] Copying web content..."
cp "$APP_SOURCE" "$TEMP_DIR/web/app/app.py"
cp -a "$STATUS_SOURCE/." "$TEMP_DIR/web/status/"

echo "[INFO] Creating compressed archive..."
tar -czf "$TEMP_ARCHIVE" -C "$TEMP_DIR" .

mv "$TEMP_ARCHIVE" "$FINAL_FILE"

chown phat:postgres "$FINAL_FILE"
chmod 640 "$FINAL_FILE"

echo "[INFO] Local backup completed successfully."

echo "[INFO] Applying retention policy..."
find "$BACKUP_DIR" \
    -type f \
    -name "capstone_backup_*.tar.gz" \
    -mtime +"$RETENTION_DAYS" \
    -delete

echo "[INFO] Rsync backup to remote server..."
rsync -avz \
    -e "ssh -i $SSH_KEY -o BatchMode=yes" \
    "$FINAL_FILE" \
    "${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_DIR}/"

echo "[INFO] Remote backup completed successfully."

echo "[INFO] Backup finished."
echo "[INFO] File: $FINAL_FILE"
