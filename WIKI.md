# 🏴‍☠️ Parrot Booty Protection Wiki

Welcome to the **Parrot Booty Protection** Wiki. This comprehensive guide details how to safeguard your digital treasure—your data, privacy, and system integrity—using our suite of security tools.

## 🧭 Table of Contents

1.  [Mission & Philosophy](#-mission--philosophy)
2.  [The War Room (Modular Framework)](#-the-war-room-modular-framework)
3.  [Getting Started](#-getting-started)
4.  [Hardening Guide](#-hardening-guide)
    *   [Step 1: Man the Cannons (Firewall)](#step-1-man-the-cannons-firewall)
    *   [Step 2: Batten down the Hatches (Services)](#step-2-batten-down-the-hatches-services)
    *   [Step 3: Secure the Lines (DNS)](#step-3-secure-the-lines-dns)
5.  [DNS Deep Dive: Unbound & TLS](#-dns-deep-dive-unbound--tls)
6.  [Maintenance & Monitoring](#-maintenance--monitoring)
7.  [The Captain's Ledger (Log Explorer)](#-the-captains-ledger-log-explorer)
8.  [Troubleshooting](#-troubleshooting)

---

## 🏴‍☠️ Mission & Philosophy

The high seas of the internet are filled with privateers and scoundrels looking to plunder your DNS queries and scan your open ports. **Parrot Booty Protection** is built on a **Zero-Trust Philosophy**:

*   **Default Deny**: If it's not explicitly allowed, it's blocked.
*   **Encrypted by Default**: DNS queries shouldn't be readable by anyone but the resolver.
*   **Minimal Surface Area**: If a service isn't needed, it shouldn't be running.
*   **Verifiable Security**: Tools to monitor and alert you if your defenses are breached.

---

## ⚔️ The War Room (Modular Framework)

The modern way to manage your defenses is through the **Modular Hardening Framework**.

### The Central Controller: `hardenctl`
Located at `hardening-framework/hardenctl`, this TUI dashboard is your "War Room." It allows you to:
*   **Deploy Defenses**: Enable or Disable security modules with a single command.
*   **Manual Scans**: Trigger immediate security audits (like Malware Scans).
*   **Report Explorer**: Browse all security logs and reports in one place.

---

## 🚀 Getting Started

### Prerequisites
*   **OS**: Parrot OS, Debian, or any Debian-based distribution.
*   **Privileges**: Sudo/Root access is mandatory for system-level changes.
*   **Tools**: `git`, `bash`, `whiptail`, `jq`.

### Installation
```bash
git clone https://github.com/cyclonite69/dns-hardening-parrot.git
cd dns-hardening-parrot
# Launch the dashboard
sudo ./hardening-framework/hardenctl
```

---

## 🛡️ Hardening Guide

While the dashboard is recommended, you can still use our manual scripts.

### Step 1: Man the Cannons (Firewall)
Run the interactive firewall builder or use Module `06`.
```bash
sudo ./scripts/port_harden.sh
```

### Step 2: Batten down the Hatches (Services)
Audit your running services and disable the ones you don't use or use Module `30`.
```bash
sudo ./scripts/service_harden.sh
```

### Step 3: Secure the Lines (DNS)
Install and configure Unbound for encrypted DNS or use Module `05`.
```bash
sudo ./scripts/dns_harden.sh
```

---

## 🔒 DNS Deep Dive: Unbound & TLS

Our setup uses **Unbound** to provide:
*   **DNS-over-TLS (DoT)**: Encrypts queries to Cloudflare (1.1.1.1) and Quad9 (9.9.9.9) on port 853.
*   **DNSSEC**: Validates signatures on DNS records to prevent "Man-in-the-Middle" (MitM) attacks.

### Verification
To verify your DNS is truly "Hardened":
1.  **Check TLS connections**: `sudo ss -tnp | grep :853`
2.  **Check Status**: `sudo ./scripts/dns_status.sh`

---

## 📡 Maintenance & Monitoring (The Crow's Nest)

Module `40` (DNS Monitoring) sets up background checks that watch for:
*   **Immutability**: If `/etc/resolv.conf` is modified, an alert is logged.
*   **TLS Health**: If Unbound falls back to unencrypted DNS, you'll be notified.

### Logs & Alerts
*   **Monitor Log**: `/var/log/dns_hardening_monitor.log`
*   **Alerts Log**: `/var/log/dns_hardening_alerts.log`

---

## 📜 The Captain's Ledger (Log Explorer)

Module `90` provides the **Global Log Explorer**. Instead of hunting through `/var/log/`, use this interface to quickly inspect:
*   Framework installation logs.
*   DNS security history.
*   Malware detection reports (RKHunter, Lynis).
*   System authentication attempts.

---

## 🛠️ Troubleshooting

| Issue | Potential Solution |
| :--- | :--- |
| **No Internet after Firewall** | Run `sudo nft flush ruleset` to reset. |
| **DNS Resolution Fails** | Check Unbound: `sudo systemctl status unbound`. |
| **Resolv.conf overwritten** | Use `lsattr /etc/resolv.conf` to check the `i` flag. |

---

*“May your booty be guarded and your lines be encrypted.”* 🦜🏴‍☠️
