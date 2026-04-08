# 🏴‍☠️ Parrot Booty Protection Wiki

Welcome to the active field guide for PBP.

## Mission

PBP enforces operator sovereignty:
- No autonomous configuration changes
- Explicit module lifecycle control
- Auditable reporting and rollback

## Command Center

- **Quarterdeck (web control plane)**: `http://localhost:7777`
- Start: `pbp control start`
- Stop: `pbp control stop`
- Integrity: `pbp integrity`
- Alerts: `pbp alerts`

## War Room

- **Menu**: `/opt/pbp/bin/pbp-menu`
- **Dashboard**: `pbp dashboard`
- **CLI**:
  - `pbp list`
  - `sudo pbp enable <module>`
  - `sudo pbp disable <module>`
  - `sudo pbp health [module]`
  - `sudo pbp scan [module]`

## Defense Modules

Current module set:
- `time` - NTS time hardening
- `dns` - Unbound encrypted DNS hardening
- `network` - nftables firewall controls
- `container` - Podman/rootless container checks
- `audit` - auditd controls and validation
- `rootkit` - rootkit scanner integration
- `recon` - exposure and port recon
- `usb` - USBGuard allowlist enforcement
- `fail2ban` - brute-force protection
- `mount` - filesystem/mount safety checks
- `mac` - MAC randomization controls
- `logs` - security log policy checks

## Captain's Ledger

- List reports: `pbp reports`
- View latest/ID: `pbp report [id]`
- Compare: `pbp compare <id1> <id2>`
- Report output root: `/var/log/pbp/reports/`

## Installation

```bash
git clone https://github.com/cyclonite69/parrot-booty-protection.git
cd parrot-booty-protection
sudo bash scripts/install.sh
sudo bash scripts/install_control.sh
sudo bash scripts/install_reporting_deps.sh
```

For existing installs:

```bash
sudo bash scripts/upgrade.sh
```

## Troubleshooting

- Menu missing modules: run `sudo pbp list` to verify registry/state access.
- DNS scan errors about `resolve1`: upgrade runtime (`sudo bash scripts/upgrade.sh`).
- Firewall shown inactive with external rules: ensure updated `modules/network/health.sh` is deployed via upgrade.
