# 🏴‍☠️ Parrot Booty Protection Wiki

Welcome to the **Parrot Booty Protection** Wiki. This comprehensive guide details how to safeguard your digital treasure—your data, privacy, and system integrity—using our suite of security tools.

## 🧭 Table of Contents

1.  [Mission & Philosophy](#-mission--philosophy)
2.  [The Pirate's Toolkit (Architecture)](#-the-pirates-toolkit-architecture)
3.  [Getting Started](#-getting-started)
4.  [Hardening Guide](#-hardening-guide)
    *   [Step 1: Man the Cannons (Firewall)](#step-1-man-the-cannons-firewall)
    *   [Step 2: Batten down the Hatches (Services)](#step-2-batten-down-the-hatches-services)
    *   [Step 3: Secure the Lines (DNS)](#step-3-secure-the-lines-dns)
5.  [DNS Deep Dive: Unbound & TLS](#-dns-deep-dive-unbound--tls)
6.  [Maintenance & Monitoring](#-maintenance--monitoring)
7.  [Container Support (Docker)](#-container-support-docker)
8.  [Troubleshooting](#-troubleshooting)
9.  [Contributing & Security](#-contributing--security)

---

## 🏴‍☠️ Mission & Philosophy

The high seas of the internet are filled with privateers and scoundrels looking to plunder your DNS queries and scan your open ports. **Parrot Booty Protection** is built on a **Zero-Trust Philosophy**:

*   **Default Deny**: If it's not explicitly allowed, it's blocked.
*   **Encrypted by Default**: DNS queries shouldn't be readable by anyone but the resolver.
*   **Minimal Surface Area**: If a service isn't needed, it shouldn't be running.
*   **Verifiable Security**: Tools to monitor and alert you if your defenses are breached.

---

## ⚔️ The Pirate's Toolkit (Architecture)

The project is divided into three primary layers of defense:

1.  **Network Layer (`nftables`)**: A strict, stateful firewall that drops all incoming traffic by default and limits outgoing traffic.
2.  **Service Layer (`systemd`)**: An interactive wizard to identify and disable "leaky" or unnecessary background services.
3.  **DNS Layer (`unbound`)**: A local, recursive caching DNS resolver that uses **DNS-over-TLS (DoT)** and **DNSSEC** to prevent spoofing and snooping.

---

## 🚀 Getting Started

### Prerequisites
*   **OS**: Parrot OS, Debian, or any Debian-based distribution.
*   **Privileges**: Sudo/Root access is mandatory for system-level changes.
*   **Tools**: `git`, `bash`, `iproute2`, `dnsutils`.

### Installation
```bash
git clone https://github.com/cyclonite69/dns-hardening-parrot.git
cd dns-hardening-parrot
chmod +x scripts/*.sh
```

---

## 🛡️ Hardening Guide

Follow these steps in order for maximum security.

### Step 1: Man the Cannons (Firewall)
Run the interactive firewall builder. It will ask you which ports (SSH, HTTP, etc.) you need to keep open.
```bash
sudo ./scripts/port_harden.sh
```
*   **Warning**: If you are on a remote server, ensure you allow your SSH port (usually 22) or you will be locked out!

### Step 2: Batten down the Hatches (Services)
Audit your running services and disable the ones you don't use (e.g., Bluetooth, Print Spoolers, Avahi).
```bash
sudo ./scripts/service_harden.sh
```

### Step 3: Secure the Lines (DNS)
Install and configure Unbound for encrypted DNS.
```bash
sudo ./scripts/dns_harden.sh
```

---

## 🔒 DNS Deep Dive: Unbound & TLS

Our setup uses **Unbound** to provide:
*   **DNS-over-TLS (DoT)**: Encrypts queries to Cloudflare (1.1.1.1) and Quad9 (9.9.9.9) on port 853.
*   **DNSSEC**: Validates signatures on DNS records to prevent "Man-in-the-Middle" (MitM) attacks.
*   **QNAME Minimisation**: Only sends the minimum necessary information to upstream servers.

### Verification
To verify your DNS is truly "Hardened":
1.  **Check TLS connections**: `sudo ss -tnp | grep :853` (Should show established connections).
2.  **Check DNSSEC**: `dig @127.0.0.1 google.com +dnssec` (Look for the `ad` flag).
3.  **Check Status**: `sudo ./scripts/dns_status.sh`

For more details, see [**UNBOUND_TLS_STATUS.md**](UNBOUND_TLS_STATUS.md).

---

## 📡 Maintenance & Monitoring

Security isn't a "set and forget" task. We provide tools for continuous monitoring.

### 1. Manual Status Check
```bash
./scripts/dns_status.sh
```

### 2. Automated Monitoring (Cron)
Use the installer to set up periodic checks that log changes and alert you to compromises.
```bash
sudo ./scripts/dns_monitoring_install.sh
```

### 3. Log Locations
*   **Status Changes**: `/var/log/dns_hardening_monitor.log`
*   **Security Alerts**: `/var/log/dns_hardening_alerts.log`

See [**MONITORING.md**](MONITORING.md) for full details.

---

## 🐳 Container Support (Docker)

Docker often bypasses local DNS settings. If your containers can't resolve names after hardening, run the Docker fix:
```bash
sudo ./scripts/docker_dns_fix.sh --apply
```
This updates `/etc/docker/daemon.json` to point containers to your local Unbound instance or reliable fallbacks.

---

## 🛠️ Troubleshooting

| Issue | Potential Solution |
| :--- | :--- |
| **No Internet after Firewall** | Run `sudo nft flush ruleset` to reset, then re-run `port_harden.sh`. |
| **DNS Resolution Fails** | Check Unbound: `sudo systemctl status unbound`. Check logs: `sudo journalctl -u unbound`. |
| **Resolv.conf overwritten** | The `dns_harden.sh` script uses `chattr +i`. Check with `lsattr /etc/resolv.conf`. |
| **SSH Locked Out** | Use a physical console or cloud provider recovery console to flush `nftables`. |

---

## 🤝 Contributing & Security

*   **Found a Bug?**: Please report it via GitHub Issues using our [**Bug Report Template**](.github/ISSUE_TEMPLATE/bug_report.md).
*   **Want to help?**: Read our [**Contributing Guidelines**](CONTRIBUTING.md).
*   **Security Vulnerabilities**: Please see [**SECURITY.md**](SECURITY.md) for our responsible disclosure policy.

---

## 📚 Project Resources

*   **[Changelog (CHANGELOG.md)](CHANGELOG.md)**: Track the latest updates and improvements.
*   **[Test Results (TEST_RESULTS.md)](TEST_RESULTS.md)**: View the latest automated test performance and validation logs.
*   **[Code of Conduct (CODE_OF_CONDUCT.md)](CODE_OF_CONDUCT.md)**: Our standards for a friendly and inclusive community.
*   **[License (LICENSE)](LICENSE)**: This project is licensed under the MIT License.

---

*“May your booty be guarded and your lines be encrypted.”* 🦜🏴‍☠️
