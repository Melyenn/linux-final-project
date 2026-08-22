#!/usr/bin/env bash

# ================================================================
# File        : toolkit/log-rotate.sh
# Description : Log Rotation and Compression Tool with Retention Policy
# Author      : Nguyen Nam Viet - Capstone Linux Team
# Standard    : Shellcheck Clean, Text-Only, POSIX/Bash Compliant
# ================================================================

set -euo pipefail

#ENV_FILE="/etc/myapp/app.env"

# Exit code constants
readonly EXIT_SUCCESS=0
# readonly EXIT_GENERAL_ERROR=1
readonly EXIT_INVALID_USAGE=2
readonly EXIT_FILE_NOT_FOUND=127

# Default fallback configurations
TARGET_LOG="${LOG_FILE:-/var/log/myapp/app.log}"
RETENTION_COUNT="${RETENTION_COUNT:-7}"

# Load environment configuration if available
#if [[ -f "$ENV_FILE" ]]; then
    # shellcheck source=/dev/null
    #source "$ENV_FILE"
#fi

# Cleanup and error handling trap
cleanup() {
    local exit_code=$?
    if [[ "$exit_code" -ne 0 ]]; then
        echo "[ERROR] Log rotation script failed with exit code $exit_code at line $1" >&2
    fi
}
trap 'cleanup $LINENO' ERR

# Display usage help
show_help() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Rotate, compress, and apply retention policy to a target log file.

Options:
  -f, --file <path>     Target log file path (default: ${TARGET_LOG})
  -k, --keep <count>    Number of rotated log generations to keep (default: ${RETENTION_COUNT})
  -h, --help            Display this help message and exit

Examples:
  $(basename "$0")
  $(basename "$0") -f /var/log/nginx/access.log -k 5
EOF
}

# Core log rotation function
rotate_log() {
    local log_path="$1"
    local keep_count="$2"

    if [[ ! -f "$log_path" ]]; then
        echo "[ERROR] Target log file does not exist: $log_path" >&2
        return "$EXIT_FILE_NOT_FOUND"
    fi

    if [[ ! -s "$log_path" ]]; then
        echo "[INFO] Target log file is empty ($log_path). Skipping rotation."
        return "$EXIT_SUCCESS"
    fi

    echo "[INFO] Starting log rotation for: $log_path"
    echo "[INFO] Retention policy: Keeping $keep_count generation(s)"

    # Step 1: Purge oldest log file if it exceeds retention limit
    local oldest_archive="${log_path}.${keep_count}.gz"
    if [[ -f "$oldest_archive" ]]; then
        echo "[INFO] Removing oldest log archive exceeding retention: $oldest_archive"
        rm -f "$oldest_archive"
    fi

    # Step 2: Shift existing compressed log archives
    local i
    for (( i = keep_count - 1; i >= 1; i-- )); do
        local current_archive="${log_path}.${i}.gz"
        local next_archive="${log_path}.$(( i + 1 )).gz"
        if [[ -f "$current_archive" ]]; then
            mv "$current_archive" "$next_archive"
        fi
    done

    # Step 3: Copy log content and truncate live file (copytruncate strategy)
    local new_uncompressed="${log_path}.1"
    echo "[INFO] Copying active log content to $new_uncompressed..."
    cp "$log_path" "$new_uncompressed"

    echo "[INFO] Truncating active log file: $log_path..."
    : > "$log_path"

    # Step 4: Compress newly copied log file
    echo "[INFO] Compressing $new_uncompressed using gzip..."
    gzip -f "$new_uncompressed"

    echo "[INFO] Log rotation completed successfully for $log_path"
    return "$EXIT_SUCCESS"
}

main() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -f|--file)
                TARGET_LOG="$2"
                shift 2
                ;;
            -k|--keep)
                RETENTION_COUNT="$2"
                shift 2
                ;;
            -h|--help)
                show_help
                exit "$EXIT_SUCCESS"
                ;;
            *)
                echo "[ERROR] Unknown option: $1" >&2
                show_help
                exit "$EXIT_INVALID_USAGE"
                ;;
        esac
    done

    # Validate that retention count is a positive integer
    if [[ ! "$RETENTION_COUNT" =~ ^[1-9][0-9]*$ ]]; then
        echo "[ERROR] Invalid retention count '$RETENTION_COUNT'. Must be a positive integer." >&2
        exit "$EXIT_INVALID_USAGE"
    fi

    rotate_log "$TARGET_LOG" "$RETENTION_COUNT"
}

main "$@"
