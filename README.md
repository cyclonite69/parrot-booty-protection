# 🏴‍☠️ Parrot Booty Protection (PBP) Sentinel Platform

**A continuous defensive security appliance to guard your digital treasure with autonomous monitoring and real-time visibility.**

![OS: Parrot OS / Debian](https://img.shields.io/badge/OS-Parrot%20OS%20%7C%20Debian-blue.svg)
![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)

**Parrot Booty Protection** has evolved from a collection of scripts into a **persistent security sentinel**. It provides continuous awareness, automated threat detection, and a centralized command center to keep your workstation secure on the high seas of the internet.

## ✅ Platform Features

-   **🦜 Central Sentinel**: A background daemon (`pbp-sentinel`) that coordinates all monitoring modules and manages the ship's security state.
-   **📈 Exposure Scoring**: A dynamic security posture score (0-100) calculated from firewall status, integrity checks, and network exposure.
-   **🛡️ Automated State Engine**: Automatically shifts ship status from **NORMAL** to **SUSPICIOUS** or **COMPROMISED** based on real-time signals.
-   **🕹️ Defensive Response Center**: Interactive counter-measures to kill suspicious processes, close new ports, or freeze containers.
-   **🖥️ Tactical Dashboard**: A real-time "War Room" TUI (`pbp watch`) showing security posture, active alerts, and listener deltas.
-   **🔍 Continuous Monitoring**:
    -   **File Integrity**: Daily AIDE scans to detect hull tampering.
    -   **Persistence Audit**: Watches for unauthorized autostart entries and services.
    -   **Network Behavior**: Detects unknown listeners and tracks outbound intelligence.
    -   **Container Watchman**: Monitors Podman/Docker for risky mounts and unapproved images.
-   **⚖️ Forensic Mode**: "Secure The Ship" action to instantly collect evidence snapshots for investigation.

## 🚀 Quick Start

1.  **Deploy the Sentinel**:
    ```bash
    git clone https://github.com/cyclonite69/dns-hardening-parrot.git
    cd dns-hardening-parrot
    sudo bash install_pbp.sh
    ```

2.  **Map the Rigging (Learning Mode)**:
    ```bash
    sudo pbp learn
    ```

3.  **Enter the War Room**:
    ```bash
    pbp watch
    ```

## 📜 Unified Command CLI

The `pbp` command is your central interface:

| Command | Purpose |
| :--- | :--- |
| `pbp status` | Show ship's security state and exposure score. |
| `pbp watch` | Launch the real-time Tactical Dashboard. |
| `pbp scan` | Run all monitoring modules immediately. |
| `pbp respond` | Launch the Defensive Response Center for counter-measures. |
| `pbp report` | Interactive menu to browse all security audits and alerts. |
| `pbp forensic` | 'Secure The Ship' - Collect an emergency evidence snapshot. |
| `pbp learn` | Establish the baseline system profile. |
| `pbp harden` | Launch the original Hardening Framework Dashboard. |

## ⚙️ Modular Hardening

The platform still includes the full modular hardening framework for deep system configuration: `pbp harden`

## ⚠️ Safety Requirements

-   **Controlled Response**: The system alerts you to threats but never executes destructive actions (like killing processes) without your confirmation.
-   **Safe Isolation**: Host isolation counter-measures allow loopback traffic to ensure you aren't completely locked out of local recovery.

*“May your booty be guarded and your sentinel ever-watchful.”* 🦜🏴‍☠️
