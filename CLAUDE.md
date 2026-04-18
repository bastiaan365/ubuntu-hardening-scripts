# ubuntu-hardening-scripts

Modular Ubuntu/Debian hardening with rollback support. Tested on Ubuntu 22.04 and 24.04 LTS. Maintained by Bastiaan ([@bastiaan365](https://github.com/bastiaan365)).

This file scopes Claude's behaviour for this repo. The global `~/.claude/CLAUDE.md` covers personal conventions; everything below is repo-specific.

## What this repo is

- A **deployable, security-critical** hardening script that other operators will run as `sudo` on their boxes.
- The single most invasive repo in the portfolio: changes sshd config, kernel sysctls, firewall rules, package set, sudo config, filesystem mount options. Bad change here = locked-out box for someone.
- Rollback is a **first-class concern**, not a nice-to-have. Any change that doesn't have a rollback path is a regression.

The bar for breakage is correspondingly high. **Mistakes here cost real recovery time** (console access, single-user mode boots, full reinstalls).

## Repo conventions

### Structure

```
harden.sh             top-level entry: --dry-run, --rollback, --modules <comma-list>
lib/
├── common.sh         logging helpers, change-log writer, config parser
└── rollback.sh       reads /var/log/hardening-changes.log and reverses entries
modules/
├── firewall.sh       UFW config, default-deny, allow rules from config.yml
├── ssh.sh            sshd hardening (key-only, no root, custom port, fail2ban)
├── kernel.sh         sysctl hardening (IP forwarding, ICMP redirects, TCP)
├── users.sh          password policy, sudo config, unused account removal
├── services.sh       disable unnecessary services + remove unused packages
├── filesystem.sh     /tmp + /var/tmp mount opts, restrictive umask
├── logging.sh        auditd rules, syslog forwarding
└── updates.sh        unattended-upgrades + automatic reboot config
config.yml            user configuration (SSH port, sudo users, syslog target, module enable/disable)
```

A new module is: a `modules/<name>.sh` file + a corresponding rollback path in `lib/rollback.sh` + an entry in `config.yml` + a row in the README's hardening table.

### Shell script standards (non-negotiable)

- `set -euo pipefail` at the top of every `.sh` file in the repo.
- Pass `shellcheck -S warning` cleanly. **Run `shellcheck harden.sh lib/*.sh modules/*.sh` before any commit that touches any `.sh` file.**
- `bash -n` parses cleanly on every `.sh` file (catches syntax errors `shellcheck` may miss).
- Every destructive operation in a module **must** log to `/var/log/hardening-changes.log` via `common.sh`'s `log_change` helper **before** executing, so rollback can find it.
- Every module **must** support `--dry-run` — no exceptions. The user previewing before applying is the difference between this script being useful and being dangerous.
- No `curl ... | sh` patterns. Download to a file, verify (sha256 ideally), then execute.
- No `sed -i` without a backup suffix. `sed -i.bak` always.
- Modules must be **idempotent** — running twice produces the same result, no errors.

### Rollback discipline

- Every module change must have a paired entry in `lib/rollback.sh` that reverses it.
- The `log_change` helper writes a structured line — keep the format stable (rollback parses it).
- If a change cannot be rolled back (e.g. a deleted package's config files are gone), the module **must** print a clear warning to the user before proceeding. No silent "this is irreversible" surprises.
- `harden.sh --rollback` is the documented escape hatch. Test it after every module change.

### Configuration

- `config.yml` is the only place users should need to edit. No editing scripts directly.
- All hardcodable values (SSH port, syslog server, sudo group name) come from config.yml via `lib/common.sh`'s parser.
- New module options go in `config.yml` under the module's section, with sensible safe defaults that work on a fresh Ubuntu install.

### Validation gates

Before any commit that touches code:

- `shellcheck -S warning harden.sh lib/*.sh modules/*.sh`
- `bash -n harden.sh lib/*.sh modules/*.sh` (syntax check)
- `sudo ./harden.sh --dry-run` runs to completion without errors. Don't run non-dry on niborserver — niborserver is the production homelab and is **not** a hardening test target. Use a throwaway VM for live tests.
- `yamllint config.yml` if yamllint is installed.
- **Leak grep**: same shape as `dns-security-setup`:

  ```bash
  grep -REn '192\.168\.|10\.[0-9]+\.|172\.(1[6-9]|2[0-9]|3[0-1])\.|niborserver|Nibordooh|OPNsense-Gateway\.home\.arpa' \
    harden.sh lib/ modules/ config.yml README.md \
    | grep -vE '"version"\s*:\s*"|^[^:]+:[0-9]+:\s*##|^[^:]+:[0-9]+:\s*#|10\.0\.0\.0/8|172\.16\.0\.0/12|192\.168\.0\.0/16'
  ```

### Dogfooding on openclaw

Openclaw is a valid live-test target (expendable per global `~/.claude/CLAUDE.md`), unlike niborserver. But it's a VPS with no hypervisor console from my side — a broken `ssh.sh` or `firewall.sh` run means provider-panel recovery.

- **Safe to run live on openclaw**: `kernel.sh`, `filesystem.sh`, `logging.sh`, `updates.sh`. Rollback-covered and none sever remote reachability.
- **Do NOT run live on openclaw without provider web console open**: `ssh.sh`, `firewall.sh`, `users.sh`. These can sever the only access path.
- **Before any non-dry run on openclaw**: snapshot via the VPS provider, keep a second SSH session open, and verify new config with `sshd -t` / `ufw status` plus a fresh connection *before* closing the original.
- **After every live test**: run `sudo ./harden.sh --rollback`, verify baseline, note findings in the Drift section.

## Workflow expectations for Claude

When I ask you to **modify an existing module**:

1. Read the module + its rollback path in `lib/rollback.sh` first.
2. Show the change as a diff.
3. Show the corresponding rollback diff in the same change set.
4. Run `shellcheck` and report any new warnings.
5. Show `sudo ./harden.sh --dry-run --modules <name>` output for the touched module.

When I ask you to **add a new module**:

1. Propose the module's responsibility in plain text first — what does it harden, what's the CIS reference, what could go wrong.
2. Wait for go-ahead before writing.
3. Write the module + rollback + config.yml entry + README row in the same commit.
4. Test full --dry-run end to end.

When I ask you to **change rollback behaviour**:

This is the highest-risk change in the repo. Triple-check:
1. Does the new behaviour break existing logged changes that someone might roll back?
2. Is the change-log format still parseable by older versions of the rollback script?
3. If format compatibility is broken, bump a version marker so old logs don't get misinterpreted.

When **reviewing a change**:

1. Flag missing rollback path first, security correctness second, style third.
2. Anything that locks the user out (sshd config without verification, firewall default-deny without rule check, sudo removal) gets a hard "did you verify this on a throwaway VM" question, not a stylistic comment.

## Things to avoid

- Modifying `harden.sh` to remove the `--dry-run` requirement on any module — the dry-run gate is load-bearing.
- Removing `--rollback` capability from any module to "simplify" — the rollback story is the repo's killer feature.
- Hardcoding the SSH port number anywhere except config.yml's default (changing 22 → 2222 silently is exactly the lockout pattern).
- Adding modules that disable or kill services without verifying via `systemctl is-enabled` first — assumptions about what's running break on different Ubuntu variants.
- Pushing to a tag or running `gh release` from automation — releases happen by my hand only, after a real VM test.

## Related repos

- [`homelab-infrastructure`](https://github.com/bastiaan365/homelab-infrastructure) — the network these hardened nodes live on
- [`dns-security-setup`](https://github.com/bastiaan365/dns-security-setup) — DNS hardening that complements this script

## Drift from target structure

_Claude maintains this section. List anything in the repo that doesn't match the conventions above, with why it's still there and what would need to happen to fix it._

- **`lib/rollback.sh:46` `eval`s rollback commands from the change log.** Log is root-only so practical risk is low, but the pattern invites regressions. Fix: write structured verb+args tuples in `log_change` and dispatch a finite set of rollback verbs in `perform_rollback`.
- **`lib/common.sh:57` `parse_config` is regex-over-YAML.** Works for the current flat `config.yml` but breaks on nested keys, quoted values with colons, or multi-line arrays. Fix: take a `yq` dependency, gate on `command -v yq` at startup, route all config reads through it.
- **README says SSH default is `22`; `config.yml:5` ships `2222`.** Align README text to the actual shipped default and note that users on SSH-restricted networks must edit before running.
- **Idempotency is claimed but not enforced.** No harness runs modules twice and diffs the change log. Fix: add `tests/idempotency.sh` that invokes each module twice on a throwaway VM and asserts zero new `log_change` entries on the second pass.
- **Doc drift audit performed on openclaw 2026-04-18.** Next pass should verify `shellcheck -S warning` cleanly across `harden.sh lib/*.sh modules/*.sh` — not done this session because `shellcheck` isn't installed on openclaw.
