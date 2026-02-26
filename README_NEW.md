# 🏴‍☠️ Parrot Booty Protection (PBP) - Security Operations Platform

**A modular Linux hardening and monitoring framework for Parrot OS (Debian-based systems)**

![OS: Parrot OS / Debian](https://img.shields.io/badge/OS-Parrot%20OS%20%7C%20Debian-blue.svg)
![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)
![Version: 1.0.0](https://img.shields.io/badge/Version-1.0.0-green.svg)

PBP is a comprehensive security orchestration layer that treats hardening as composable, auditable policies. Built with defense-in-depth principles, it provides real-time visibility, modular defenses, and integrated auditing.

---

## ✨ Features

### 🎯 Core Capabilities
- **Modular Architecture** - 7 independent security modules
- **State Management** - Declarative configuration with rollback
- **Automated Scanning** - Daily security audits via systemd
- **Risk Scoring** - Quantified security posture (0-100+ scale)
- **HTML Reports** - Beautiful, detailed security reports
- **TUI Dashboard** - Real-time monitoring interface
- **Backup/Rollback** - Safe configuration changes
- **Audit Logging** - Complete action trail

### 🛡️ Security Modules

| Module | Purpose | Technology |
|--------|---------|------------|
| **TIME** | NTS-authenticated time sync | chrony + NTS |
| **DNS** | Encrypted DNS queries | systemd-resolved + DoT |
| **NETWORK** | Stateful firewall | nftables |
| **CONTAINER** | Rootless container security | Podman + seccomp |
| **AUDIT** | System activity monitoring | auditd |
| **ROOTKIT** | Malware detection | rkhunter + chkrootkit |
| **RECON** | Network exposure validation | nmap |

---

## 🚀 Quick Start

### Installation

```bash
git clone https://github.com/yourusername/parrot-booty-protection.git
cd parrot-booty-protection
sudo bash scripts/install.sh
```

### Basic Usage

```bash
# List available modules
pbp list

# Enable security modules
sudo pbp enable time
sudo pbp enable dns
sudo pbp enable network

# Run security scan
sudo pbp scan

# View system status
pbp status

# Launch interactive dashboard
pbp dashboard

# View reports
pbp reports
```

### Enable Automated Scans

```bash
# Daily security scans
sudo systemctl enable --now pbp-scan-daily.timer

# Weekly deep audits
sudo systemctl enable --now pbp-audit-weekly.timer
```

---

## 📊 Architecture

### Module Lifecycle

```
UNINSTALLED → install → INSTALLED → enable → ENABLED
                ↑                      ↓
                └──────── rollback ────┘
```

### Directory Structure

```
/opt/pbp/                    # Installation root
├── bin/
│   ├── pbp                  # Main CLI
│   └── pbp-dashboard        # TUI dashboard
├── core/
│   ├── engine.sh            # Orchestration
│   ├── state.sh             # State management
│   ├── registry.sh          # Module discovery
│   └── lib/                 # Libraries
├── modules/
│   ├── time/
│   ├── dns/
│   ├── network/
│   ├── container/
│   ├── audit/
│   ├── rootkit/
│   └── recon/
└── config/
    └── pbp.conf

/var/lib/pbp/                # State and backups
├── state/
│   ├── modules.state        # Module status
│   └── backups/             # Config snapshots
└── data/

/var/log/pbp/                # Logs and reports
├── audit.log                # Action trail
├── actions.jsonl            # Structured logs
└── reports/
    ├── json/                # JSON reports
    ├── html/                # HTML reports
    └── checksums/           # Integrity hashes
```

---

## 🔧 CLI Reference

### Module Management

```bash
pbp list                     # List all modules
pbp enable <module>          # Enable a module
pbp disable <module>         # Disable a module
pbp rollback <module>        # Revert to backup
```

### Security Operations

```bash
pbp scan                     # Scan all enabled modules
pbp scan <module>            # Scan specific module
pbp status                   # Show system status
pbp health                   # Run health checks
```

### Reporting

```bash
pbp reports                  # List all reports
pbp report <id>              # View specific report
pbp report <id> html         # Open HTML report
pbp compare <id1> <id2>      # Compare two reports
```

### Interactive

```bash
pbp dashboard                # Launch TUI dashboard
```

---

## 📈 Risk Scoring

Findings are weighted by severity:

| Severity | Weight | Example |
|----------|--------|---------|
| CRITICAL | 10 | Rootkit detected, firewall disabled |
| HIGH | 5 | Unencrypted DNS, privileged containers |
| MEDIUM | 2 | Many open ports, missing audit rules |
| LOW | 1 | IPv6 disabled, large log files |

**Risk Bands:**
- **0-20**: SECURE ✓
- **21-50**: MODERATE ⚠
- **51-100**: ELEVATED ⚠⚠
- **100+**: CRITICAL ⚠⚠⚠

---

## 🔒 Security Principles

1. **Defense-in-Depth** - Multiple layers of security
2. **Least Privilege** - Root only when necessary
3. **Fail-Safe Defaults** - Reject unknown, block on errors
4. **Idempotency** - Safe to run operations multiple times
5. **Observability** - Complete audit trail
6. **Reproducibility** - Declarative configuration
7. **Zero Trust** - Verify everything

---

## 🧪 Testing

```bash
# Validate core engine
bash tests/validate_core.sh

# Generate test report
bash tests/test_report.sh

# Run demo
bash demo.sh
```

---

## 📄 License

MIT License - See LICENSE file for details

---

**"May your booty be guarded and your lines be encrypted."** 🦜🏴‍☠️
