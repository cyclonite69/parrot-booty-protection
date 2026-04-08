# 🏴‍☠️ Parrot Booty Protection (PBP)

### Enterprise-Grade Linux Security Control Platform

[![OS: Parrot OS / Debian](https://img.shields.io/badge/OS-Parrot%20OS%20%7C%20Debian-blue.svg)](https://parrotsec.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Version: 2.0.0](https://img.shields.io/badge/Version-2.0.0-brightgreen.svg)](https://github.com/cyclonite69/parrot-booty-protection)
[![Security: Audited](https://img.shields.io/badge/Security-Audited-red.svg)](docs/)

**Parrot Booty Protection** is a production-ready security control platform that enforces operator sovereignty over Linux hardening. Built with defense-in-depth principles and **zero-tolerance for autonomous configuration changes**, it provides automated scanning, professional reporting, real-time monitoring, and a local web control plane.

---

## 🎯 What Makes PBP Different?

Traditional security tools make changes without asking. PBP **enforces operator authority**:

- **🛡️ Operator Sovereignty** - No autonomous configuration changes, ever
- **📋 Policy-Driven** - Single source of truth for all security decisions
- **🔐 Integrity Monitoring** - Protected files watched continuously
- **⚠️ Alert Framework** - Instant notification of violations
- **🖥️ Control Plane** - Local web dashboard (no cloud dependencies)
- **🔄 Rollback Capability** - Every change is reversible
- **📊 Risk Quantification** - Know your security posture with numerical scores
- **📄 Professional Reports** - PDF/HTML reports for compliance

**PBP is not a script collection. It's a security control platform.**

---

## 🛡️ Security Modules

PBP provides 12 independent security modules, each with full lifecycle management:

| Module | Purpose | Technology | Risk Mitigation |
|--------|---------|------------|-----------------|
| **⏰ TIME** | NTS-authenticated time sync | chrony + NTS | Prevents time-based attacks, ensures certificate validity |
| **🔒 DNS** | Encrypted DNS queries | unbound + DoT | Blocks DNS hijacking, surveillance, cache poisoning |
| **🛡️ NETWORK** | Stateful firewall | nftables | Default-deny policy, connection tracking, egress filtering |
| **📦 CONTAINER** | Rootless container security | Podman + seccomp | Prevents privilege escalation, container breakouts |
| **📋 AUDIT** | System activity monitoring | auditd | Detects unauthorized changes, tracks privileged commands |
| **🔍 ROOTKIT** | Malware detection | rkhunter + chkrootkit | Identifies rootkits, hidden processes, file tampering |
| **🌐 RECON** | Network exposure validation | nmap | Maps attack surface, detects misconfigurations |
| **🔌 USB** | Device allowlist enforcement | USBGuard | Blocks unauthorized USB devices |
| **🚫 FAIL2BAN** | Brute-force lockout | fail2ban | Reduces password-guessing attacks |
| **🗂️ MOUNT** | Filesystem hardening checks | sysctl + mount policy | Reduces local abuse paths |
| **🎭 MAC** | MAC randomization controls | NetworkManager | Reduces tracking correlation |
| **📜 LOGS** | Log policy checks | logrotate + ledger checks | Improves retention hygiene |

Each module includes:
- ✅ Installation automation
- ✅ Configuration management
- ✅ Health monitoring
- ✅ Security scanning
- ✅ Rollback capability

---

## 🚀 Quick Start

### Installation

```bash
# Clone repository
git clone https://github.com/cyclonite69/parrot-booty-protection.git
cd parrot-booty-protection

# Install PBP
sudo bash scripts/install.sh

# Install control system (operator sovereignty)
sudo bash scripts/install_control.sh

# Install reporting dependencies (PDF generation)
sudo bash scripts/install_reporting_deps.sh
```

### Basic Usage

```bash
# Start control plane
pbp control start
# Access: http://localhost:7777

# List available modules
pbp list

# Enable core security modules
sudo pbp enable time      # NTS time synchronization
sudo pbp enable dns       # Unbound DNS with DoH/DoT
sudo pbp enable network   # Firewall

# Run security scan
sudo pbp scan

# View system status
pbp status

# Check integrity
pbp integrity

# View alerts
pbp alerts

# Launch interactive dashboard
pbp dashboard
```

### Enable Automated Monitoring

```bash
# Integrity monitoring (continuous)
sudo systemctl enable --now pbp-integrity.service

# Daily security scans
sudo systemctl enable --now pbp-scan-daily.timer

# Weekly deep audits (rootkit + audit)
sudo systemctl enable --now pbp-audit-weekly.timer

# Check timer status
systemctl list-timers pbp-*
```

---

## 📊 Reporting System

PBP includes a universal reporting engine that generates professional PDF and JSON reports from all security scanners.

### Generate Reports

```bash
# Run scanner and generate report
sudo rkhunter --check > /tmp/rkhunter.txt
sudo pbp-report rkhunter /tmp/rkhunter.txt

# Output: /var/log/pbp/reports/<timestamp>/
#   ├── raw/rkhunter.txt
#   ├── json/rkhunter.json
#   ├── html/rkhunter.html
#   ├── pdf/rkhunter.pdf
#   └── checksums/rkhunter.*.sha256
```

### Bug Hunt Mode

Comprehensive system validation in one command:

```bash
sudo pbp bughunt
```

**Validates**:
- ✅ Configuration integrity
- ✅ Firewall rules (duplicates, policies)
- ✅ Service health
- ✅ NTS time synchronization
- ✅ DNS hardening (DoT, DNSSEC)
- ✅ Container privileges
- ✅ Open ports
- ✅ File permissions

**Generates**:
- `master-report.json` - Machine-readable findings
- `master-report.html` - Human-readable report
- `master-report.pdf` - Professional PDF for compliance

---

## 🎨 Interactive Dashboard

Real-time security monitoring in your terminal:

```bash
pbp dashboard
```

**Features**:
- 📊 Module status (enabled/installed/uninstalled)
- ❤️ Health checks per module
- 📈 Latest risk score
- ⚡ Quick actions (scan/reports/health)

---

## 📈 Risk Scoring

PBP quantifies your security posture with weighted risk scores:

| Severity | Weight | Examples |
|----------|--------|----------|
| **CRITICAL** | 10 points | Rootkit detected, firewall disabled, DNS failing |
| **HIGH** | 5 points | Unencrypted DNS, privileged containers, insecure services |
| **MEDIUM** | 2 points | Many open ports, missing audit rules, outdated scanners |
| **LOW** | 1 point | IPv6 disabled, large logs, minor misconfigurations |

**Risk Bands**:
- **0-20**: 🟢 SECURE - System is well-hardened
- **21-50**: 🟡 MODERATE - Some issues need attention
- **51-100**: 🟠 ELEVATED - Significant vulnerabilities present
- **100+**: 🔴 CRITICAL - Immediate action required

---

## 🔧 CLI Reference

### Module Management

```bash
pbp list                     # List all modules
pbp enable <module>          # Enable a module (requires approval)
pbp disable <module>         # Disable a module (requires approval)
pbp rollback <module>        # Revert to previous configuration
```

### Security Operations

```bash
pbp scan                     # Scan all enabled modules
pbp scan <module>            # Scan specific module
pbp status                   # Show system status
pbp health [module]          # Run health checks (all or one module)
pbp bughunt                  # Comprehensive validation
```

### Control & Monitoring

```bash
pbp control start            # Start web control plane
pbp control stop             # Stop web control plane
pbp integrity                # Check file integrity
pbp alerts                   # View security alerts
pbp dashboard                # Launch TUI dashboard
```

### Reporting

```bash
pbp reports                  # List all reports
pbp report <id>              # View specific report
pbp report <id> html         # Open HTML report in browser
pbp compare <id1> <id2>      # Compare two reports
pbp-report <scanner> <file>  # Generate report from scanner output
```

---

## 🏗️ Architecture

### Modular Design

```
┌─────────────────────────────────────────────────────────┐
│                     PBP Core Engine                     │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐ │
│  │    State     │  │   Registry   │  │    Health    │ │
│  │  Management  │  │  & Discovery │  │    Checks    │ │
│  └──────────────┘  └──────────────┘  └──────────────┘ │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐ │
│  │   Backup &   │  │   Rollback   │  │   Logging    │ │
│  │   Restore    │  │    System    │  │   & Audit    │ │
│  └──────────────┘  └──────────────┘  └──────────────┘ │
└─────────────────────────────────────────────────────────┘
                            │
        ┌───────────────────┼───────────────────┐
        │                   │                   │
┌───────▼────────┐  ┌───────▼────────┐  ┌──────▼───────┐
│   Security     │  │   Reporting    │  │     TUI      │
│    Modules     │  │     Engine     │  │   Dashboard  │
│                │  │                │  │              │
│ • time         │  │ • PDF Gen      │  │ • Real-time  │
│ • dns          │  │ • HTML Gen     │  │ • Health     │
│ • network      │  │ • Parsers      │  │ • Actions    │
│ • container    │  │ • Bug Hunt     │  │              │
│ • audit        │  │                │  │              │
│ • rootkit      │  │                │  │              │
│ • recon        │  │                │  │              │
│ • usb          │  │                │  │              │
│ • fail2ban     │  │                │  │              │
│ • mount        │  │                │  │              │
│ • mac          │  │                │  │              │
│ • logs         │  │                │  │              │
└────────────────┘  └────────────────┘  └──────────────┘
```

### Module Lifecycle

```
UNINSTALLED → install → INSTALLED → enable → ENABLED
                ↑                      ↓
                └──────── rollback ────┘
```

---

## 📁 Directory Structure

```
/opt/pbp/                    # Installation root
├── bin/
│   ├── pbp                  # Main CLI
│   ├── pbp-dashboard        # TUI dashboard
│   └── pbp-report           # Report generator
├── core/
│   ├── engine.sh            # Orchestration engine
│   ├── state.sh             # State management
│   ├── registry.sh          # Module discovery
│   └── lib/                 # Core libraries
├── modules/
│   ├── time/                # NTS time sync
│   ├── dns/                 # Encrypted DNS
│   ├── network/             # nftables firewall
│   ├── container/           # Podman hardening
│   ├── audit/               # auditd monitoring
│   ├── rootkit/             # Malware detection
│   └── recon/               # Network scanning
│   ├── usb/                 # USBGuard allowlisting
│   ├── fail2ban/            # Brute-force protection
│   ├── mount/               # Mount safety controls
│   ├── mac/                 # MAC randomization
│   └── logs/                # Log policy checks
├── reporting/
│   ├── engine.sh            # Report engine
│   ├── parsers/             # Scanner parsers
│   └── templates/           # HTML templates
├── bughunt/
│   └── bughunt.sh           # System validator
└── config/
    └── pbp.conf             # Global configuration

/var/lib/pbp/                # State and backups
├── state/
│   ├── modules.state        # Module status (JSON)
│   └── backups/             # Config snapshots
└── data/

/var/log/pbp/                # Logs and reports
├── audit.log                # Action trail
├── actions.jsonl            # Structured logs
└── reports/
    ├── json/                # JSON reports
    ├── html/                # HTML reports
    ├── pdf/                 # PDF reports
    └── checksums/           # SHA256 hashes
```

---

## 🔒 Security Features

### Defense-in-Depth

- **Input Validation** - All user input sanitized and validated
- **Output Escaping** - HTML reports XSS-safe via Python escaping
- **Privilege Separation** - Root only when necessary, immediate drop
- **Fail-Safe Defaults** - Reject unknown, block on errors
- **Audit Trail** - Complete logging of all actions
- **Immutable Reports** - `chattr +i` after generation
- **Integrity Verification** - SHA256 checksums for all reports

### Rollback Safety

Every configuration change includes:
1. Pre-change backup with checksums
2. Post-change health verification
3. Automatic rollback on failure
4. Manual rollback capability

### Access Control

- Reports: `600` permissions (root-only)
- Directories: `700` permissions
- State files: `600` permissions
- No world-readable security data

---

## 📚 Documentation

- **[Control Restoration](docs/CONTROL_RESTORATION.md)** - Operator sovereignty system
- **[Quick Start Guide](docs/QUICKSTART_CONTROL.md)** - Get started in 5 minutes
- **[Reporting System](docs/REPORTING_SYSTEM.md)** - Report generation guide
- **[Architecture](docs/ARCHITECTURE.md)** - System design and components
- **[Phase Documentation](docs/)** - Complete implementation phases

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

## 🤝 Contributing

Contributions welcome! Please follow the module template structure:

```
modules/your_module/
├── manifest.json       # Metadata and config
├── install.sh          # Package installation
├── enable.sh           # Activation logic
├── disable.sh          # Deactivation logic
├── scan.sh             # Security scanning
└── health.sh           # Health checks
```

---

## 📊 Project Metrics

- **Total Files**: 85+
- **Lines of Code**: ~6,400 (focused, minimal)
- **Security Modules**: 12 fully implemented
- **Hook Scripts**: 35 (5 per module)
- **Core Libraries**: 9
- **CLI Commands**: 13
- **Systemd Units**: 4
- **Test Coverage**: Core + Modules validated
- **Documentation**: 2,000+ lines

---

## 🎯 Use Cases

### For Security Engineers
- Automated hardening of Parrot OS workstations
- Compliance reporting (CIS, NIST)
- Security posture monitoring
- Incident response preparation

### For System Administrators
- One-command security deployment
- Automated daily/weekly scans
- Professional PDF reports for management
- Safe rollback on issues

### For Penetration Testers
- Harden attack platforms
- Validate security controls
- Generate compliance evidence
- Monitor container security

### For DevSecOps Teams
- Infrastructure-as-code security
- CI/CD security validation
- Automated compliance checks
- Security metrics tracking

---

## 🗺️ Roadmap

### Phase 5 (Planned)
- [ ] Web dashboard enhancements (localhost:7777)
- [ ] Policy profiles (home/privacy/pentest/paranoid)
- [ ] Email alerting
- [ ] Baseline tracking & trending
- [ ] SIEM integration (Splunk/ELK)
- [ ] Multi-host management
- [ ] Compliance mapping (CIS/NIST/PCI-DSS)
- [ ] Module marketplace

---

## 📄 License

MIT License - See [LICENSE](LICENSE) for details

---

## 🙏 Acknowledgments

Built with security best practices from:
- [CIS Benchmarks](https://www.cisecurity.org/cis-benchmarks/)
- [NIST Cybersecurity Framework](https://www.nist.gov/cyberframework)
- [OWASP Security Guidelines](https://owasp.org/)
- [Linux Hardening Guides](https://github.com/trimstray/the-book-of-secret-knowledge)

---

<div align="center">

**"May your booty be guarded and your lines be encrypted."** 🦜🏴‍☠️

Made with ❤️ for the security community

[⬆ Back to Top](#-parrot-booty-protection-pbp)

</div>
