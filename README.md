# 🛡️ Ubuntu Hardening Scripts

Automated security hardening for Ubuntu/Debian systems, with rollback support built in from the start. Covers SSH, firewall, kernel parameters, unused services, filesystem permissions, and logging.

I got tired of manually applying CIS benchmark recommendations every time I spun up a new box — especially since half the steps are things I'd forget or apply inconsistently. This script does it reproducibly in one run and keeps a log of every change made so you can actually reverse it if something breaks.

Tested on Ubuntu 22.04 and 24.04 LTS. I use it on the Linux nodes in my homelab and ran a version of it in a healthcare IT environment (NEN 7510 compliance work).

## ✨ What it hardens

| Module | What changes |
|---|---|
| SSH | Key-only auth, root login disabled, custom port, fail2ban |
| Firewall | UFW with minimal open ports — deny all inbound by default |
| Kernel | Sysctl hardening: IP forwarding, ICMP redirects, TCP timestamps |
| Users | Password policy, sudo configuration, removes unused accounts |
| Services | Disables unnecessary services (cups, avahi, etc.), removes unused packages |
| Filesystem | Secure /tmp and /var/tmp, restrictive umask, noexec mounts |
| Logging | Auditd rules, syslog forwarding to central collector |
| Updates | Unattended security updates, automatic reboot config |

## 🚀 Quick start

```bash
git clone https://github.com/bastiaan365/ubuntu-hardening-scripts.git
cd ubuntu-hardening-scripts
chmod +x harden.sh

# Always run dry-run first — shows you exactly what will change
sudo ./harden.sh --dry-run

# Apply hardening
sudo ./harden.sh

# If something breaks:
sudo ./harden.sh --rollback
```

## ⚙️ Configuration

Edit `config.yml` before running. Main things to set:

- SSH port (default: 22 — change this)
- Allowed users/groups for sudo
- Syslog server address if you have a central collector
- Which modules to enable/disable (some things you might not want, like changing the SSH port on a cloud VM with no console access)

## 📋 Requirements

- Ubuntu 22.04 / 24.04 LTS or Debian 12+
- Root or sudo access
- Bash 5.0+

## Why rollback matters

Every change is logged to `/var/log/hardening-changes.log` before being applied. The rollback flag reads that log and reverses each change in order. I added this after locking myself out of a test VM by applying SSH hardening without thinking through the implications for key-based auth first.

The rollback isn't magic — if you run it weeks later after other changes, results may vary. Use it as a safety net for "I just ran this and something's wrong" situations, not as a substitute for snapshots/backups.

## 📁 Structure

```
├── harden.sh           # Main entrypoint
├── config.yml          # Configuration
├── lib/
│   ├── common.sh       # Shared utilities
│   └── rollback.sh     # Rollback engine
└── modules/
    ├── ssh.sh
    ├── firewall.sh
    ├── kernel.sh
    ├── users.sh
    ├── services.sh
    ├── filesystem.sh
    ├── logging.sh
    └── updates.sh
```

## 🔗 Related

- [Homelab infrastructure](https://github.com/bastiaan365/homelab-infrastructure) — where these run
- [bastiaan365.com](https://bastiaan365.com) — write-up on the hardening approach

> Use at your own risk. Always test in a non-production environment first. Some modules (especially firewall and SSH) can lock you out if misconfigured.
