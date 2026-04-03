#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# rollback.sh - Restore system to pre-hardening state
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

# --------------------------------------------------------------
# perform_rollback - Read rollback log and restore backed-up files
# Usage: perform_rollback [logfile]
# If no logfile given, uses the most recent one
# --------------------------------------------------------------
perform_rollback() {
    local log_file="${1:-}"
    local log_dir="/var/log/hardening"
    local services_to_restart=()

    if [[ -z "${log_file}" ]]; then
        log_file=$(ls -t "${log_dir}"/rollback-*.log 2>/dev/null | head -1 || true)
    fi

    if [[ -z "${log_file}" || ! -f "${log_file}" ]]; then
        print_error "No rollback log found. Nothing to roll back."
        exit 1
    fi

    print_section "Rolling back changes from: ${log_file}"

    local count=0
    local errors=0

    # Process rollback commands in reverse order
    tac "${log_file}" | while IFS='|' read -r description rollback_cmd; do
        rollback_cmd=$(echo "${rollback_cmd}" | sed 's/^[[:space:]]*ROLLBACK:[[:space:]]*//')

        if [[ -z "${rollback_cmd}" ]]; then
            continue
        fi

        description=$(echo "${description}" | sed 's/^\[.*\][[:space:]]*//')
        print_info "Reverting: ${description}"

        if eval "${rollback_cmd}" 2>/dev/null; then
            print_ok "Reverted successfully"
            count=$((count + 1))
        else
            print_warning "Failed to revert: ${description}"
            errors=$((errors + 1))
        fi

        # Track services that may need restarting
        if echo "${description}" | grep -qi "sshd\|ssh"; then
            services_to_restart+=("sshd")
        fi
        if echo "${description}" | grep -qi "ufw\|firewall"; then
            services_to_restart+=("ufw")
        fi
        if echo "${description}" | grep -qi "auditd\|audit"; then
            services_to_restart+=("auditd")
        fi
        if echo "${description}" | grep -qi "rsyslog\|syslog"; then
            services_to_restart+=("rsyslog")
        fi
        if echo "${description}" | grep -qi "fail2ban"; then
            services_to_restart+=("fail2ban")
        fi
    done

    # Restart affected services
    print_section "Restarting affected services"
    local unique_services
    unique_services=$(echo "${services_to_restart[@]:-}" | tr ' ' '\n' | sort -u)

    for svc in ${unique_services}; do
        if systemctl is-active --quiet "${svc}" 2>/dev/null || systemctl is-enabled --quiet "${svc}" 2>/dev/null; then
            print_info "Restarting ${svc}..."
            systemctl restart "${svc}" 2>/dev/null && print_ok "${svc} restarted" || print_warning "Failed to restart ${svc}"
        fi
    done

    # Reload sysctl if kernel params were changed
    if grep -qi "sysctl\|kernel" "${log_file}" 2>/dev/null; then
        print_info "Reloading sysctl settings..."
        sysctl --system >/dev/null 2>&1 && print_ok "sysctl reloaded" || print_warning "Failed to reload sysctl"
    fi

    print_section "Rollback Summary"
    print_ok "Rollback complete. Review system state and test connectivity."
    print_warning "You may need to manually verify some changes."
    echo ""
}
