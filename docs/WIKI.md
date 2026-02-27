# 🏴‍☠️ Parrot Booty Protection Wiki

Welcome to the **Parrot Booty Protection** Wiki. This comprehensive guide details how to safeguard your digital treasure using our full-scale **Security Operations Console**.

## 🧭 Table of Contents

1.  [Mission & Philosophy](#-mission--philosophy)
2.  [The Command Center (Web Ops Console)](#-the-command-center-web-ops-console)
3.  [The War Room (Modular Framework)](#-the-war-room-modular-framework)
4.  [Getting Started](#-getting-started)
5.  [Defense Modules](#-defense-modules)
    *   [Rootkit Sentry](#rootkit-sentry)
    *   [Network Exposure](#network-exposure)
    *   [DNS Hardening](#dns-hardening)
    *   [Encrypted Time (NTS)](#encrypted-time-nts)
6.  [Maintenance & Monitoring](#-maintenance--monitoring)
7.  [The Captain's Ledger (Reports)](#-the-captains-ledger-reports)
8.  [Troubleshooting](#-troubleshooting)

---

## 🏴‍☠️ Mission & Philosophy

The high seas of the internet are filled with privateers and scoundrels. **Parrot Booty Protection** is built on a **Zero-Trust Philosophy**:

*   **Default Deny**: If it's not explicitly allowed, it's blocked.
*   **Encrypted by Default**: All signals (DNS, Time) must be encrypted.
*   **Minimal Surface Area**: Unused ports and services are scuttled.
*   **Verifiable Security**: Continuous auditing and reporting.

---

## ⚔️ The Command Center (Web Ops Console)

The primary interface for managing your ship's defenses is the **Web Ops Console**.

### The Quarterdeck: `http://localhost:8080`
Accessible via any local browser, this dashboard provides:
*   **Live Rigging Status**: Real-time SECURED/UNSECURED indicators.
*   **Modular Control**: One-click Install and Execution of defenses.
*   **The Ledger Browser**: Read all security reports directly in the high-contrast UI.

---

## ⚔️ The War Room (TUI)

For those who prefer the terminal, the `hardenctl` dashboard remains available at `hardening-framework/hardenctl`.

---

## 🚀 Getting Started

### Prerequisites
*   **OS**: Parrot OS or Debian.
*   **Privileges**: Sudo/Root access for system changes.
*   **Tools**: `python3`, `fastapi`, `uvicorn`, `whiptail`.

### Installation
```bash
git clone https://github.com/cyclonite69/dns-hardening-parrot.git
cd dns-hardening-parrot
sudo bash scripts/install_ops.sh
```

---

## 🛡️ Defense Modules

### Rootkit Sentry
Uses `rkhunter` and `chkrootkit` to scan for hidden enemies in the hull.
*   **Action**: `Run Scan`
*   **Report**: `reports/rootkit/`

### Network Exposure
Uses `nmap` to perform external-style host validation and service fingerprinting.
*   **Action**: `Batten Down`
*   **Report**: HTML-based scan results.

### DNS Hardening
Configures `unbound` for DNS-over-TLS and DNSSEC.
*   **Action**: `Inspect` to verify DoT signal.

---

## 📜 The Captain's Ledger (Report Viewer)

Every action on the ship is recorded. Use the **Open Ledger** button in the Web UI to view:
*   Firewall ruleset exports.
*   NTS synchronization status.
*   Container security audits.
*   System compliance summaries.

---

## 🛠️ Troubleshooting

| Issue | Potential Solution |
| :--- | :--- |
| **Console not loading** | Run `sudo systemctl restart pbp-ops`. |
| **Module fails install** | Check `logs/` for the specific install log. |
| **Network blocked** | Use `sudo nft flush ruleset` to open the ports. |

---

*“May your booty be guarded and your lines be encrypted.”* 🦜🏴‍☠️
