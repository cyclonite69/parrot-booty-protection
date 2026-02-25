# GEMINI.md

## Project Overview: Parrot Booty Protection

This project provides a set of scripts and configuration files to harden the DNS and network configuration on a Linux system, specifically tailored for Parrot OS. The goal is to enhance security and privacy—protecting your digital treasure (booty)—by implementing a robust setup that includes DNS over TLS (DoT), DNSSEC validation, and a strict firewall policy.

The core components of this project are:
-   **Unbound:** A local DNS resolver configured to use DNS over TLS to encrypt DNS queries to upstream providers like Cloudflare and Quad9. It also performs DNSSEC validation to protect against DNS spoofing.
-   **nftables:** A firewall configured to restrict network traffic, only allowing essential services. This helps to prevent DNS leaks and other potential attacks.
-   **Shell Scripts:** A collection of scripts to automate the process of hardening, restoring, and monitoring the DNS configuration.

## Key Files

| File | Description |
| --- | --- |
| `README.md` | The main documentation for the project, providing a comprehensive guide to installation, usage, and troubleshooting. |
| `scripts/dns_harden.sh` | The main script for applying the DNS hardening. It configures `/etc/resolv.conf`, makes it immutable, and restarts NetworkManager. |
| `scripts/dns_restore.sh` | A script to restore the default DNS configuration, in case of any issues. |
| `scripts/dns_monitor.sh` | A script to monitor the status of the DNS hardening and log any changes. |
| `scripts/dns_status.sh` | A script to quickly check the current status of the DNS hardening. |
| `configs/unbound.conf` | The configuration file for the Unbound DNS resolver. It includes settings for DNS over TLS, DNSSEC, and privacy. |
| `configs/nftables.conf` | The configuration file for the nftables firewall. It defines a strict set of rules to control network traffic. |

## Building and Running

This project does not have a traditional build process. The scripts are meant to be run directly.

### Hardening the System

To apply the DNS hardening, run the following command:

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

### Applying the Unbound Configuration

After running the hardening script, you need to apply the Unbound configuration:

```bash
sudo cp configs/unbound.conf /etc/unbound/unbound.conf
sudo unbound-checkconf
sudo systemctl restart unbound
```

### Applying the nftables Firewall

To apply the firewall rules:

```bash
sudo cp configs/nftables.conf /etc/nftables.conf
sudo systemctl restart nftables
```

### Monitoring the Hardening

You can check the status of the DNS hardening at any time by running:

```bash
./scripts/dns_status.sh
```

To set up automatic monitoring, you can use the `dns_monitoring_install.sh` script, which will set up a cron job to run `dns_monitor.sh` periodically.

## Development Conventions

-   **Shell Scripts:** The shell scripts are written in `bash` and use `set -euo pipefail` for robustness. They include logging and error handling.
-   **Configuration Files:** The configuration files (`unbound.conf`, `nftables.conf`) are well-commented to explain the purpose of each setting.
-   **Immutability:** The project uses the `chattr +i` command to make `/etc/resolv.conf` immutable. This is a key part of the hardening process, but it's important to be aware of it when making changes to the system. The `dns_harden.sh` and `dns_restore.sh` scripts handle this automatically.
