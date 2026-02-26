# 🏴‍☠️ Parrot Booty Protection (PBP) Ops Platform

**A full-scale Security Operations Console to guard your digital treasure with real-time visibility, modular defenses, and integrated auditing.**

![OS: Parrot OS / Debian](https://img.shields.io/badge/OS-Parrot%20OS%20%7C%20Debian-blue.svg)
![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)

**Parrot Booty Protection** has evolved into a comprehensive **Integrated Defense Console**. It provides a high-contrast web dashboard to orchestrate installation, execution, and reporting for all system hardening and auditing modules.

## ✅ Platform Features

-   **🕹️ Ops Command Center**: A real-time web dashboard (`http://localhost:8080`) with a high-contrast **"Midnight Quarterdeck"** theme.
-   **🧩 Selectable Modules**: Plug-and-play architecture for DNS, Firewall, Rootkits, Network, and System hardening.
-   **📜 The Captain's Ledger**: Integrated report viewer to read timestamped security audits and scan results directly in the browser.
-   **🦜 Central Sentinel**: Background daemon coordinating autonomous monitoring and real-time state recalculation.
-   **🖥️ Tactical Display**: Terminal-based "War Room" (`pbp watch`) for quick security posture checks.
-   **🔍 Comprehensive Auditing**:
    -   **Rootkit Sentry**: Daily and manual scans for deep system threats.
    -   **Network Exposure**: Detailed port and service auditing using Nmap.
    -   **DNS & Time**: Hardened DoT and NTS-authenticated signals.
-   **⚖️ Forensic Mode**: "Secure The Ship" action to instantly collect evidence snapshots.

## 🚀 Quick Start

1.  **Deploy the Fleet**:
    ```bash
    git clone https://github.com/cyclonite69/dns-hardening-parrot.git
    cd dns-hardening-parrot
    sudo bash scripts/install_ops.sh
    ```

2.  **Access the Quarterdeck**:
    Open your browser to: **`http://localhost:8080`**

3.  **Map the Rigging**:
    ```bash
    sudo pbp learn
    ```

## 📜 Unified Command CLI

The `pbp` command coordinates the entire platform:

| Command | Purpose |
| :--- | :--- |
| `pbp ops` | Show instructions for the Web Ops Console. |
| `pbp watch` | Launch the real-time Tactical Dashboard (Terminal). |
| `pbp status` | Show ship's security state and exposure score. |
| `pbp respond` | Launch the Defensive Response Center for counter-measures. |
| `pbp report` | Interactive menu to browse all security audits (Terminal). |
| `pbp forensic` | 'Secure The Ship' - Collect an emergency evidence snapshot. |
| `pbp learn` | Establish the baseline system profile. |
| `pbp harden` | Launch the original Hardening Framework TUI. |

## ⚠️ Safety Requirements

-   **Non-Destructive**: All hardening modules include configuration backups and support rollback.
-   **Controlled Response**: Destructive actions (killing processes, freezing containers) require explicit Captain's confirmation.

*“May your booty be guarded and your lines be encrypted.”* 🦜🏴‍☠️
