# 🏴‍☠️ Joining the Crew: Contributing to Parrot Booty Protection

First off, thank you for considering joining the crew! This project thrives on community involvement, and every contribution helps keep our digital treasure safe from scoundrels.

This document provides guidelines for contributing to the fleet.

## ❓ Reporting an Issue: Sighting the Enemy

If you find a hole in the hull (bug), have a feature request (new cannons), or want to suggest an improvement, please [**open an issue on GitHub**](https://github.com/cyclonite69/dns-hardening-parrot/issues).

When filing a report, please include:
-   A clear and descriptive title (e.g., "The DNS Crow's Nest is blind in the fog").
-   A detailed description of the problem, including the module you were running.
-   Steps to reproduce the issue so we can see it from our deck.
-   The output of the script and any relevant logs from the **Captain's Ledger** (Module 90).

## 🚀 Submitting a Pull Request (PR): Man the Cannons!

We welcome PRs for bug fixes, new defense modules, and documentation improvements.

1.  **Fork the repository** to your own GitHub account.
2.  **Create a new branch** for your changes. Use a descriptive name (e.g., `feat/add-new-defense-module` or `fix/ssh-restart-bug`).
3.  **Make your changes**. If adding a new defense, use the `hardening-framework/modules/template.sh` as your map.
4.  **Test your changes** thoroughly on a clean deck (Parrot OS or Debian).
5.  **Commit your changes** with a clear and descriptive commit message.
6.  **Push your branch** to your fork and **Open a Pull Request**.

## 🎨 The Pirate's Code: Style Guidelines

To maintain a consistent and seaworthy codebase, please follow these rules:

-   **Theming**: All user-facing strings and documentation MUST follow the **Parrot Booty Protection** pirate theme. 🦜🏴‍☠️
-   **Shell Scripts**:
    -   All scripts must start with `set -euo pipefail` for robustness.
    -   Use the framework's `log_info`, `log_warn`, and `log_error` functions for consistent logging.
    -   Add comments to explain complex or non-obvious rigging.
-   **Modular Framework**:
    -   New defenses should be added as modules in `hardening-framework/modules/`.
    -   Implement `install()`, `rollback()`, `verify()`, and `status()`.
    -   Optionally add `run_task()` and `view_reports()` for interactive features.

## ✅ Testing Requirements

-   **New Defenses**: Test on a clean installation of Parrot OS or Debian.
-   **Bug Fixes**: Provide steps to reproduce the bug and verify the fix.
-   **Stability**: Ensure your changes don't scuttle the rest of the ship. Run `sudo ./hardening-framework/hardenctl` and verify all modules.

## 📜 Code of Conduct

Please note that this project is released with a [Code of Conduct](CODE_OF_CONDUCT.md). By participating in this project you agree to abide by its terms.

## 🔒 Security

If you discover a security vulnerability, please see our [Security Policy](SECURITY.md) for instructions on how to report it responsibly.

Thank you again for joining the crew! 🏴‍☠️
