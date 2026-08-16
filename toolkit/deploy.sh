#!/usr/bin/env bash

# ================================================================
# File        : toolkit/deploy.sh
# Description : Safe Application Deployment with Automated Rollback
# ================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
ENV_FILE="/etc/myapp/app.env"
ALERT_SCRIPT="${SCRIPT_DIR}/send_alert.sh"

# Exit code constants
readonly EXIT_SUCCESS=0
# readonly EXIT_GENERAL_ERROR=1
readonly EXIT_INVALID_USAGE=2
readonly EXIT_HEALTH_CHECK_FAILED=5

# System deployment paths matching interfaces.md
APP_DIR="/opt/myapp"
BACKUP_RELEASE_DIR="/var/backups/myapp/releases"
ROLLBACK_BACKUP_DIR="${BACKUP_RELEASE_DIR}/previous_release"
SERVICE_NAME="myapp.service"
HEALTH_CHECK_URL="http://127.0.0.1:5000/products"
SOURCE_DIR="${REPO_ROOT}/app"

# State flags
IS_DEPLOYING=false

# Load environment configuration if available
if [[ -f "$ENV_FILE" ]]; then
    # shellcheck source=/dev/null
    source "$ENV_FILE"
fi

# Function to execute rollback to previous release
rollback() {
    echo "[WARN] Deployment failed! Executing automatic rollback..." >&2

    if [[ -d "$ROLLBACK_BACKUP_DIR" && -n "$(ls -A "$ROLLBACK_BACKUP_DIR")" ]]; then
        echo "[INFO] Restoring previous application codebase from $ROLLBACK_BACKUP_DIR..."
        mkdir -p "$APP_DIR"
        rm -rf "${APP_DIR:?}"/*
        cp -r "${ROLLBACK_BACKUP_DIR}"/* "$APP_DIR/"
        
        echo "[INFO] Resetting file permissions..."
        chmod -R 755 "$APP_DIR"

        echo "[INFO] Restarting systemd service: $SERVICE_NAME..."
        systemctl restart "$SERVICE_NAME" || true
        systemctl reload nginx || true

        echo "[INFO] Rollback completed. System restored to previous working version."
    else
        echo "[CRITICAL] No rollback backup found at $ROLLBACK_BACKUP_DIR! System requires manual intervention." >&2
    fi

    if [[ -x "$ALERT_SCRIPT" ]]; then
        echo "[INFO] Triggering failure alert notification..."
        "$ALERT_SCRIPT" "DEPLOYMENT FAILED" "Application deployment failed on $(hostname). Automatic rollback was executed." || true
    fi
}

# Cleanup and error handling trap
cleanup() {
    local exit_code=$?
    if [[ "$exit_code" -ne 0 && "$IS_DEPLOYING" == "true" ]]; then
        echo "[ERROR] Deployment error occurred on line $1 with exit code $exit_code." >&2
        rollback
    fi
}
trap 'cleanup $LINENO' ERR

# Display usage help
show_help() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Safely deploy application code to ${APP_DIR} with automated rollback.

Options:
  -s, --source <dir>   Path to source app directory (default: ${SOURCE_DIR})
  -h, --help           Display this help message and exit

Examples:
  $(basename "$0")
  $(basename "$0") --source /tmp/new_app_code
EOF
}

# Main deployment routine
main() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -s|--source)
                SOURCE_DIR="$2"
                shift 2
                ;;
            -h|--help)
                show_help
                exit "$EXIT_SUCCESS"
                ;;
            *)
                echo "[ERROR] Unknown parameter: $1" >&2
                show_help
                exit "$EXIT_INVALID_USAGE"
                ;;
        esac
    done

    echo "[INFO] Starting application deployment on $(hostname)..."

    # Step 1: Validate source directory
    if [[ ! -d "$SOURCE_DIR" ]]; then
        echo "[ERROR] Source directory does not exist: $SOURCE_DIR" >&2
        exit "$EXIT_INVALID_USAGE"
    fi

    # Enable deployment tracking flag for rollback trap
    IS_DEPLOYING=true

    # Step 2: Create pre-deploy backup of current code
    echo "[INFO] Creating pre-deploy backup..."
    mkdir -p "$BACKUP_RELEASE_DIR"
    rm -rf "$ROLLBACK_BACKUP_DIR"
    mkdir -p "$ROLLBACK_BACKUP_DIR"

    if [[ -d "$APP_DIR" && -n "$(ls -A "$APP_DIR")" ]]; then
        cp -r "${APP_DIR}"/* "$ROLLBACK_BACKUP_DIR/"
        echo "[INFO] Current version backed up to $ROLLBACK_BACKUP_DIR"
    else
        echo "[INFO] Target directory $APP_DIR is empty. Skipping backup content."
    fi

    # Step 3: Copy new code to target directory
    echo "[INFO] Syncing new code to $APP_DIR..."
    mkdir -p "$APP_DIR"
    rm -rf "${APP_DIR:?}"/*
    cp -r "${SOURCE_DIR}"/* "$APP_DIR/"

    # Step 4: Set proper ownership and permissions
    echo "[INFO] Setting ownership and permissions..."
    chmod -R 755 "$APP_DIR"
    if [[ -f "${APP_DIR}/app.py" ]]; then
        chmod 644 "${APP_DIR}/app.py"
    fi

    # Step 5: Pre-flight Nginx configuration test
    echo "[INFO] Testing Nginx configuration syntax..."
    if command -v nginx &>/dev/null; then
        nginx -t
    else
        echo "[INFO] Nginx not installed locally. Skipping nginx -t."
    fi

    # Step 6: Reload services safely
    echo "[INFO] Reloading systemd service: $SERVICE_NAME..."
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        systemctl reload-or-restart "$SERVICE_NAME"
    else
        systemctl start "$SERVICE_NAME"
    fi

    if command -v nginx &>/dev/null && systemctl is-active --quiet nginx; then
        echo "[INFO] Reloading Nginx web server..."
        systemctl reload nginx
    fi

    # Step 7: Post-deployment Health Check
    echo "[INFO] Running post-deployment HTTP health check on $HEALTH_CHECK_URL..."
    local attempts=0
    local max_attempts=3
    local health_pass=false

    while [[ "$attempts" -lt "$max_attempts" ]]; do
        attempts=$(( attempts + 1 ))
        echo "[INFO] Health check attempt ${attempts}/${max_attempts}..."
        
        if curl -s -f -m 5 "$HEALTH_CHECK_URL" &>/dev/null; then
            health_pass=true
            break
        fi
        sleep 2
    done

    if [[ "$health_pass" == "false" ]]; then
        echo "[ERROR] Health check failed! Endpoint $HEALTH_CHECK_URL did not respond with 200 OK." >&2
        # Raising error will trigger ERR trap and execute rollback()
        return "$EXIT_HEALTH_CHECK_FAILED"
    fi

    # Disable deployment flag as deployment succeeded
    IS_DEPLOYING=false
    echo "[INFO] Deployment completed successfully! Application is live and healthy."
    exit "$EXIT_SUCCESS"
}

main "$@"