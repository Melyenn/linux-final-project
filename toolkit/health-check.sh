#!/usr/bin/env bash

# ================================================================
# File        : toolkit/health-check.sh
# Description : System Health and Resource Threshold Monitor
# Author      : Nguyen Nam Viet - Capstone Linux Team
# Standard    : Shellcheck Clean, Text-Only, POSIX/Bash Compliant
# ================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="/etc/myapp/toolkit.env"
ALERT_SCRIPT="${SCRIPT_DIR}/send_alert.sh"

# Exit code constants
readonly EXIT_SUCCESS=0
readonly EXIT_BREACH_DETECTED=1
# readonly EXIT_MISSING_ALERT_SCRIPT=3

# Default fallback thresholds
CPU_THRESHOLD="${CPU_THRESHOLD:-80}"
RAM_THRESHOLD="${RAM_THRESHOLD:-85}"
DISK_THRESHOLD="${DISK_THRESHOLD:-90}"

# Mandatory services and ports to monitor
readonly MONITORED_SERVICES=("flaskapp.service" "postgresql" "nginx")
readonly MONITORED_PORTS=(5000 5432 80)

# Load environment configuration if available
if [[ -f "$ENV_FILE" ]]; then
    # shellcheck source=/dev/null
    source "$ENV_FILE"
fi

# Cleanup and error handling trap
cleanup() {
    local exit_code=$?
    if [[ "$exit_code" -ne 0 && "$exit_code" -ne "$EXIT_BREACH_DETECTED" ]]; then
        echo "[ERROR] Health check script failed unexpectedly with exit code $exit_code at line $1" >&2
    fi
}
trap 'cleanup $LINENO' ERR

# Global list to collect detected anomalies
ANOMALIES=""

append_anomaly() {
    local message="$1"
    if [[ -z "$ANOMALIES" ]]; then
        ANOMALIES="- ${message}"
    else
        ANOMALIES="${ANOMALIES}"$'\n'"- ${message}"
    fi
}

# Function to check CPU usage percentage
check_cpu() {
    echo "[INFO] Checking CPU usage..."
    local cpu_idle
    cpu_idle=$(LC_ALL=C mpstat 1 1 | awk '/Average:/ && $2 == "all" {printf "%.0f\n", $NF}')
    
    # Handle idle calculation edge case
    if [[ -z "$cpu_idle" || ! "$cpu_idle" =~ ^[0-9]+$ ]]; then
        cpu_idle=0
    fi

    local cpu_usage=$(( 100 - cpu_idle ))
    echo "[INFO] Current CPU usage: ${cpu_usage}% (Threshold: ${CPU_THRESHOLD}%)"

    if [[ "$cpu_usage" -ge "$CPU_THRESHOLD" ]]; then
        append_anomaly "High CPU usage: ${cpu_usage}% (Threshold: ${CPU_THRESHOLD}%)"
    fi
}

# Function to check RAM usage percentage
check_ram() {
    echo "[INFO] Checking RAM usage..."
    local ram_usage
    ram_usage=$(free | awk '/Mem:/ {printf "%d", $3/$2 * 100}')

    echo "[INFO] Current RAM usage: ${ram_usage}% (Threshold: ${RAM_THRESHOLD}%)"

    if [[ "$ram_usage" -ge "$RAM_THRESHOLD" ]]; then
        append_anomaly "High RAM usage: ${ram_usage}% (Threshold: ${RAM_THRESHOLD}%)"
    fi
}

# Function to check Disk usage percentage on root partition
check_disk() {
    echo "[INFO] Checking Disk usage (/)..."
    local disk_usage
    disk_usage=$(df / | awk 'NR==2 {print $5}' | tr -d '%')

    echo "[INFO] Current Disk usage: ${disk_usage}% (Threshold: ${DISK_THRESHOLD}%)"

    if [[ "$disk_usage" -ge "$DISK_THRESHOLD" ]]; then
        append_anomaly "High Disk usage: ${disk_usage}% (Threshold: ${DISK_THRESHOLD}%)"
    fi
}

# Function to check systemd service statuses
check_services() {
    echo "[INFO] Checking Systemd services..."
    local svc
    for svc in "${MONITORED_SERVICES[@]}"; do
        if systemctl is-active --quiet "$svc"; then
            echo "[INFO] Service '${svc}': ACTIVE"
        else
            echo "[WARN] Service '${svc}': INACTIVE/FAILED" >&2
            append_anomaly "Service '${svc}' is not running"
        fi
    done
}

# Function to check required open network ports
check_ports() {
    echo "[INFO] Checking listening network ports..."
    local port
    for port in "${MONITORED_PORTS[@]}"; do
        if ss -tulpn | grep -q ":${port} "; then
            echo "[INFO] Port ${port}: LISTENING"
        else
            echo "[WARN] Port ${port}: NOT LISTENING" >&2
            append_anomaly "Port ${port} is not listening"
        fi
    done
}

# Main execution logic
main() {
    echo "[INFO] Starting System Health Check on $(hostname)..."

    check_cpu
    check_ram
    check_disk
    check_services
    check_ports

    if [[ -n "$ANOMALIES" ]]; then
        echo "========================================================" >&2
        echo "[CRITICAL] System health breach(es) detected:" >&2
        echo "$ANOMALIES" >&2
        echo "========================================================" >&2

        if [[ -x "$ALERT_SCRIPT" ]]; then
            echo "[INFO] Triggering alert dispatcher..."
            "$ALERT_SCRIPT" "HEALTH CHECK BREACH" "System anomalies detected on $(hostname):"$'\n'"$ANOMALIES" || true
        else
            echo "[WARN] Alert script not executable or missing: $ALERT_SCRIPT" >&2
        fi

        exit "$EXIT_BREACH_DETECTED"
    else
        echo "[INFO] System health status: ALL CHECKS PASSED OK."
        exit "$EXIT_SUCCESS"
    fi
}

main "$@"
