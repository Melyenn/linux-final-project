#!/bin/bash

set -euo pipefail

# =========================================================
# Configuration
# =========================================================

DB_NAME="appdb"
BACKUP_DIR="/data/backups"

APP_TARGET="/home/duyen/linux-final-project/app/app.py"
STATUS_TARGET="/var/www/status.lab.local"

FLASK_SERVICE="flaskapp"
FLASK_HEALTH_URL="http://127.0.0.1:5000/products"

MAX_RETRIES=10
RETRY_DELAY=2


# =========================================================
# Functions
# =========================================================

usage() {
    echo "Usage: $0 <backup-file>"
    echo
    echo "Restore PostgreSQL database and web content"
    echo "from a capstone .tar.gz backup."
    echo
    echo "Example:"
    echo "  sudo $0 /data/backups/capstone_backup_20260824_024322.tar.gz"
}


cleanup() {
    if [[ -n "${TEMP_DIR:-}" && -d "$TEMP_DIR" ]]; then
        rm -rf "$TEMP_DIR"
    fi
}


on_error() {
    local exit_code=$?
    echo "[ERROR] Restore failed at line $1." >&2
    exit "$exit_code"
}


trap 'on_error $LINENO' ERR
trap cleanup EXIT


# =========================================================
# Validate execution
# =========================================================

if [[ $EUID -ne 0 ]]; then
    echo "[ERROR] This script must be run as root." >&2
    echo "Example:" >&2
    echo "  sudo $0 /data/backups/capstone_backup_YYYYMMDD_HHMMSS.tar.gz" >&2
    exit 1
fi


if [[ $# -eq 0 ]]; then
    usage >&2
    exit 1
fi


if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    usage
    exit 0
fi


BACKUP_FILE="$1"


# =========================================================
# Validate backup file
# =========================================================

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


# =========================================================
# Temporary directory
# =========================================================

TEMP_DIR=$(mktemp -d)


echo "[INFO] Starting restore..."
echo "[INFO] Backup: $BACKUP_FILE"


# =========================================================
# Extract backup
# =========================================================

echo "[INFO] Extracting backup archive..."

tar -xzf "$BACKUP_FILE" -C "$TEMP_DIR"


DB_DUMP="$TEMP_DIR/database/appdb.sql"
APP_BACKUP="$TEMP_DIR/web/app/app.py"
STATUS_BACKUP="$TEMP_DIR/web/status"


# =========================================================
# Validate archive contents
# =========================================================

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


# =========================================================
# Restore PostgreSQL
# =========================================================

echo "[INFO] Restoring PostgreSQL database..."
cat "$DB_DUMP" | runuser -u postgres -- psql \
            --set=ON_ERROR_STOP=1 \
                --dbname="$DB_NAME"

echo "[INFO] PostgreSQL database restored successfully."

# =========================================================
# Restore Flask application
# =========================================================

echo "[INFO] Restoring Flask application source..."

install \
    -o duyen \
    -g duyen \
    -m 644 \
    "$APP_BACKUP" \
    "$APP_TARGET"


# =========================================================
# Restore static web content
# =========================================================

echo "[INFO] Restoring static web content..."

mkdir -p "$STATUS_TARGET"

# Remove all old files, including hidden files
find "$STATUS_TARGET" \
    -mindepth 1 \
    -maxdepth 1 \
    -exec rm -rf -- {} +

cp -a "$STATUS_BACKUP/." "$STATUS_TARGET/"

chown -R root:root "$STATUS_TARGET"


# =========================================================
# Restart Flask
# =========================================================

echo "[INFO] Restarting Flask application..."

systemctl restart "$FLASK_SERVICE"


# =========================================================
# Wait for Flask
# =========================================================

echo "[INFO] Waiting for Flask application to become ready..."

FLASK_READY=false

for ((i=1; i<=MAX_RETRIES; i++)); do

    if curl \
        --fail \
        --silent \
        --show-error \
        "$FLASK_HEALTH_URL" \
        >/dev/null 2>&1
    then
        FLASK_READY=true
        break
    fi

    if (( i < MAX_RETRIES )); then
        echo "[WARN] Flask not ready yet. Retrying in ${RETRY_DELAY} seconds..."
        sleep "$RETRY_DELAY"
    fi

done


if [[ "$FLASK_READY" != true ]]; then
    echo "[ERROR] Flask application did not become ready." >&2
    echo "[ERROR] Service status:" >&2

    systemctl status "$FLASK_SERVICE" \
        --no-pager \
        --full >&2 || true

    exit 1
fi


echo "[INFO] Flask application is active and responding."


# =========================================================
# Final result
# =========================================================

echo "[INFO] Restore completed successfully."
