# GEMINI.md

## Project Overview: Parrot Booty Protection

This project provides a set of scripts and configuration files to harden the DNS and network configuration on a Linux system, specifically tailored for Parrot OS. The goal is to enhance security and privacy—protecting your digital treasure (booty)—by implementing a robust setup that includes DNS over TLS (DoT), DNSSEC validation, and a strict firewall policy.

The core components of this project are:
-   **Unbound:** A local DNS resolver configured to use DNS over TLS to encrypt DNS queries to upstream providers like Cloudflare and Quad9. It also performs DNSSEC validation to protect against DNS spoofing.
-   **nftables:** A firewall configured to restrict network traffic, only allowing essential services. This helps to prevent DNS leaks and other potential attacks.
-   **Modular Hardening Framework:** A centralized "War Room" system (`hardenctl`) to manage various security policies (Sysctl, SSH, etc.) as independent modules.
-   **Shell Scripts:** A collection of scripts to automate the process of hardening, restoring, and monitoring the DNS configuration.

## Key Files

| File | Description |
| --- | --- |
| `README.md` | The main documentation for the project, providing a comprehensive guide to installation, usage, and troubleshooting. |
| `hardening-framework/hardenctl` | The central TUI "War Room" control interface for all hardening modules. |
| `hardening-framework/modules/` | Directory containing individual hardening modules (Sysctl, SSH, etc.). |
| `scripts/dns_harden.sh` | The main script for applying the DNS hardening. It configures `/etc/resolv.conf`, makes it immutable, and restarts NetworkManager. |
| `scripts/dns_restore.sh` | A script to restore the default DNS configuration, in case of any issues. |
| `scripts/dns_monitor.sh` | A script to monitor the status of the DNS hardening and log any changes. |
| `scripts/dns_status.sh` | A script to quickly check the current status of the DNS hardening. |
| `configs/unbound.conf` | The configuration file for the Unbound DNS resolver. It includes settings for DNS over TLS, DNSSEC, and privacy. |
| `configs/nftables.conf` | The configuration file for the nftables firewall. It defines a strict set of rules to control network traffic. |

## Building and Running

This project does not have a traditional build process. The scripts are meant to be run directly.

### The War Room (Modular Controller)

The recommended way to secure the ship is using the central controller:

```bash
sudo ./hardening-framework/hardenctl
```

This interface allows you to:
1. **Enable Defenses**: Install and activate specific hardening modules.
2. **Inspect the Rigging**: Verify that defenses are still active and correctly configured.
3. **Pick your Defenses**: Configure module-specific settings (like selecting which services to disable).
4. **Run Tasks**: Trigger manual actions like "Malware Scans".
5. **View the Ship's Logs**: Access integrated reports and security logs (The Captain's Ledger).

### Manual Hardening

To apply the DNS hardening manually, run:

```bash
sudo ./scripts/dns_harden.sh
```

This will:
1.  **Check for and install required packages (`unbound`, `unbound-anchor`, `dnsutils`) if missing.**
2.  Backup the current `/etc/resolv.conf` and `/etc/NetworkManager/NetworkManager.conf`.
3.  Create a new `/etc/resolv.conf` with the local Unbound resolver as the primary nameserver.
4.  Make `/etc/resolv.conf` immutable to prevent other services from modifying it.
5.  Configure NetworkManager to not manage DNS.
6.  Restart NetworkManager.

## Modular Hardening Framework

The project includes an extensible framework for general system hardening.

### Available Modules
- **01 Kernel Sysctl:** Network stack hardening (anti-spoofing, SYN cookies).
- **02 SSH Hardening:** Disables root login, enforcing key-based auth. Supports both `ssh` and `sshd` service names.
- **04 NTP Hardening:** Configures Chrony with NTS (Network Time Security) and strict authentication.
- **05 DNS Hardening:** Installs Unbound as a local DoT resolver with DNSSEC. Includes service status reports.
- **06 Firewall Base:** Applies a strict nftables ruleset (Default Deny Inbound).
- **07 IPv6 Removal:** Disables IPv6 via GRUB kernel parameter (Reboot required).
- **10 Malware Detect:** Sets up rkhunter/chkrootkit/lynis with **Manual Scan** and report viewing.
- **20 Container Stabilization:** Fixes Podman/Docker CLI, enables rootless containers.
- **30 Service Hardening:** Attack surface reduction by disabling risky/unused daemons (CUPS, Avahi, etc.). Includes **interactive selection** of services and automatic **firewall port scuttling**.
- **40 DNS Monitoring:** Background monitoring of DNS immutability and DoT health (The Crow's Nest).
- **90 Log Explorer:** A centralized utility to browse all ship logs and security reports (The Captain's Ledger).

### Adding Modules

New modules can be added by placing a bash script in `hardening-framework/modules/` following the `template.sh` structure. Modules can optionally implement `run_task()` for manual actions and `view_reports()` for log exploration.

## Development Conventions

-   **Theming**: All user-facing strings should follow the **Parrot Booty Protection** pirate theme (e.g., "The Locker", "The Quarterdeck", "Scuttle the defenses").
-   **Shell Scripts**: The shell scripts are written in `bash` and use `set -euo pipefail` for robustness. They include logging and error handling.
-   **Configuration Files**: The configuration files (`unbound.conf`, `nftables.conf`) are well-commented to explain the purpose of each setting.
-   **Immutability**: The project uses the `chattr +i` command to make `/etc/resolv.conf` immutable. This is a key part of the hardening process.
