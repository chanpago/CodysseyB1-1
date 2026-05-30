#!/usr/bin/env bash
set -euo pipefail

APP_NAME="agent-app"
APP_PORT="15034"

LOG_DIR="/var/log/agent-app"
LOG_FILE="${LOG_DIR}/monitor.log"

MAX_LOG_SIZE=$((10 * 1024 * 1024))
MAX_ROTATE_COUNT=10

CPU_THRESHOLD="20"
MEM_THRESHOLD="10"
DISK_THRESHOLD="80"

timestamp() {
    date "+%Y-%m-%d %H:%M:%S"
}

ensure_log_dir() {
    mkdir -p "$LOG_DIR"
    touch "$LOG_FILE"
}

rotate_logs_if_needed() {
    local size

    if [[ ! -f "$LOG_FILE" ]]; then
        touch "$LOG_FILE"
        return 0
    fi

    size=$(stat -c%s "$LOG_FILE" 2>/dev/null || echo 0)
    if (( size < MAX_LOG_SIZE )); then
        return 0
    fi

    rm -f "${LOG_FILE}.${MAX_ROTATE_COUNT}"

    local i
    for ((i=MAX_ROTATE_COUNT-1; i>=1; i--)); do
        if [[ -f "${LOG_FILE}.${i}" ]]; then
            mv "${LOG_FILE}.${i}" "${LOG_FILE}.$((i + 1))"
        fi
    done

    mv "$LOG_FILE" "${LOG_FILE}.1"
    touch "$LOG_FILE"
}

check_process() {
    local pid

    pid=$(pgrep -x "${APP_NAME}" | head -n 1 || true)
    if [[ -z "$pid" ]]; then
        pid=$(pgrep -f "/${APP_NAME}([[:space:]]|$)" | awk -v self="$$" '$1 != self { print; exit }' || true)
    fi

    if [[ -z "$pid" ]]; then
        echo "Checking process '${APP_NAME}'... [FAIL]"
        return 1
    fi

    echo "Checking process '${APP_NAME}'... [OK] (PID: ${pid})"
    MONITOR_PID="$pid"
}

check_port() {
    if ss -tuln | awk '{print $5}' | grep -qE "(:|\.)${APP_PORT}$"; then
        echo "Checking port ${APP_PORT} LISTEN... [OK]"
        return 0
    fi

    echo "Checking port ${APP_PORT} LISTEN... [FAIL]"
    return 1
}

check_firewall() {
    if command -v ufw >/dev/null 2>&1; then
        if ufw status 2>/dev/null | grep -q "Status: active"; then
            echo "Checking firewall UFW... [OK]"
        elif [[ -r /etc/ufw/ufw.conf ]] && grep -q '^ENABLED=yes' /etc/ufw/ufw.conf; then
            echo "Checking firewall UFW config... [OK]"
        elif systemctl is-active --quiet ufw 2>/dev/null; then
            echo "Checking firewall UFW service... [OK]"
        else
            echo "[WARNING] UFW is not active"
        fi
        return 0
    fi

    if command -v firewall-cmd >/dev/null 2>&1; then
        if firewall-cmd --state 2>/dev/null | grep -q "running"; then
            echo "Checking firewall firewalld... [OK]"
        else
            echo "[WARNING] firewalld is not active"
        fi
        return 0
    fi

    echo "[WARNING] No supported firewall command found"
}

get_cpu_usage() {
    top -bn1 | awk -F'id,' '/Cpu\(s\)|%Cpu/ {
        split($1, a, ",")
        idle=a[length(a)]
        gsub(/[^0-9.]/, "", idle)
        if (idle == "") {
            next
        }
        printf "%.1f", 100-idle
        found=1
    }
    END {
        if (!found) {
            printf "0.0"
        }
    }'
}

get_mem_usage() {
    free | awk '/Mem:/ {
        printf "%.1f", $3/$2*100
    }'
}

get_disk_usage() {
    df / | awk 'NR==2 {
        gsub(/%/, "", $5)
        printf "%s", $5
    }'
}

warn_if_exceeded() {
    local name="$1"
    local value="$2"
    local threshold="$3"

    if awk -v v="$value" -v t="$threshold" 'BEGIN { exit !(v > t) }'; then
        echo "[WARNING] ${name} threshold exceeded (${value}% > ${threshold}%)"
    fi
}

main() {
    local cpu mem disk
    MONITOR_PID=""

    ensure_log_dir
    rotate_logs_if_needed

    echo "====== SYSTEM MONITOR RESULT ======"
    echo
    echo "[HEALTH CHECK]"

    check_process
    check_port
    check_firewall

    echo
    echo "[RESOURCE MONITORING]"
    cpu=$(get_cpu_usage)
    mem=$(get_mem_usage)
    disk=$(get_disk_usage)

    echo "CPU Usage : ${cpu}%"
    echo "MEM Usage : ${mem}%"
    echo "DISK Used : ${disk}%"
    echo

    warn_if_exceeded "CPU" "$cpu" "$CPU_THRESHOLD"
    warn_if_exceeded "MEM" "$mem" "$MEM_THRESHOLD"
    warn_if_exceeded "DISK_USED" "$disk" "$DISK_THRESHOLD"

    printf '[%s] PID:%s CPU:%s%% MEM:%s%% DISK_USED:%s%%\n' \
        "$(timestamp)" "$MONITOR_PID" "$cpu" "$mem" "$disk" >> "$LOG_FILE"

    echo
    echo "[INFO] Log appended: ${LOG_FILE}"
}

main "$@"
