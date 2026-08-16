#!/bin/bash

set -euo pipefail

DB_NAME="appdb"
BACKUP_DIR="/data/backups"

usage() {
    echo "Usage: $0 <backup-file>"
    echo
    echo "Restore PostgreSQL database '$DB_NAME' from a .sql.gz backup."
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
    "$BACKUP_DIR"/*.sql.gz)
        ;;
    *)
        echo "[ERROR] Backup file must be inside $BACKUP_DIR and end with .sql.gz" >&2
        exit 1
        ;;
esac

echo "[INFO] Starting restore..."
echo "[INFO] Database: $DB_NAME"
echo "[INFO] Backup: $BACKUP_FILE"

sudo -u postgres bash -c \
    "set -o pipefail; gzip -dc '$BACKUP_FILE' | psql --dbname='$DB_NAME'"

echo "[INFO] Restore completed successfully."
