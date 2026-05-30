#!/usr/bin/env bash
set -euo pipefail

AGENT_USER_ADMIN="agent-admin"
AGENT_USER_DEV="agent-dev"
AGENT_USER_TEST="agent-test"

GROUP_COMMON="agent-common"
GROUP_CORE="agent-core"

AGENT_HOME="/home/${AGENT_USER_ADMIN}/agent-app"
AGENT_UPLOAD_DIR="${AGENT_HOME}/upload_files"
AGENT_KEY_DIR="${AGENT_HOME}/api_keys"
AGENT_KEY_PATH="${AGENT_KEY_DIR}/secret.key"
AGENT_LOG_DIR="/var/log/agent-app"
AGENT_LOG_FILE="${AGENT_LOG_DIR}/monitor.log"
AGENT_BIN_DIR="${AGENT_HOME}/bin"

require_root_or_sudo() {
    if [[ "$(id -u)" -ne 0 ]] && ! command -v sudo >/dev/null 2>&1; then
        echo "[ERROR] This script requires root privileges or sudo." >&2
        exit 1
    fi
}

run_as_root() {
    if [[ "$(id -u)" -eq 0 ]]; then
        "$@"
    else
        sudo "$@"
    fi
}

create_user_if_missing() {
    local username="$1"

    if id "$username" >/dev/null 2>&1; then
        echo "[INFO] User already exists: ${username}"
        return 0
    fi

    run_as_root useradd -m -s /bin/bash "$username"
    echo "[INFO] Created user: ${username}"
}

require_root_or_sudo

run_as_root groupadd -f "$GROUP_COMMON"
run_as_root groupadd -f "$GROUP_CORE"

create_user_if_missing "$AGENT_USER_ADMIN"
create_user_if_missing "$AGENT_USER_DEV"
create_user_if_missing "$AGENT_USER_TEST"

run_as_root usermod -aG "$GROUP_COMMON" "$AGENT_USER_ADMIN"
run_as_root usermod -aG "$GROUP_COMMON" "$AGENT_USER_DEV"
run_as_root usermod -aG "$GROUP_COMMON" "$AGENT_USER_TEST"
run_as_root usermod -aG "$GROUP_CORE" "$AGENT_USER_ADMIN"
run_as_root usermod -aG "$GROUP_CORE" "$AGENT_USER_DEV"

run_as_root mkdir -p "$AGENT_HOME" "$AGENT_UPLOAD_DIR" "$AGENT_KEY_DIR" "$AGENT_LOG_DIR" "$AGENT_BIN_DIR"

run_as_root chown "${AGENT_USER_ADMIN}:${GROUP_COMMON}" "$AGENT_HOME"
run_as_root chmod 2770 "$AGENT_HOME"

run_as_root chown -R "${AGENT_USER_ADMIN}:${GROUP_COMMON}" "$AGENT_UPLOAD_DIR"
run_as_root chmod 2770 "$AGENT_UPLOAD_DIR"

run_as_root chown -R "${AGENT_USER_ADMIN}:${GROUP_CORE}" "$AGENT_KEY_DIR"
run_as_root chmod 2770 "$AGENT_KEY_DIR"

run_as_root chown -R "${AGENT_USER_ADMIN}:${GROUP_CORE}" "$AGENT_LOG_DIR"
run_as_root chmod 2770 "$AGENT_LOG_DIR"

run_as_root chown -R "${AGENT_USER_DEV}:${GROUP_CORE}" "$AGENT_BIN_DIR"
run_as_root chmod 2750 "$AGENT_BIN_DIR"

printf '%s\n' "agent_api_key_test" | run_as_root tee "$AGENT_KEY_PATH" >/dev/null
run_as_root chown "${AGENT_USER_ADMIN}:${GROUP_CORE}" "$AGENT_KEY_PATH"
run_as_root chmod 660 "$AGENT_KEY_PATH"

run_as_root touch "$AGENT_LOG_FILE"
run_as_root chown "${AGENT_USER_ADMIN}:${GROUP_CORE}" "$AGENT_LOG_FILE"
run_as_root chmod 660 "$AGENT_LOG_FILE"

echo "========== USERS / GROUPS =========="
id "$AGENT_USER_ADMIN"
id "$AGENT_USER_DEV"
id "$AGENT_USER_TEST"

echo
echo "========== DIRECTORIES =========="
ls -ld "$AGENT_HOME" "$AGENT_UPLOAD_DIR" "$AGENT_KEY_DIR" "$AGENT_LOG_DIR" "$AGENT_BIN_DIR"

echo
echo "========== FILES =========="
ls -l "$AGENT_KEY_PATH" "$AGENT_LOG_FILE"
