#!/usr/bin/env bash
set -euo pipefail

AGENT_USER_ADMIN="agent-admin"
AGENT_USER_DEV="agent-dev"
GROUP_CORE="agent-core"

AGENT_HOME="/home/${AGENT_USER_ADMIN}/agent-app"
AGENT_BIN_DIR="${AGENT_HOME}/bin"
AGENT_DEST="${AGENT_BIN_DIR}/agent-app"
AGENT_PORT="15034"
AGENT_UPLOAD_DIR="${AGENT_HOME}/upload_files"
AGENT_KEY_PATH="${AGENT_HOME}/api_keys"
AGENT_LOG_DIR="/var/log/agent-app"

run_as_root() {
    if [[ "$(id -u)" -eq 0 ]]; then
        "$@"
    else
        sudo "$@"
    fi
}

find_binary() {
    local filename="$1"
    local candidates=(
        "./${filename}"
        "./agent-app/${filename}"
        "../agent-app/${filename}"
    )

    local path
    for path in "${candidates[@]}"; do
        if [[ -f "$path" ]]; then
            printf '%s\n' "$path"
            return 0
        fi
    done

    return 1
}

if [[ "$(id -u)" -ne 0 ]] && ! command -v sudo >/dev/null 2>&1; then
    echo "[ERROR] This script requires root privileges or sudo." >&2
    exit 1
fi

ARCH="$(uname -m)"
case "$ARCH" in
    x86_64)
        SRC="$(find_binary agent-app-linux-x86 || true)"
        ;;
    aarch64|arm64)
        SRC="$(find_binary agent-app-linux-arm64 || true)"
        ;;
    *)
        echo "[ERROR] Unsupported architecture: ${ARCH}" >&2
        exit 1
        ;;
esac

if [[ -z "${SRC:-}" ]]; then
    echo "[ERROR] Missing Agent binary for architecture: ${ARCH}" >&2
    echo "[ERROR] Expected agent-app-linux-x86 or agent-app-linux-arm64 in the mission root or agent-app/." >&2
    exit 1
fi

if ! id "$AGENT_USER_DEV" >/dev/null 2>&1; then
    echo "[ERROR] Missing user ${AGENT_USER_DEV}. Run scripts/setup_users_permissions.sh first." >&2
    exit 1
fi

run_as_root mkdir -p "$AGENT_BIN_DIR"
run_as_root cp "$SRC" "$AGENT_DEST"
run_as_root chown "${AGENT_USER_DEV}:${GROUP_CORE}" "$AGENT_DEST"
run_as_root chmod 750 "$AGENT_DEST"

run_as_root tee /etc/profile.d/agent-app.sh >/dev/null <<EOF
export AGENT_HOME="${AGENT_HOME}"
export AGENT_PORT="${AGENT_PORT}"
export AGENT_UPLOAD_DIR="${AGENT_UPLOAD_DIR}"
export AGENT_KEY_PATH="${AGENT_KEY_PATH}"
export AGENT_LOG_DIR="${AGENT_LOG_DIR}"
EOF
run_as_root chmod 644 /etc/profile.d/agent-app.sh

echo "[INFO] Installed Agent app: ${SRC} -> ${AGENT_DEST}"
echo "[INFO] Environment file: /etc/profile.d/agent-app.sh"
echo "[INFO] Run as ${AGENT_USER_ADMIN}:"
echo "       source /etc/profile.d/agent-app.sh"
echo "       ${AGENT_DEST}"
