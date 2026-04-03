#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# services.sh - Service hardening module
# ============================================================

harden_services() {
    print_section "Service Hardening"

    # List of unnecessary services to disable
    local unnecessary_services=(
        "cups"
        "cups-browsed"
        "avahi-daemon"
        "rpcbind"
        "rpc-statd"
        "nfs-common"
    )

    # Disable unnecessary services
    for svc in "${unnecessary_services[@]}"; do
        if systemctl is-enabled "${svc}" 2>/dev/null | grep -q "enabled"; then
            if dry_run_msg "Would disable service: ${svc}"; then
                :
            else
                systemctl stop "${svc}" 2>/dev/null || true
                systemctl disable "${svc}" 2>/dev/null || true
                systemctl mask "${svc}" 2>/dev/null || true
                log_change "Disabled and masked service: ${svc}" "systemctl unmask ${svc} && systemctl enable ${svc}"
            fi
        else
            print_status "SKIP" "Service ${svc} is already disabled or not installed"
        fi
    done

    # Remove unnecessary packages
    local unnecessary_packages=(
        "telnet"
        "nis"
        "rsh-client"
        "rsh-server"
        "talk"
        "talkd"
    )

    for pkg in "${unnecessary_packages[@]}"; do
        if dpkg -l "${pkg}" 2>/dev/null | grep -q "^ii"; then
            if dry_run_msg "Would remove package: ${pkg}"; then
                :
            else
                apt-get remove -y "${pkg}" >/dev/null 2>&1
                log_change "Removed package: ${pkg}" "apt-get install -y ${pkg}"
            fi
        else
            print_status "SKIP" "Package ${pkg} is not installed"
        fi
    done

    # Disable USB storage module
    if dry_run_msg "Would disable USB storage kernel module"; then
        :
    else
        local usb_conf="/etc/modprobe.d/disable-usb-storage.conf"
        backup_file "${usb_conf}" 2>/dev/null || true
        echo "install usb-storage /bin/true" > "${usb_conf}"
        echo "blacklist usb-storage" >> "${usb_conf}"
        log_change "Disabled USB storage kernel module" "rm -f ${usb_conf}"

        # Unload module if currently loaded
        if lsmod | grep -q "usb_storage"; then
            rmmod usb_storage 2>/dev/null || print_warning "Could not unload usb_storage module (may be in use)"
        fi
    fi

    print_ok "Service hardening complete"
}
