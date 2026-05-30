#!/usr/bin/env bash
set -euo pipefail

SSH_PORT="20022"
APP_PORT="15034"

run_as_root() {
    if [[ "$(id -u)" -eq 0 ]]; then
        "$@"
    else
        sudo "$@"
    fi
}

if [[ "$(id -u)" -ne 0 ]] && ! command -v sudo >/dev/null 2>&1; then
    echo "[ERROR] This script requires root privileges or sudo." >&2
    exit 1
fi

if ! command -v ufw >/dev/null 2>&1; then
    run_as_root apt-get update
    run_as_root apt-get install -y ufw
fi

run_as_root ufw --force reset
run_as_root ufw default deny incoming
run_as_root ufw default allow outgoing
run_as_root ufw allow "${SSH_PORT}/tcp"
run_as_root ufw allow "${APP_PORT}/tcp"
run_as_root ufw --force enable

run_as_root ufw status verbose
