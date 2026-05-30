#!/usr/bin/env bash
set -euo pipefail

run_maybe_sudo() {
    if [[ "$(id -u)" -eq 0 ]]; then
        "$@"
    elif command -v sudo >/dev/null 2>&1; then
        sudo "$@"
    else
        "$@"
    fi
}

run_as_agent_admin() {
    if [[ "$(id -u)" -eq 0 ]]; then
        runuser -u agent-admin -- "$@"
    elif command -v sudo >/dev/null 2>&1; then
        sudo -u agent-admin "$@"
    else
        "$@"
    fi
}

echo "========== SSH CONFIG =========="
run_maybe_sudo sshd -T 2>/dev/null | grep -E '^(port|permitrootlogin)' || true
ss -tulnp 2>/dev/null | grep -E 'ssh|20022' || true

echo
echo "========== FIREWALL =========="
if command -v ufw >/dev/null 2>&1; then
    run_maybe_sudo ufw status verbose || true
fi
if command -v firewall-cmd >/dev/null 2>&1; then
    run_maybe_sudo firewall-cmd --list-all || true
fi

echo
echo "========== USERS / GROUPS =========="
id agent-admin || true
id agent-dev || true
id agent-test || true

echo
echo "========== DIRECTORIES =========="
ls -ld /home/agent-admin/agent-app || true
ls -ld /home/agent-admin/agent-app/upload_files || true
ls -ld /home/agent-admin/agent-app/api_keys || true
ls -ld /home/agent-admin/agent-app/bin || true
ls -ld /var/log/agent-app || true

echo
echo "========== FILES =========="
ls -l /home/agent-admin/agent-app/bin/agent-app || true
ls -l /home/agent-admin/agent-app/bin/monitor.sh || true
ls -l /home/agent-admin/agent-app/api_keys/t_secret.key || true
ls -l /var/log/agent-app/monitor.log || true

echo
echo "========== PROCESS / PORT =========="
pgrep -af agent-app || true
ss -tulnp 2>/dev/null | grep 15034 || true

echo
echo "========== MONITOR LOG =========="
tail -n 10 /var/log/agent-app/monitor.log || true

echo
echo "========== CRON =========="
run_as_agent_admin crontab -l || true
