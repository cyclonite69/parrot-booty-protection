# Linux Hardening Framework

A modular, extensible security hardening framework for Linux systems (Debian/Parrot/Kali).

## Directory Structure

- `core/`: Core libraries (logging, state management).
- `modules/`: Individual hardening scripts.
- `profiles/`: Preset configurations (Minimal, Workstation, Hardened).
- `logs/`: Operation logs.
- `state/`: Current enabled/disabled state of modules.
- `hardenctl`: The main control interface.

## Usage

Run the control interface as root:

```bash
sudo ./hardenctl
```

This will launch a terminal menu where you can enable or disable specific hardening modules.

## Modules

Each module is a self-contained bash script in the `modules/` directory that implements:
- `install()`: Applies the hardening measures.
- `status()`: Checks if the hardening is active.
- `verify()`: Validates the configuration.
- `rollback()`: Reverts changes to the original state.

## Creating New Modules

Copy `modules/template.sh` to a new file (e.g., `modules/99_custom_harden.sh`) and implement the required functions.

## Logging

All actions are logged to `logs/hardenctl.log` (or `/var/log/hardenctl.log` if configured).

## Safety

Always test changes in a non-production environment first. The framework includes rollback capabilities, but system-level changes can have unintended consequences.
