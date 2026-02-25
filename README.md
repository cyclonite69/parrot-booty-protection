# 🏴‍☠️ Parrot Booty Protection

**A suite of scripts to guard your digital treasure (DNS, firewall, and system services) with a zero-trust philosophy.**

![OS: Parrot OS / Debian](https://img.shields.io/badge/OS-Parrot%20OS%20%7C%20Debian-blue.svg)
![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)
![Last Commit](https://img.shields.io/github/last-commit/cyclonite69/dns-hardening-parrot)

**Parrot Booty Protection** is a collection of powerful, interactive scripts designed for **Parrot OS DNS hardening** and general **Linux security**. It ensures your "booty"—your data and identity—remains safe from prying eyes by implementing **DNS-over-TLS (DoT)**, a **zero-trust nftables firewall**, and strict **service hardening** for Debian-based systems.

## ✅ Features

-   **Secure the Lines**: Configures `unbound` as a local DNS-over-TLS (DoT) resolver to encrypt your DNS queries.
-   **Guard the Clock**: Configures `chrony` with Network Time Security (NTS) to ensure encrypted and authenticated time synchronization.
-   **Man the Cannons**: An interactive wizard to build a strict `nftables` firewall policy, allowing only the traffic you explicitly permit.
-   **Batten down the Hatches**: Interactively scan for and disable unnecessary system services to minimize attack surface.
-   **Fix Docker DNS**: Automatically solves the common DNS resolution issue for containers when using a local DNS resolver.
-   **Modular Framework**: A new extensible system to manage all hardening policies from a central controller (`hardenctl`).
-   **Robust & Reversible**: All scripts are designed to be idempotent and include mechanisms to revert changes.

## 🚀 Quick Start

1.  **Clone the repository:**
    ```bash
    git clone https://github.com/cyclonite69/dns-hardening-parrot.git
    cd dns-hardening-parrot
    ```

2.  **Use the Modular Controller (Recommended):**
    ```bash
    # Launch the central hardening control panel
    sudo ./hardening-framework/hardenctl
    ```

3.  **Or run individual hardening wizards:**

    # Then, harden system services
    sudo ./scripts/service_harden.sh
    
    # Secure your system time with NTS
    sudo ./scripts/ntp_harden.sh

    # Finally, set up encrypted DNS
    sudo ./scripts/dns_harden.sh
    ```
3.  **Fix Docker DNS (if you use Docker):**
    ```bash
    sudo ./scripts/docker_dns_fix.sh --apply
    ```

## 📜 Script Overview

| Script | Purpose | Usage |
| :--- | :--- | :--- |
| `hardenctl` | Central TUI controller for all modular hardening policies. | `sudo ./hardening-framework/hardenctl` |
| `port_harden.sh` | Interactively create a zero-trust `nftables` firewall. | `sudo ./scripts/port_harden.sh` |
| `service_harden.sh` | Interactively disable unnecessary system services. | `sudo ./scripts/service_harden.sh` |
| `ntp_harden.sh` | Configures Chrony with NTS for secure time sync. | `sudo ./scripts/ntp_harden.sh` |
| `dns_harden.sh` | Hardens system DNS to use a local DoT resolver. | `sudo ./scripts/dns_harden.sh` |
| `dns_restore.sh` | Reverts all changes made by the DNS hardening script. | `sudo ./scripts/dns_restore.sh` |
| `docker_dns_fix.sh` | Automatically configures DNS for Docker containers. | `sudo ./scripts/docker_dns_fix.sh --apply`|

## 📋 Prerequisites

-   A Debian-based system (tested on Parrot OS).
-   `git`, `bash`, and standard networking tools (`ip`, `dig`).
-   Root/sudo privileges are required to run these scripts.

## ⚙️ Installation

The scripts are designed to be self-contained. The hardening script will automatically install required packages like `unbound` and `nftables` if they are missing.

```bash
# 1. Update your system (Recommended)
sudo apt update && sudo apt upgrade -y

# 2. Clone the repository
git clone https://github.com/cyclonite69/dns-hardening-parrot.git
cd dns-hardening-parrot

# 3. Make scripts executable
chmod +x scripts/*.sh
```

## ⚠️ Security Warnings

-   **Firewall**: The `port_harden.sh` script creates a **deny-by-default** firewall. If you configure it incorrectly (e.g., without allowing SSH) and apply the rules, you could lock yourself out of a remote machine.
-   **Root Access**: These scripts make significant, system-wide changes. Read the code and understand what each script does before executing it.
-   **Backups**: While the scripts create backups, you are encouraged to have your own system snapshots or backups as a fallback.

## 📚 Detailed Documentation

For a deeper dive into the architecture, script logic, and advanced configuration, please see our detailed documentation and wiki.

➡️ **[Comprehensive Wiki (WIKI.md)](WIKI.md)**
➡️ **[Read the Full Documentation (GEMINI.md)](GEMINI.md)**

## 🤝 Contributing

We welcome contributions! Please read our [**Contributing Guidelines (CONTRIBUTING.md)**](CONTRIBUTING.md) to get started with reporting issues, submitting pull requests, and our code style conventions.

## 📜 License

This project is licensed under the MIT License. See the [**LICENSE**](LICENSE) file for details.
