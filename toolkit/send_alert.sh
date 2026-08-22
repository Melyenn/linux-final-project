#!/usr/bin/env bash

# ================================================================
# File        : toolkit/send_alert.sh
# Description : Dual-channel Alerting Module (Telegram Bot & Email)
# Author      : Nguyen Nam Viet - Capstone Linux Team
# Standard    : Shellcheck Clean, Text-Only, POSIX/Bash Compliant
# ================================================================

set -euo pipefail

ENV_FILE="/etc/myapp/toolkit.env"

# Exit code constants
readonly EXIT_SUCCESS=0
readonly EXIT_GENERAL_ERROR=1
readonly EXIT_INVALID_USAGE=2
# readonly EXIT_MISSING_CONFIG=3

# Default fallback configurations
TELEGRAM_BOT_TOKEN="${TELEGRAM_BOT_TOKEN:-}"
TELEGRAM_CHAT_ID="${TELEGRAM_CHAT_ID:-}"
ALERT_EMAIL_TO="${ALERT_EMAIL_TO:-}"
ALERT_EMAIL_FROM="${ALERT_EMAIL_FROM:-sysadmin@localhost}"
ALERT_CHANNEL="${ALERT_CHANNEL:-all}"

# Load environment configuration if available
if [[ -f "$ENV_FILE" ]]; then
    # shellcheck source=/dev/null
    source "$ENV_FILE"
fi

# Cleanup and error handling trap
cleanup() {
    local exit_code=$?
    if [[ "$exit_code" -ne 0 ]]; then
        echo "[ERROR] Alert script failed with exit code $exit_code at line $1" >&2
    fi
}
trap 'cleanup $LINENO' ERR

# Display usage help
show_help() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS] "Subject/Title" "Message Body"

Send operational alerts via Telegram Bot, Email (msmtp/mail), or both.

Options:
  -c, --channel <type>    Alert channel: 'telegram', 'email', or 'all' (default: ${ALERT_CHANNEL})
  -f, --file <file_path>  Attach a log or text file to the email alert
  -h, --help              Display this help message and exit

Examples:
  $(basename "$0") "CRITICAL" "High CPU usage detected on main host"
  $(basename "$0") -c telegram "WARNING" "Disk usage exceeded threshold"
  $(basename "$0") -c email -f /var/log/myapp/app.log "REPORT" "Daily system status"
EOF
}

# Function to send Telegram message via curl
send_telegram() {
    local subject="$1"
    local message="$2"

    if [[ -z "$TELEGRAM_BOT_TOKEN" || -z "$TELEGRAM_CHAT_ID" ]]; then
        echo "[WARN] Telegram credentials not configured in $ENV_FILE. Skipping Telegram alert." >&2
        return 0
    fi

    local text_payload
    text_payload="[ALERT - ${subject}]
Host: $(hostname)
Time: $(date -u '+%Y-%m-%d %H:%M:%S UTC')
Message: ${message}"

    echo "[INFO] Sending alert via Telegram Bot..."
    local http_code
    http_code=$(curl -s -o /dev/null -w "%{http_code}" \
        -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
        -d "chat_id=${TELEGRAM_CHAT_ID}" \
        -d "text=${text_payload}" \
        --connect-timeout 10 || echo "000")

    if [[ "$http_code" -eq 200 ]]; then
        echo "[INFO] Telegram alert delivered successfully."
    else
        echo "[ERROR] Failed to send Telegram alert. HTTP response code: ${http_code}" >&2
        return "$EXIT_GENERAL_ERROR"
    fi
}

# Function to send Email message via mail / msmtp
send_email() {
    local subject="$1"
    local message="$2"
    local attachment="${3:-}"

    if [[ -z "$ALERT_EMAIL_TO" ]]; then
        echo "[WARN] ALERT_EMAIL_TO not configured in $ENV_FILE. Skipping Email alert." >&2
        return 0
    fi

    local mail_cmd=""
    if command -v mail &>/dev/null; then
        mail_cmd="mail"
    elif command -v msmtp &>/dev/null; then
        mail_cmd="msmtp"
    else
        echo "[WARN] Neither 'mail' nor 'msmtp' command found. Skipping Email alert." >&2
        return 0
    fi

    local email_subject
    email_subject="[CAPSTONE ALERT] [${subject}] on $(hostname)"
    local email_body
    email_body="System Operational Alert
========================================
Host    : $(hostname)
Date    : $(date -u '+%Y-%m-%d %H:%M:%S UTC')
Subject : ${subject}
========================================

Message:
${message}"

    echo "[INFO] Sending alert via Email (${mail_cmd}) to ${ALERT_EMAIL_TO}..."

    if [[ "$mail_cmd" == "mail" ]]; then
        if [[ -n "$attachment" && -f "$attachment" ]]; then
            echo "${email_body}" | mail -s "${email_subject}" -a "${attachment}" "${ALERT_EMAIL_TO}"
        else
            echo "${email_body}" | mail -s "${email_subject}" "${ALERT_EMAIL_TO}"
        fi
    elif [[ "$mail_cmd" == "msmtp" ]]; then
        printf "Subject: %s\nTo: %s\nFrom: %s\n\n%s" \
            "${email_subject}" "${ALERT_EMAIL_TO}" "${ALERT_EMAIL_FROM}" "${email_body}" | msmtp "${ALERT_EMAIL_TO}"
    fi

    echo "[INFO] Email alert dispatched successfully."
}

# Main execution logic
main() {
    local channel="$ALERT_CHANNEL"
    local attachment=""
    local subject=""
    local message=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -c|--channel)
                channel="$2"
                shift 2
                ;;
            -f|--file)
                attachment="$2"
                shift 2
                ;;
            -h|--help)
                show_help
                exit "$EXIT_SUCCESS"
                ;;
            -*)
                echo "[ERROR] Unknown option: $1" >&2
                show_help
                exit "$EXIT_INVALID_USAGE"
                ;;
            *)
                if [[ -z "$subject" ]]; then
                    subject="$1"
                elif [[ -z "$message" ]]; then
                    message="$1"
                else
                    echo "[ERROR] Unexpected positional argument: $1" >&2
                    exit "$EXIT_INVALID_USAGE"
                fi
                shift
                ;;
        esac
    done

    if [[ -z "$subject" || -z "$message" ]]; then
        echo "[ERROR] Missing required arguments: 'Subject' and 'Message Body'." >&2
        show_help
        exit "$EXIT_INVALID_USAGE"
    fi

    case "$channel" in
        telegram)
            send_telegram "$subject" "$message"
            ;;
        email)
            send_email "$subject" "$message" "$attachment"
            ;;
        all)
            # Try sending via both channels without breaking execution if one fails
            send_telegram "$subject" "$message" || true
            send_email "$subject" "$message" "$attachment" || true
            ;;
        *)
            echo "[ERROR] Invalid channel '$channel'. Allowed values: telegram, email, all." >&2
            exit "$EXIT_INVALID_USAGE"
            ;;
    esac

    return "$EXIT_SUCCESS"
}

main "$@"
