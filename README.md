# 🛡️ Ubuntu Hardening Scripts

Automated security hardening for Ubuntu/Debian systems with built-in rollback capability. Designed for both homelab and production environments.

## ✨ Features

- One-command hardening — Run a single script to apply all security measures
- Rollback support — Every change is logged and reversible
- CIS benchmark aligned — Based on CIS Ubuntu Linux Benchmark
- Modular design — Enable/disable individual hardening modules
- Logging — Full audit trail of all changes made

## 🔧 What it hardens

| Module | Description |
|---|---|
| SSH | Key-only auth, disable root login, custom port, fail2ban |
| Firewall | UFW configuration with minimal open ports |
| Kernel | Sysctl hardening (network, memory, filesystem) |
| Users | Password policies, sudo configuration, unused accounts |
| Services | Disable unnecessary services, remove unused packages |
| Filesystem | Secure mount options, tmp hardening, file permissions |
| Logging | Auditd rules, centralized syslog forwarding |
| Updates | Unattended security updates configuration |

## 🚀 Quick Start

```bash
git clone https://github.com/bastiaan365/ubuntu-hardening-scripts.git
cd ubuntu-hardening-scripts
chmod +x harden.sh
sudo ./harden.sh --dry-run    # Preview changes
sudo ./harden.sh              # Apply hardening
sudo ./harden.sh --rollback   # Revert all changes
```

## 📋 Requirements

- Ubuntu 22.04 / 24.04 LTS or Debian 12+
- Root or sudo access
- Bash 5.0+

## ⚙️ Configuration

Edit config.yml to customize:
- SSH port number
- Allowed users/groups
- Firewall rules
- Syslog server address
- Enable/disable specific modules

## 🔗 Related

- [Homelab Infrastructure](https://github.com/bastiaan365/homelab-infrastructure) — Where these scripts are deployed
- [bastiaan365.com](https://bastiaan365.com) — Full write-up of my security homelab

---

Scripts are tested on Ubuntu 22.04 and 24.04 LTS. Use at your own risk — always test in a non-production environment first.
