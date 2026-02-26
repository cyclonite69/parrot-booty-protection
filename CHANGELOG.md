# 📜 The Ship's Manifest: Changelog

Tracking all modifications to the **Parrot Booty Protection** defenses.

## 2026-02-25 - Major Update: The War Room (hardenctl v2.0)

### 🏴‍☠️ New Framework Features
- **The War Room Dashboard**: Upgraded `hardenctl` with a fully themed TUI interface.
- **Interactive Configuration**: Modules now support **"Configure"** submenus (e.g., picking which services to scuttle).
- **Synchronized Defenses**: Service Hardening now automatically manages firewall ports (Modular Port Scuttling).
- **Dynamic Action Support**: Modules can now offer **"Run Task"** (e.g., manual scans) and **"View Reports"** (e.g., log explorer).
- **The Captain's Ledger**: New **Global Log Explorer** (Module 90) to browse all ship logs in one place.
- **Parrot OS Support**: Enhanced SSH and DNS modules with distributive-aware service detection.

### ⚔️ New Defense Modules
1. **Module 30 (Service Hardening)**: Attack surface reduction. Scuttles CUPS, Avahi, and other leaky daemons with **interactive checklist selection**.
2. **Module 40 (DNS Monitoring)**: Manned lookout (The Crow's Nest) for DNS integrity and DoT health.
3. **Module 90 (Log Explorer)**: Centralized utility for inspecting all security records.

### 🛠️ Improvements & Repairs
- **SSH Verification**: Fixed `sshd -T` permission issues and service name conflicts (ssh vs sshd).
- **DNS Robustness**: Added retry logic and flexible NetworkManager configuration checks to prevent false rollback alarms.
- **Unified Theming**: All menus, logs, and documentation now follow the **Parrot Booty Protection** pirate theme.

---

## 2026-02-06 - Major Update: Portmaster Protection & Monitoring

### New Features
- **The Immutable Seal**: Prevents Portmaster/NetworkManager from scuttling `resolv.conf`.
- **Lookout System**: Initial periodic monitoring and alerts for DNS integrity.
- **The Ship's Log**: All scripts now log to timestamped files for later inspection.

### New Documentation
- **MONITORING.md**: Guide to the Crow's Nest setup.
- **TEST_RESULTS.md**: Initial verification of the ship's rigging.
- **WIKI.md**: The full Pirate's Manual for system hardening.

### Protection Against:
- Portmaster DNS hijackings.
- NetworkManager dynamic DNS overrides.
- Any landlubber trying to modify the DNS fortress (even as root).
