#!/usr/bin/env bash

# ================================================================
# File        : toolkit/menu.sh
# Description : Operational CLI Menu and Task Dispatcher
# Author      : Nguyen Nam Viet - Capstone Linux Team
# Standard    : Shellcheck Clean, Text-Only, POSIX/Bash Compliant
# ================================================================

set -euo pipefail

# Define script directory dynamically to allow execution from anywhere
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#ENV_FILE="/etc/myapp/app.env"

# Exit code constants
readonly EXIT_SUCCESS=0
readonly EXIT_GENERAL_ERROR=1
readonly EXIT_INVALID_USAGE=2
readonly EXIT_FILE_NOT_FOUND=127

# Load environment configuration if present
#if [[ -f "$ENV_FILE" ]]; then
    # shellcheck source=/dev/null
    #source "$ENV_FILE"
#fi

# Cleanup and error handling trap
cleanup() {
    local exit_code=$?
    if [[ "$exit_code" -ne 0 ]]; then
        echo "[ERROR] Command failed with exit code $exit_code at line $1" >&2
    fi
}
trap 'cleanup $LINENO' ERR

# Display usage help
show_help() {
    cat << EOF
Usage: $(basename "$0") [OPTION]

Operations & Automation CLI Toolkit Dispatcher.

Options:
  -d, --deploy       Execute application deployment
  -b, --backup       Execute database and web content backup
  -r, --restore      Execute data restoration process
  -c, --check        Execute system health-check
  -l, --log-rotate   Execute log rotation
  -i, --interactive  Launch interactive CLI menu (default)
  -h, --help         Display this help message and exit

Examples:
  $(basename "$0") -c
  $(basename "$0") --deploy
EOF
}

# Helper function to validate and execute sub-scripts
dispatch_task() {
    local script_name="$1"
    shift
    local script_path="${SCRIPT_DIR}/${script_name}"

    if [[ ! -f "$script_path" ]]; then
        echo "[ERROR] Task script not found: $script_path" >&2
        return "$EXIT_FILE_NOT_FOUND"
    fi

    if [[ ! -x "$script_path" ]]; then
        echo "[WARN] Task script is not executable. Attempting fix: $script_path" >&2
        chmod +x "$script_path" || {
            echo "[ERROR] Failed to make script executable: $script_path" >&2
            return "$EXIT_GENERAL_ERROR"
        }
    fi

    echo "[INFO] Dispatching task: $script_name"
    "$script_path" "$@"
}

# Sub-task routing procedures
# shellcheck disable=SC2120
task_deploy() {
    dispatch_task "deploy.sh" "$@"
}

# shellcheck disable=SC2120
task_backup() {
    dispatch_task "backup.sh" "$@"
}

# shellcheck disable=SC2120
task_restore() {
    dispatch_task "restore.sh" "$@"
}

# shellcheck disable=SC2120
task_health_check() {
    dispatch_task "health-check.sh" "$@"
}

# shellcheck disable=SC2120
task_log_rotate() {
    dispatch_task "log-rotate.sh" "$@"
}

# Interactive menu interface
run_interactive() {
    local choice=""

    while true; do
        echo ""
        echo "========================================================"
        echo "   CAPSTONE SYSTEM OPERATIONS & AUTOMATION TOOLKIT      "
        echo "========================================================"
        echo "1) Deploy Application  (deploy.sh)"
        echo "2) Run System Backup   (backup.sh)"
        echo "3) Restore System Data (restore.sh)"
        echo "4) Run Health Check    (health-check.sh)"
        echo "5) Rotate Log Files    (log-rotate.sh)"
        echo "6) Exit"
        echo "========================================================"
        read -r -p "Select an option [1-6]: " choice

        case "$choice" in
            1)
                task_deploy || echo "[ERROR] Deploy task failed." >&2
                ;;
            2)
                task_backup || echo "[ERROR] Backup task failed." >&2
                ;;
            3)
                task_restore || echo "[ERROR] Restore task failed." >&2
                ;;
            4)
                task_health_check || echo "[ERROR] Health check task failed." >&2
                ;;
            5)
                task_log_rotate || echo "[ERROR] Log rotation task failed." >&2
                ;;
            6)
                echo "[INFO] Exiting operations toolkit."
                exit "$EXIT_SUCCESS"
                ;;
            *)
                echo "[WARN] Invalid choice '$choice'. Please select between 1 and 6." >&2
                ;;
        esac
    done
}

# Main entrypoint parsing arguments
main() {
    if [[ $# -eq 0 ]]; then
        run_interactive
        return "$EXIT_SUCCESS"
    fi

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -d|--deploy)
                task_deploy
                shift
                ;;
            -b|--backup)
                task_backup
                shift
                ;;
            -r|--restore)
                task_restore
                shift
                ;;
            -c|--check)
                task_health_check
                shift
                ;;
            -l|--log-rotate)
                task_log_rotate
                shift
                ;;
            -i|--interactive)
                run_interactive
                shift
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
}

main "$@"
