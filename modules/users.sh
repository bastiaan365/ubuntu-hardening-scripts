#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# users.sh - User security hardening module
# ============================================================

harden_users() {
    print_section "User Security Hardening"

    # Set password aging policies
    local login_defs="/etc/login.defs"

    if dry_run_msg "Would set password aging policies in ${login_defs}"; then
        echo "  - PASS_MAX_DAYS=90"
        echo "  - PASS_MIN_DAYS=7"
        echo "  - PASS_WARN_AGE=14"
    else
        backup_file "${login_defs}"

        sed -i 's/^PASS_MAX_DAYS.*/PASS_MAX_DAYS   90/' "${login_defs}"
        sed -i 's/^PASS_MIN_DAYS.*/PASS_MIN_DAYS   7/' "${login_defs}"
        sed -i 's/^PASS_WARN_AGE.*/PASS_WARN_AGE   14/' "${login_defs}"

        log_change "Set password aging: MAX=90, MIN=7, WARN=14" ""
    fi

    # Set UMASK to 027
    if dry_run_msg "Would set default UMASK to 027"; then
        :
    else
        if grep -q "^UMASK" "${login_defs}"; then
            sed -i 's/^UMASK.*/UMASK           027/' "${login_defs}"
        fi
        log_change "Set UMASK to 027 in login.defs" ""
    fi

    # Lock unused system accounts
    if dry_run_msg "Would lock unused system accounts"; then
        :
    else
        local locked_count=0
        while IFS=: read -r username _ uid _ _ _ shell; do
            # Lock system accounts (UID < 1000) that have a login shell
            # Skip root, sync, shutdown, halt
            if [[ "${uid}" -lt 1000 && "${uid}" -gt 0 ]]; then
                if [[ "${shell}" != "/usr/sbin/nologin" && "${shell}" != "/bin/false" && "${shell}" != "/sbin/nologin" ]]; then
                    case "${username}" in
                        sync|shutdown|halt|daemon|bin|sys|games|man|lp|mail|news|uucp|proxy|www-data|backup|list|irc|nobody)
                            usermod -s /usr/sbin/nologin "${username}" 2>/dev/null && locked_count=$((locked_count + 1))
                            ;;
                    esac
                fi
            fi
        done < /etc/passwd

        if [[ ${locked_count} -gt 0 ]]; then
            log_change "Set nologin shell on ${locked_count} unused system accounts" ""
        else
            print_status "SKIP" "No unused system accounts to lock"
        fi
    fi

    # Configure sudo hardening
    if dry_run_msg "Would configure sudo hardening (use_pty, remove NOPASSWD)"; then
        :
    else
        local sudoers_hardening="/etc/sudoers.d/99-hardening"
        backup_file "${sudoers_hardening}" 2>/dev/null || true

        cat > "${sudoers_hardening}" <<'SUDOERS'
# Hardening: Require pseudo-terminal for sudo
Defaults use_pty

# Hardening: Log sudo commands
Defaults logfile="/var/log/sudo.log"

# Hardening: Set secure path
Defaults secure_path="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

# Hardening: Require password timeout
Defaults timestamp_timeout=5
SUDOERS

        chmod 0440 "${sudoers_hardening}"
        # Validate sudoers syntax
        if visudo -cf "${sudoers_hardening}" >/dev/null 2>&1; then
            log_change "Created sudo hardening config" "rm -f ${sudoers_hardening}"
        else
            rm -f "${sudoers_hardening}"
            print_warning "Sudo hardening config had syntax errors, removed"
        fi

        # Warn about NOPASSWD entries
        if grep -r "NOPASSWD" /etc/sudoers /etc/sudoers.d/ 2>/dev/null | grep -v "^#" | grep -v "99-hardening" >/dev/null 2>&1; then
            print_warning "NOPASSWD entries found in sudoers. Review and remove for better security."
        fi
    fi

    # Set default shell timeout
    if dry_run_msg "Would set shell timeout (TMOUT=900)"; then
        :
    else
        local profile_hardening="/etc/profile.d/99-hardening.sh"
        backup_file "${profile_hardening}" 2>/dev/null || true
        cat > "${profile_hardening}" <<'PROFILE'
# Hardening: Auto-logout after 15 minutes of inactivity
readonly TMOUT=900
export TMOUT
PROFILE
        log_change "Set shell TMOUT=900 (15 min auto-logout)" "rm -f ${profile_hardening}"
    fi

    print_ok "User security hardening complete"
}
