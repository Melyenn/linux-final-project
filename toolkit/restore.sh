#!/usr/bin/env bash
set -euo pipefail

if [[ $# -eq 0 ]]; then
    echo "[INFO] Available backups:"
    ls -1t /data/backups/capstone_backup_*.tar.gz 2>/dev/null | head -10
    echo

    read -r -p "Enter backup file path: " BACKUP_FILE
else
    BACKUP_FILE="$1"
fi

exec /home/phat/db/restore.sh "$BACKUP_FILE"
