# 🏴‍☠️ Parrot Booty Protection: The War Room

Welcome to the **War Room** (Modular Hardening Framework). This is the central command center for all shipboard security policies.

## 🧭 Overview

The framework provides a unified, interactive TUI (`hardenctl`) to manage various hardening modules as independent "defenses." Each module can be enabled, disabled, or verified from a single menu.

## 🚀 Usage

To enter the War Room:
```bash
sudo ./hardenctl
```

### 🦜 Menu Commands
- **Batten down the hatches (Enable)**: Install and activate a defense module.
- **Abandon defenses (Disable)**: Rollback and disable a module.
- **Inspect the rigging (Verify)**: Run tests to ensure the defense is still secure.
- **🦜 Run Task**: Trigger manual actions like malware scans or network audits.
- **📜 View the Ship's Logs**: Browse integrated security reports and audit ledgers.

---

## 🏗️ The Ship's Design (Architecture)

- **`hardenctl`**: The main TUI controller (The Quarterdeck).
- **`core/`**: Essential rigging (logger, state management).
- **`modules/`**: Individual defense scripts.
- **`state/`**: The manifest of which defenses are active.
- **`logs/`**: Temporary logs for module operations.

---

## ⚔️ Adding New Defenses (New Modules)

To add a new module to the fleet:
1. Copy `modules/template.sh` to a new filename (e.g., `modules/50_my_new_defense.sh`).
2. Implement the `install`, `rollback`, `verify`, and `status` functions.
3. (Optional) Define `run_task` for manual actions and `view_reports` for log viewing.
4. The dashboard will automatically detect the new module and add it to the menu!

*“May your booty be guarded and your lines be encrypted.”* 🦜🏴‍☠️
