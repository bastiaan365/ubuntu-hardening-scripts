#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# logging.sh - Logging and auditing module
# ============================================================

harden_logging() {
    print_section "Logging and Audit Hardening"

    local syslog_server
    syslog_server=$(parse_config "syslog_server")

    # Install auditd
    if ! command -v auditd &>/dev/null; then
        if dry_run_msg "Would install auditd and audispd-plugins"; then
            :
        else
            apt-get install -y auditd audispd-plugins >/dev/null 2>&1
            log_change "Installed auditd and audispd-plugins" "apt-get remove -y auditd audispd-plugins"
        fi
    fi

    # Configure audit rules
    local audit_rules="/etc/audit/rules.d/99-hardening.rules"

    if dry_run_msg "Would create audit rules at ${audit_rules}"; then
        echo "  - Monitor file access to sensitive files"
        echo "  - Monitor user/group changes"
        echo "  - Monitor network configuration changes"
        echo "  - Monitor login/logout events"
    else
        backup_file "${audit_rules}" 2>/dev/null || true

        cat > "${audit_rules}" <<'AUDITRULES'
# Ubuntu Hardening Scripts - Audit Rules

# Monitor changes to user/group files
-w /etc/passwd -p wa -k identity
-w /etc/group -p wa -k identity
-w /etc/shadow -p wa -k identity
-w /etc/gshadow -p wa -k identity
-w /etc/security/opasswd -p wa -k identity

# Monitor changes to network configuration
-w /etc/hosts -p wa -k network-config
-w /etc/sysconfig/network -p wa -k network-config
-w /etc/network/ -p wa -k network-config
-w /etc/netplan/ -p wa -k network-config

# Monitor changes to system configuration
-w /etc/sysctl.conf -p wa -k sysctl-changes
-w /etc/sysctl.d/ -p wa -k sysctl-changes

# Monitor SSH configuration changes
-w /etc/ssh/sshd_config -p wa -k sshd-config

# Monitor sudo and sudoers changes
-w /etc/sudoers -p wa -k sudoers
-w /etc/sudoers.d/ -p wa -k sudoers

# Monitor login/logout events
-w /var/log/auth.log -p wa -k auth-log
-w /var/log/faillog -p wa -k login-failures
-w /var/log/lastlog -p wa -k login-records
-w /var/log/wtmp -p wa -k login-records
-w /var/log/btmp -p wa -k login-records

# Monitor cron configuration
-w /etc/crontab -p wa -k cron
-w /etc/cron.d/ -p wa -k cron
-w /etc/cron.daily/ -p wa -k cron
-w /etc/cron.hourly/ -p wa -k cron
-w /etc/cron.weekly/ -p wa -k cron
-w /etc/cron.monthly/ -p wa -k cron

# Monitor kernel module loading
-w /sbin/insmod -p x -k kernel-modules
-w /sbin/rmmod -p x -k kernel-modules
-w /sbin/modprobe -p x -k kernel-modules

# Monitor time changes
-a always,exit -F arch=b64 -S adjtimex -S settimeofday -k time-change
-a always,exit -F arch=b32 -S adjtimex -S settimeofday -k time-change
-w /etc/localtime -p wa -k time-change

# Ensure auditd configuration is immutable (must be last rule)
-e 2
AUDITRULES

        log_change "Created audit rules at ${audit_rules}" "rm -f ${audit_rules}"

        # Enable and restart auditd
        systemctl enable auditd >/dev/null 2>&1
        systemctl restart auditd >/dev/null 2>&1 || service auditd restart 2>/dev/null || true
        log_change "Enabled and restarted auditd" ""
    fi

    # Configure rsyslog forwarding if syslog_server is set
    if [[ -n "${syslog_server}" ]]; then
        if dry_run_msg "Would configure rsyslog forwarding to ${syslog_server}"; then
            :
        else
            local rsyslog_conf="/etc/rsyslog.d/99-forwarding.conf"
            backup_file "${rsyslog_conf}" 2>/dev/null || true

            cat > "${rsyslog_conf}" <<RSYSLOG
# Ubuntu Hardening Scripts - Syslog Forwarding
# Forward all logs to central syslog server
*.* @@${syslog_server}:514
RSYSLOG

            log_change "Configured rsyslog forwarding to ${syslog_server}" "rm -f ${rsyslog_conf}"

            systemctl restart rsyslog >/dev/null 2>&1
            log_change "Restarted rsyslog with forwarding" ""
        fi
    else
        print_status "SKIP" "No syslog_server configured, skipping remote logging"
    fi

    print_ok "Logging and audit hardening complete"
}
