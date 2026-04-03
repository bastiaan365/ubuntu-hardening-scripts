#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# kernel.sh - Kernel/sysctl hardening module
# ============================================================

harden_kernel() {
    print_section "Kernel Hardening (sysctl)"

    local sysctl_conf="/etc/sysctl.d/99-hardening.conf"

    if dry_run_msg "Would create ${sysctl_conf} with hardened kernel parameters"; then
        echo "  - Disable IP forwarding"
        echo "  - Disable source routing"
        echo "  - Disable ICMP redirects"
        echo "  - Enable SYN cookies"
        echo "  - Enable reverse path filtering"
        echo "  - Disable core dumps"
        echo "  - Restrict dmesg and kernel pointers"
        return
    fi

    backup_file "${sysctl_conf}" 2>/dev/null || true

    cat > "${sysctl_conf}" <<'SYSCTL'
# Ubuntu Hardening Scripts - Kernel Parameters
# Based on CIS Benchmark recommendations

# Disable IP forwarding
net.ipv4.ip_forward = 0
net.ipv6.conf.all.forwarding = 0

# Disable source routing
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0
net.ipv6.conf.default.accept_source_route = 0

# Disable ICMP redirects
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0

# Enable SYN cookies (SYN flood protection)
net.ipv4.tcp_syncookies = 1

# Enable reverse path filtering
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1

# Log martian packets
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1

# Ignore ICMP broadcast requests
net.ipv4.icmp_echo_ignore_broadcasts = 1

# Ignore bogus ICMP error responses
net.ipv4.icmp_ignore_bogus_error_responses = 1

# Disable core dumps
fs.suid_dumpable = 0

# Restrict dmesg access
kernel.dmesg_restrict = 1

# Restrict kernel pointer exposure
kernel.kptr_restrict = 2

# Restrict access to kernel logs
kernel.printk = 3 3 3 3

# Enable ASLR
kernel.randomize_va_space = 2

# Restrict ptrace scope
kernel.yama.ptrace_scope = 1
SYSCTL

    log_change "Created hardened sysctl config at ${sysctl_conf}" "rm -f ${sysctl_conf} && sysctl --system"

    # Apply sysctl settings
    sysctl --system >/dev/null 2>&1
    log_change "Applied sysctl hardening parameters" ""

    # Disable core dumps via limits.conf
    local limits_conf="/etc/security/limits.d/99-hardening.conf"
    backup_file "${limits_conf}" 2>/dev/null || true
    echo "* hard core 0" > "${limits_conf}"
    log_change "Disabled core dumps via limits.conf" "rm -f ${limits_conf}"

    print_ok "Kernel hardening complete"
}
