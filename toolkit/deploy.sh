#!/usr/bin/env bash

# ================================================================
# File        : toolkit/deploy.sh
# Description : Safe Application Deployment with Automated Rollback
# Author      : Nguyen Nam Viet - Capstone Linux Team
# ================================================================

set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ALERT_SCRIPT="${SCRIPT_DIR}/send_alert.sh"

readonly EXIT_SUCCESS=0
readonly EXIT_INVALID_USAGE=2
readonly EXIT_HEALTH_CHECK_FAILED=5

APP_DIR="/home/duyen/linux-final-project/app"
APP_OWNER="duyen"
APP_GROUP="duyen"

PYTHON_BIN="/home/duyen/linux-final-project/.venv/bin/python"
SERVICE_NAME="flaskapp.service"

BACKUP_RELEASE_DIR="/var/backups/myapp/releases"
ROLLBACK_BACKUP_DIR="${BACKUP_RELEASE_DIR}/previous_release"

HEALTH_CHECK_URL="http://127.0.0.1:5000/products"

# Default source is the canonical application itself.
# A different source can be supplied with --source.
SOURCE_DIR="${APP_DIR}"

IS_DEPLOYING=false
STAGING_DIR=""

cleanup_staging() {
    if [[ -n "${STAGING_DIR:-}" && -d "$STAGING_DIR" ]]; then
        rm -rf "$STAGING_DIR"
        STAGING_DIR=""
    fi
}

wait_for_application() {
    local max_attempts="${1:-5}"
    local attempt

    for ((attempt=1; attempt<=max_attempts; attempt++)); do
        echo "[INFO] Health check attempt ${attempt}/${max_attempts}..."

        if curl -fsS -m 5 "$HEALTH_CHECK_URL" >/dev/null; then
            echo "[INFO] Application health check passed."
            return 0
        fi

        if [[ "$attempt" -lt "$max_attempts" ]]; then
            sleep 2
        fi
    done

    return 1
}

rollback() {
    echo "[WARN] Deployment failed. Executing automatic rollback..." >&2

    if [[ ! -d "$ROLLBACK_BACKUP_DIR" ]] || \
       [[ -z "$(ls -A "$ROLLBACK_BACKUP_DIR" 2>/dev/null)" ]]; then
        echo "[CRITICAL] No rollback backup available at:" >&2
        echo "[CRITICAL] $ROLLBACK_BACKUP_DIR" >&2
        return 1
    fi

    echo "[INFO] Restoring previous application code..."
    echo "[INFO] Source: $ROLLBACK_BACKUP_DIR"
    echo "[INFO] Target: $APP_DIR"

    mkdir -p "$APP_DIR" || return 1

    find "$APP_DIR" \
        -mindepth 1 \
        -maxdepth 1 \
        -exec rm -rf -- {} + || return 1

    cp -a "${ROLLBACK_BACKUP_DIR}/." "$APP_DIR/" || return 1

    echo "[INFO] Restoring ownership and permissions..."
    chown -R "${APP_OWNER}:${APP_GROUP}" "$APP_DIR" || return 1

    find "$APP_DIR" \
        -type d \
        -exec chmod 755 {} + || return 1

    if [[ -f "${APP_DIR}/app.py" ]]; then
        chmod 664 "${APP_DIR}/app.py" || return 1
    fi

    echo "[INFO] Resetting systemd failure state..."
    sudo systemctl reset-failed "$SERVICE_NAME" || true

    echo "[INFO] Restarting $SERVICE_NAME..."
    if ! sudo systemctl restart "$SERVICE_NAME"; then
        echo "[CRITICAL] Failed to restart $SERVICE_NAME after rollback." >&2
        return 1
    fi

    echo "[INFO] Waiting for rolled-back application to become ready..."
    if ! wait_for_application 5; then
        echo "[CRITICAL] Application did not recover after rollback." >&2
        return 1
    fi

    echo "[INFO] Validating Nginx..."
    if ! sudo nginx -t; then
        echo "[CRITICAL] Nginx validation failed after rollback." >&2
        return 1
    fi

    if ! sudo systemctl reload nginx; then
        echo "[CRITICAL] Failed to reload Nginx after rollback." >&2
        return 1
    fi

    echo "[INFO] Rollback completed and application health verified."
    return 0
}

cleanup() {
    local exit_code=$?

    # Avoid recursive EXIT handling.
    trap - EXIT

    cleanup_staging

    if [[ "$exit_code" -ne 0 && "$IS_DEPLOYING" == "true" ]]; then
        echo "[ERROR] Deployment exited with code $exit_code." >&2

        if rollback; then
            if [[ -x "$ALERT_SCRIPT" ]]; then
                "$ALERT_SCRIPT" \
                    "DEPLOYMENT FAILED - ROLLBACK SUCCESSFUL" \
                    "Deployment failed on $(hostname). The previous release was restored and verified successfully." \
                    || true
            fi
        else
            echo "[CRITICAL] AUTOMATIC ROLLBACK FAILED." >&2
            echo "[CRITICAL] Manual intervention is required." >&2

            if [[ -x "$ALERT_SCRIPT" ]]; then
                "$ALERT_SCRIPT" \
                    "CRITICAL DEPLOYMENT FAILURE" \
                    "Deployment failed on $(hostname) and automatic rollback could not restore application health. Manual intervention is required." \
                    || true
            fi
        fi
    fi

    exit "$exit_code"
}

trap cleanup EXIT

show_help() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Safely deploy Flask application code with automatic rollback.

Target:
  ${APP_DIR}

Default source:
  ${SOURCE_DIR}

Options:
  -s, --source <dir>   Deploy from another application directory
  -h, --help           Display this help message

Examples:
  $(basename "$0")
  $(basename "$0") --source /tmp/new_app_code
EOF
}

main() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -s|--source)
                if [[ $# -lt 2 ]]; then
                    echo "[ERROR] --source requires a directory." >&2
                    exit "$EXIT_INVALID_USAGE"
                fi
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
    echo "[INFO] Source : $SOURCE_DIR"
    echo "[INFO] Target : $APP_DIR"
    echo "[INFO] Service: $SERVICE_NAME"

    # Step 1: Validate source.
    if [[ ! -d "$SOURCE_DIR" ]]; then
        echo "[ERROR] Source directory does not exist: $SOURCE_DIR" >&2
        exit "$EXIT_INVALID_USAGE"
    fi

    # Step 2: Stage source before touching the live app.
    echo "[INFO] Staging deployment source..."
    STAGING_DIR="$(mktemp -d)"
    cp -a "${SOURCE_DIR}/." "$STAGING_DIR/"

    # Step 3: Validate candidate Python syntax in staging.
    echo "[INFO] Validating staged Python application syntax..."

    if [[ ! -f "${STAGING_DIR}/app.py" ]]; then
        echo "[ERROR] app.py not found in deployment source." >&2
        exit "$EXIT_INVALID_USAGE"
    fi

    if ! "$PYTHON_BIN" \
        -c 'import sys; compile(open(sys.argv[1], encoding="utf-8").read(), sys.argv[1], "exec")' \
        "${STAGING_DIR}/app.py"; then
        echo "[ERROR] Python syntax validation failed." >&2
        echo "[ERROR] Live application was not modified." >&2
        exit "$EXIT_INVALID_USAGE"
    fi

    echo "[INFO] Python syntax validation passed."

    # Step 4: Validate Nginx before touching the live app.
    echo "[INFO] Testing Nginx configuration..."
    if ! sudo nginx -t; then
        echo "[ERROR] Nginx configuration validation failed." >&2
        echo "[ERROR] Live application was not modified." >&2
        exit "$EXIT_INVALID_USAGE"
    fi

    # Step 5: Create rollback snapshot.
    echo "[INFO] Creating pre-deployment rollback backup..."
    mkdir -p "$BACKUP_RELEASE_DIR"
    rm -rf "$ROLLBACK_BACKUP_DIR"
    mkdir -p "$ROLLBACK_BACKUP_DIR"

    if [[ -d "$APP_DIR" ]] && [[ -n "$(ls -A "$APP_DIR" 2>/dev/null)" ]]; then
        cp -a "${APP_DIR}/." "$ROLLBACK_BACKUP_DIR/"
        echo "[INFO] Current release backed up to:"
        echo "[INFO] $ROLLBACK_BACKUP_DIR"
    else
        echo "[ERROR] Live application directory is empty." >&2
        echo "[ERROR] Refusing deployment because rollback would be impossible." >&2
        exit "$EXIT_INVALID_USAGE"
    fi

    # Any failure beyond here must trigger rollback.
    IS_DEPLOYING=true

    # Step 6: Replace live application.
    echo "[INFO] Deploying staged application..."
    find "$APP_DIR" \
        -mindepth 1 \
        -maxdepth 1 \
        -exec rm -rf -- {} +

    cp -a "${STAGING_DIR}/." "$APP_DIR/"
    cleanup_staging

    # Step 7: Restore canonical ownership/permissions.
    echo "[INFO] Setting application ownership and permissions..."
    chown -R "${APP_OWNER}:${APP_GROUP}" "$APP_DIR"

    find "$APP_DIR" \
        -type d \
        -exec chmod 755 {} +

    if [[ -f "${APP_DIR}/app.py" ]]; then
        chmod 664 "${APP_DIR}/app.py"
    fi

    # Step 8: Restart Flask.
    echo "[INFO] Restarting $SERVICE_NAME..."
    sudo systemctl reset-failed "$SERVICE_NAME" || true
    sudo systemctl restart "$SERVICE_NAME"

    # Step 9: Health check.
    echo "[INFO] Waiting for application health check..."
    if ! wait_for_application 5; then
        echo "[ERROR] Deployment health check failed." >&2
        return "$EXIT_HEALTH_CHECK_FAILED"
    fi

    # Step 10: Reload Nginx.
    echo "[INFO] Reloading Nginx..."
    sudo systemctl reload nginx

    IS_DEPLOYING=false

    echo "[INFO] Deployment completed successfully."
    echo "[INFO] Application is live and healthy."

    return "$EXIT_SUCCESS"
}

main "$@"
