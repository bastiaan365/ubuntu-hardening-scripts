#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# filesystem.sh - Filesystem hardening module
# ============================================================

harden_filesystem() {
    print_section "Filesystem Hardening"

    # Set noexec,nosuid,nodev on /tmp
    local fstab="/etc/fstab"

    if dry_run_msg "Would set noexec,nosuid,nodev mount options on /tmp"; then
        :
    else
        backup_file "${fstab}"

        if grep -q "/tmp" "${fstab}"; then
            # Update existing /tmp entry
            sed -i '/\/tmp/ s/defaults/defaults,noexec,nosuid,nodev/' "${fstab}" 2>/dev/null || true
            log_change "Added noexec,nosuid,nodev to /tmp in fstab" ""
        else
            # Add /tmp entry if it does not exist
            echo "tmpfs /tmp tmpfs defaults,noexec,nosuid,nodev,size=2G 0 0" >> "${fstab}"
            log_change "Added /tmp tmpfs entry with noexec,nosuid,nodev to fstab" ""
        fi

        # Remount /tmp with new options
        mount -o remount /tmp 2>/dev/null || print_warning "Could not remount /tmp (may need reboot)"
    fi

    # Set proper permissions on sensitive files
    local -A file_perms=(
        ["/etc/passwd"]="644"
        ["/etc/passwd-"]="600"
        ["/etc/shadow"]="640"
        ["/etc/shadow-"]="640"
        ["/etc/group"]="644"
        ["/etc/group-"]="600"
        ["/etc/gshadow"]="640"
        ["/etc/gshadow-"]="640"
        ["/etc/crontab"]="600"
    )

    for file in "${!file_perms[@]}"; do
        local perm="${file_perms[${file}]}"
        if [[ -f "${file}" ]]; then
            if dry_run_msg "Would set ${file} permissions to ${perm}"; then
                :
            else
                local current_perm
                current_perm=$(stat -c "%a" "${file}")
                chmod "${perm}" "${file}"
                chown root:root "${file}" 2>/dev/null || true
                log_change "Set ${file} permissions to ${perm} (was ${current_perm})" "chmod ${current_perm} ${file}"
            fi
        fi
    done

    # Ensure /etc/shadow is owned by root:shadow
    if [[ -f /etc/shadow ]]; then
        if dry_run_msg "Would set /etc/shadow ownership to root:shadow"; then
            :
        else
            chown root:shadow /etc/shadow 2>/dev/null || chown root:root /etc/shadow
            log_change "Set /etc/shadow ownership to root:shadow" ""
        fi
    fi

    # Disable automounting
    if dry_run_msg "Would disable automounting (autofs)"; then
        :
    else
        if systemctl is-enabled autofs 2>/dev/null | grep -q "enabled"; then
            systemctl stop autofs 2>/dev/null || true
            systemctl disable autofs 2>/dev/null || true
            log_change "Disabled autofs automounting" "systemctl enable autofs && systemctl start autofs"
        else
            print_status "SKIP" "autofs is already disabled or not installed"
        fi
    fi

    # Restrict world-writable directories with sticky bit check
    if dry_run_msg "Would check world-writable directories for sticky bit"; then
        :
    else
        print_info "Checking world-writable directories..."
        local found_issues=false
        while IFS= read -r dir; do
            if [[ -d "${dir}" ]]; then
                chmod +t "${dir}" 2>/dev/null || true
                found_issues=true
            fi
        done < <(find / -xdev -type d \( -perm -0002 -a ! -perm -1000 \) 2>/dev/null || true)

        if [[ "${found_issues}" == "true" ]]; then
            log_change "Set sticky bit on world-writable directories" ""
        else
            print_status "SKIP" "All world-writable directories already have sticky bit"
        fi
    fi

    print_ok "Filesystem hardening complete"
}
