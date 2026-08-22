#!/bin/bash

set -euo pipefail

DB_NAME="appdb"
BACKUP_DIR="/data/backups"

APP_TARGET="/home/duyen/linux-final-project/app/app.py"
STATUS_TARGET="/var/www/status.lab.local"

usage() {
    echo "Usage: $0 <backup-file>"
    echo
    echo "Restore PostgreSQL database and web content from a capstone .tar.gz backup."
    echo
    echo "Example:"
    echo "  $0 /data/backups/capstone_backup_20260820_141748.tar.gz"
}

trap 'echo "[ERROR] Restore failed at line $LINENO." >&2' ERR

if [[ $# -eq 0 ]]; then
    usage >&2
    exit 1
fi

if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    usage
    exit 0
fi

BACKUP_FILE="$1"

if [[ ! -f "$BACKUP_FILE" ]]; then
    echo "[ERROR] Backup file not found: $BACKUP_FILE" >&2
    exit 1
fi

case "$BACKUP_FILE" in
    "$BACKUP_DIR"/capstone_backup_*.tar.gz)
        ;;
    *)
        echo "[ERROR] Backup file must be a capstone_backup_*.tar.gz file inside $BACKUP_DIR" >&2
        exit 1
        ;;
esac

TEMP_DIR=$(mktemp -d)

cleanup() {
    rm -rf "$TEMP_DIR"
}

trap cleanup EXIT

echo "[INFO] Starting restore..."
echo "[INFO] Backup: $BACKUP_FILE"

echo "[INFO] Extracting backup archive..."
tar -xzf "$BACKUP_FILE" -C "$TEMP_DIR"

DB_DUMP="$TEMP_DIR/database/appdb.sql"
APP_BACKUP="$TEMP_DIR/web/app/app.py"
STATUS_BACKUP="$TEMP_DIR/web/status"

if [[ ! -f "$DB_DUMP" ]]; then
    echo "[ERROR] Database dump not found in backup." >&2
    exit 1
fi

if [[ ! -f "$APP_BACKUP" ]]; then
    echo "[ERROR] Application backup not found in archive." >&2
    exit 1
fi

if [[ ! -d "$STATUS_BACKUP" ]]; then
    echo "[ERROR] Static site backup not found in archive." >&2
    exit 1
fi

echo "[INFO] Restoring PostgreSQL database..."
(
    cd /tmp
    sudo -u postgres psql \
        --dbname="$DB_NAME" \
        < "$DB_DUMP"
)
echo "[INFO] Restoring Flask application source..."
install -o duyen -g duyen -m 644 \
    "$APP_BACKUP" \
    "$APP_TARGET"

echo "[INFO] Restoring static web content..."
rm -rf "${STATUS_TARGET:?}/"*
cp -a "$STATUS_BACKUP/." "$STATUS_TARGET/"

chown -R root:root "$STATUS_TARGET"

echo "[INFO] Restarting Flask application..."
systemctl restart flaskapp.service

if ! systemctl is-active --quiet flaskapp.service; then
    echo "[ERROR] flaskapp.service failed after restore." >&2
    exit 1
fi

echo "[INFO] Waiting for Flask application to become ready..."

for attempt in 1 2 3 4 5; do
    if curl -fsS -m 5 http://127.0.0.1:5000/products >/dev/null; then
        echo "[INFO] Flask application is active and responding."
        break
    fi

    if [[ "$attempt" -eq 5 ]]; then
        echo "[ERROR] Flask health check failed after 5 attempts." >&2
        exit 1
    fi

    echo "[WARN] Flask not ready yet. Retrying in 2 seconds..."
    sleep 2
done
echo "[INFO] Restore completed successfully."
