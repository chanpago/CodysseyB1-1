#!/usr/bin/env bash
set -euo pipefail

AGENT_USER_ADMIN="agent-admin"
MONITOR_PATH="/home/${AGENT_USER_ADMIN}/agent-app/bin/monitor.sh"
CRON_OUT="/var/log/agent-app/monitor_cron.out"

run_as_root() {
    if [[ "$(id -u)" -eq 0 ]]; then
        "$@"
    else
        sudo "$@"
    fi
}

run_as_agent_admin() {
    if [[ "$(id -u)" -eq 0 ]]; then
        runuser -u "$AGENT_USER_ADMIN" -- "$@"
    else
        sudo -u "$AGENT_USER_ADMIN" "$@"
    fi
}

if ! run_as_agent_admin test -x "$MONITOR_PATH"; then
    echo "[ERROR] Missing executable monitor script: ${MONITOR_PATH}" >&2
    echo "[ERROR] Copy scripts/monitor.sh to this path and set owner/mode first." >&2
    exit 1
fi

run_as_root touch "$CRON_OUT"
run_as_root chown "${AGENT_USER_ADMIN}:agent-core" "$CRON_OUT"
run_as_root chmod 660 "$CRON_OUT"

tmp_cron="$(mktemp)"
trap 'rm -f "$tmp_cron"' EXIT

run_as_agent_admin crontab -l 2>/dev/null | grep -v -F "$MONITOR_PATH" > "$tmp_cron" || true
printf '* * * * * %s >> %s 2>&1\n' "$MONITOR_PATH" "$CRON_OUT" >> "$tmp_cron"
chmod 644 "$tmp_cron"
run_as_agent_admin crontab "$tmp_cron"

run_as_agent_admin crontab -l
