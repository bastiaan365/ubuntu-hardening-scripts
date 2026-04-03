#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# firewall.sh - UFW firewall hardening module
# ============================================================

harden_firewall() {
    print_section "Firewall Hardening (UFW)"

    local allowed_ports
    local ssh_port
    allowed_ports=$(parse_config "firewall_allowed_ports")
    ssh_port=$(parse_config "ssh_port")

    # Install UFW if not present
    if ! command -v ufw &>/dev/null; then
        if dry_run_msg "Would install ufw"; then
            :
        else
            apt-get install -y ufw >/dev/null 2>&1
            log_change "Installed ufw" "apt-get remove -y ufw"
        fi
    fi

    # Set default policies
    if dry_run_msg "Would set UFW default deny incoming, allow outgoing"; then
        :
    else
        ufw default deny incoming >/dev/null 2>&1
        ufw default allow outgoing >/dev/null 2>&1
        log_change "Set UFW default deny incoming, allow outgoing" ""
    fi

    # Allow configured ports
    if [[ -n "${allowed_ports}" ]]; then
        for port in ${allowed_ports}; do
            if dry_run_msg "Would allow port ${port}/tcp"; then
                :
            else
                ufw allow "${port}/tcp" >/dev/null 2>&1
                log_change "Allowed port ${port}/tcp in UFW" "ufw delete allow ${port}/tcp"
            fi
        done
    fi

    # Rate limit SSH port
    local effective_ssh_port="${ssh_port:-22}"
    if dry_run_msg "Would rate-limit SSH port ${effective_ssh_port}"; then
        :
    else
        ufw limit "${effective_ssh_port}/tcp" >/dev/null 2>&1
        log_change "Rate-limited SSH port ${effective_ssh_port}/tcp" ""
    fi

    # Enable logging
    if dry_run_msg "Would enable UFW logging"; then
        :
    else
        ufw logging on >/dev/null 2>&1
        log_change "Enabled UFW logging" "ufw logging off"
    fi

    # Enable UFW
    if dry_run_msg "Would enable UFW"; then
        :
    else
        echo "y" | ufw enable >/dev/null 2>&1
        log_change "Enabled UFW firewall" "ufw disable"
        print_ok "Firewall hardening complete"
    fi
}
