#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# ssh.sh - SSH hardening module
# ============================================================

harden_ssh() {
    print_section "SSH Hardening"

    local sshd_config="/etc/ssh/sshd_config"
    local ssh_port
    local allowed_users
    local allowed_groups

    ssh_port=$(parse_config "ssh_port")
    allowed_users=$(parse_config "allowed_users")
    allowed_groups=$(parse_config "allowed_groups")

    # Backup sshd_config
    if dry_run_msg "Would back up ${sshd_config}"; then
        :
    else
        backup_file "${sshd_config}"
    fi

    # Disable root login
    if dry_run_msg "Would disable root login via SSH"; then
        :
    else
        sed -i 's/^#*PermitRootLogin.*/PermitRootLogin no/' "${sshd_config}"
        log_change "Disabled SSH root login" ""
    fi

    # Disable password authentication
    if dry_run_msg "Would disable password authentication"; then
        :
    else
        sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' "${sshd_config}"
        log_change "Disabled SSH password authentication" ""
    fi

    # Set custom SSH port
    if [[ -n "${ssh_port}" ]]; then
        if dry_run_msg "Would set SSH port to ${ssh_port}"; then
            :
        else
            sed -i "s/^#*Port.*/Port ${ssh_port}/" "${sshd_config}"
            # If no Port line exists, add one
            if ! grep -q "^Port " "${sshd_config}"; then
                echo "Port ${ssh_port}" >> "${sshd_config}"
            fi
            log_change "Set SSH port to ${ssh_port}" ""
        fi
    fi

    # Set MaxAuthTries
    if dry_run_msg "Would set MaxAuthTries to 3"; then
        :
    else
        if grep -q "^#*MaxAuthTries" "${sshd_config}"; then
            sed -i 's/^#*MaxAuthTries.*/MaxAuthTries 3/' "${sshd_config}"
        else
            echo "MaxAuthTries 3" >> "${sshd_config}"
        fi
        log_change "Set MaxAuthTries to 3" ""
    fi

    # Set ClientAliveInterval and ClientAliveCountMax
    if dry_run_msg "Would set ClientAliveInterval to 300"; then
        :
    else
        if grep -q "^#*ClientAliveInterval" "${sshd_config}"; then
            sed -i 's/^#*ClientAliveInterval.*/ClientAliveInterval 300/' "${sshd_config}"
        else
            echo "ClientAliveInterval 300" >> "${sshd_config}"
        fi
        if grep -q "^#*ClientAliveCountMax" "${sshd_config}"; then
            sed -i 's/^#*ClientAliveCountMax.*/ClientAliveCountMax 2/' "${sshd_config}"
        else
            echo "ClientAliveCountMax 2" >> "${sshd_config}"
        fi
        log_change "Set ClientAliveInterval=300, ClientAliveCountMax=2" ""
    fi

    # Disable X11 forwarding
    if dry_run_msg "Would disable X11 forwarding"; then
        :
    else
        sed -i 's/^#*X11Forwarding.*/X11Forwarding no/' "${sshd_config}"
        log_change "Disabled X11 forwarding" ""
    fi

    # Restrict to allowed users
    if [[ -n "${allowed_users}" ]]; then
        if dry_run_msg "Would restrict SSH to users: ${allowed_users}"; then
            :
        else
            local user_list
            user_list=$(echo "${allowed_users}" | tr '\n' ' ')
            # Remove existing AllowUsers line
            sed -i '/^AllowUsers/d' "${sshd_config}"
            echo "AllowUsers ${user_list}" >> "${sshd_config}"
            log_change "Restricted SSH to users: ${user_list}" ""
        fi
    fi

    # Restrict to allowed groups
    if [[ -n "${allowed_groups}" ]]; then
        if dry_run_msg "Would restrict SSH to groups: ${allowed_groups}"; then
            :
        else
            local group_list
            group_list=$(echo "${allowed_groups}" | tr '\n' ' ')
            sed -i '/^AllowGroups/d' "${sshd_config}"
            echo "AllowGroups ${group_list}" >> "${sshd_config}"
            log_change "Restricted SSH to groups: ${group_list}" ""
        fi
    fi

    # Install and configure fail2ban
    if dry_run_msg "Would install and configure fail2ban"; then
        :
    else
        if ! command -v fail2ban-server &>/dev/null; then
            apt-get install -y fail2ban >/dev/null 2>&1
            log_change "Installed fail2ban" "apt-get remove -y fail2ban"
        fi

        local jail_local="/etc/fail2ban/jail.local"
        if [[ ! -f "${jail_local}" ]]; then
            cat > "${jail_local}" <<FAIL2BAN
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 3

[sshd]
enabled = true
port = ${ssh_port:-22}
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
FAIL2BAN
            log_change "Created fail2ban jail.local" "rm -f ${jail_local}"
        fi

        systemctl enable fail2ban >/dev/null 2>&1
        systemctl restart fail2ban >/dev/null 2>&1
        log_change "Enabled and started fail2ban" ""
    fi

    # Restart SSH service
    if dry_run_msg "Would restart sshd"; then
        :
    else
        systemctl restart sshd 2>/dev/null || systemctl restart ssh 2>/dev/null || true
        print_ok "SSH hardening complete"
    fi
}
