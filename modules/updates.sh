#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# updates.sh - Automatic updates module
# ============================================================

harden_updates() {
    print_section "Automatic Updates Configuration"

    local unattended
    unattended=$(parse_config "unattended_upgrades")

    if [[ "${unattended}" != "true" ]]; then
        print_status "SKIP" "Unattended upgrades disabled in config"
        return
    fi

    # Install unattended-upgrades
    if dry_run_msg "Would install and configure unattended-upgrades"; then
        echo "  - Enable security updates only"
        echo "  - Enable automatic reboot if needed"
        echo "  - Configure reboot time to 03:00"
        return
    fi

    if ! dpkg -l unattended-upgrades 2>/dev/null | grep -q "^ii"; then
        apt-get install -y unattended-upgrades >/dev/null 2>&1
        log_change "Installed unattended-upgrades" "apt-get remove -y unattended-upgrades"
    fi

    # Configure for security updates only
    local auto_upgrades="/etc/apt/apt.conf.d/20auto-upgrades"
    backup_file "${auto_upgrades}" 2>/dev/null || true

    cat > "${auto_upgrades}" <<'AUTOUPGRADES'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
AUTOUPGRADES

    log_change "Configured automatic package list updates" "rm -f ${auto_upgrades}"

    # Configure unattended-upgrades settings
    local unattended_conf="/etc/apt/apt.conf.d/50unattended-upgrades"
    backup_file "${unattended_conf}" 2>/dev/null || true

    cat > "${unattended_conf}" <<'UNATTENDED'
// Ubuntu Hardening Scripts - Unattended Upgrades Configuration

Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}-security";
    "${distro_id}ESMApps:${distro_codename}-apps-security";
    "${distro_id}ESM:${distro_codename}-infra-security";
};

// Remove unused kernel packages
Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";

// Remove unused dependencies
Unattended-Upgrade::Remove-Unused-Dependencies "true";

// Enable automatic reboot if required
Unattended-Upgrade::Automatic-Reboot "true";

// Set reboot time
Unattended-Upgrade::Automatic-Reboot-Time "03:00";

// Enable syslog logging
Unattended-Upgrade::SyslogEnable "true";

// Do not install packages on shutdown
Unattended-Upgrade::InstallOnShutdown "false";
UNATTENDED

    log_change "Configured unattended-upgrades for security updates" ""

    # Enable the timer
    systemctl enable apt-daily.timer >/dev/null 2>&1
    systemctl enable apt-daily-upgrade.timer >/dev/null 2>&1
    log_change "Enabled apt-daily and apt-daily-upgrade timers" ""

    print_ok "Automatic updates configuration complete"
}
