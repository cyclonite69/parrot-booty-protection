# REPO_INVENTORY.md
## Complete Repository Structural Inventory
**Generated:** 2026-02-26  
**Auditor:** Kiro Systems Auditor  
**Purpose:** Determine real operational state of PBP repository

---

## EXECUTIVE SUMMARY

**Total Files Scanned:** 950+  
**Shell Scripts:** 145  
**Systemd Units:** 6 services, 4 timers  
**Python Files:** 2  
**HTML Files:** 1  
**JSON Manifests:** 10  
**Markdown Docs:** 30+  

**Critical Finding:** THREE PARALLEL IMPLEMENTATIONS DETECTED
1. **Core PBP System** (`/core`, `/modules`, `/bin/pbp`) - ACTIVE
2. **Hardening Framework** (`/hardening-framework`) - ORPHANED
3. **PBP-Ops** (`/pbp-ops`) - PARTIAL/ABANDONED
4. **PBP-Core** (`/pbp-core`) - SHADOW IMPLEMENTATION

---

## DIRECTORY TREE

```
/home/dbcooper/parrot-booty-protection/
├── bin/                          [ACTIVE - Main executables]
│   ├── pbp                       ✓ ACTIVE - Main CLI entrypoint
│   ├── pbp-control               ✓ ACTIVE - Web control plane
│   ├── pbp-dashboard             ✓ ACTIVE - TUI dashboard
│   ├── pbp-report                ✓ ACTIVE - Report wrapper
│   └── dns-sovereignty-guard     ✓ ACTIVE - DNS monitoring daemon
│
├── core/                         [ACTIVE - Core engine]
│   ├── engine.sh                 ✓ ACTIVE - Module orchestration
│   ├── state.sh                  ✓ ACTIVE - State management
│   ├── registry.sh               ✓ ACTIVE - Module discovery
│   ├── health.sh                 ✓ ACTIVE - Health checks
│   ├── rollback.sh               ✓ ACTIVE - Rollback system
│   ├── policy.sh                 ✓ ACTIVE - Policy enforcement
│   ├── integrity.sh              ✓ ACTIVE - File integrity
│   ├── alerts.sh                 ✓ ACTIVE - Alert system
│   └── lib/                      [ACTIVE - Core libraries]
│       ├── logging.sh            ✓ ACTIVE
│       ├── validation.sh         ✓ ACTIVE
│       ├── backup.sh             ✓ ACTIVE
│       ├── report.sh             ✓ ACTIVE
│       ├── report_viewer.sh      ✓ ACTIVE
│       └── html_report.sh        ✓ ACTIVE
│
├── modules/                      [ACTIVE - Security modules]
│   ├── _template/                ✓ REFERENCE - Module template
│   ├── time/                     ✓ ACTIVE - NTS time sync
│   ├── dns/                      ✓ ACTIVE - Encrypted DNS
│   ├── network/                  ✓ ACTIVE - nftables firewall
│   ├── container/                ✓ ACTIVE - Podman security
│   ├── audit/                    ✓ ACTIVE - auditd monitoring
│   ├── rootkit/                  ✓ ACTIVE - Malware detection
│   └── recon/                    ✓ ACTIVE - Network scanning
│       └── [Each contains: manifest.json, install.sh, enable.sh, disable.sh, health.sh, scan.sh]
│
├── reporting/                    [ACTIVE - Report generation]
│   ├── engine.sh                 ✓ ACTIVE - Report orchestrator
│   ├── parsers/                  
│   │   ├── rkhunter.sh           ✓ ACTIVE
│   │   └── nmap.sh               ✓ ACTIVE
│   └── templates/
│       └── report.html.j2        ✓ ACTIVE - HTML template
│
├── bughunt/                      [ACTIVE - System validator]
│   └── bughunt.sh                ✓ ACTIVE - Comprehensive validation
│
├── scripts/                      [MIXED - Installation & utilities]
│   ├── install.sh                ✓ ACTIVE - Main installer
│   ├── install_control.sh        ✓ ACTIVE - Control plane installer
│   ├── install_reporting_deps.sh ✓ ACTIVE - Report dependencies
│   ├── install_dns_guard.sh      ✓ ACTIVE - DNS guard installer
│   ├── uninstall_dns_guard.sh    ✓ ACTIVE - DNS guard uninstaller
│   ├── install_dns_enhancements.sh ⚠ PARTIAL - DNS enhancement installer
│   ├── install_ops.sh            ⚠ ORPHANED - PBP-Ops installer (unused)
│   ├── sync-wiki.sh              ✓ ACTIVE - Wiki synchronization
│   ├── dns_harden.sh             ⚠ DUPLICATE - Superseded by modules/dns
│   ├── dns_monitor.sh            ⚠ DUPLICATE - Superseded by dns-sovereignty-guard
│   ├── dns_status.sh             ⚠ DUPLICATE - Superseded by modules/dns/health.sh
│   ├── dns_alert.sh              ⚠ DUPLICATE - Superseded by dns-sovereignty-guard
│   ├── dns_restore.sh            ⚠ DUPLICATE - Superseded by core/rollback.sh
│   ├── dns_tls_monitor.sh        ⚠ DUPLICATE - Superseded by dns-sovereignty-guard
│   ├── dns_monitoring_install.sh ⚠ DUPLICATE - Superseded by install_dns_guard.sh
│   ├── dns_monitoring_uninstall.sh ⚠ DUPLICATE - Superseded by uninstall_dns_guard.sh
│   ├── docker_dns_fix.sh         ⚠ ORPHANED - Docker-specific (PBP uses Podman)
│   ├── ntp_harden.sh             ⚠ DUPLICATE - Superseded by modules/time
│   ├── port_harden.sh            ⚠ DUPLICATE - Superseded by modules/network
│   └── service_harden.sh         ⚠ DUPLICATE - Superseded by modules/audit
│
├── systemd/                      [ACTIVE - Systemd units]
│   ├── pbp-integrity.service     ✓ ACTIVE - Integrity monitoring
│   ├── pbp-scan-daily.service    ✓ ACTIVE - Daily scans
│   ├── pbp-scan-daily.timer      ✓ ACTIVE
│   ├── pbp-audit-weekly.service  ✓ ACTIVE - Weekly audits
│   ├── pbp-audit-weekly.timer    ✓ ACTIVE
│   └── dns-sovereignty-guard.service ✓ ACTIVE - DNS monitoring
│
├── config/                       [ACTIVE - Configuration]
│   ├── pbp.conf                  ✓ ACTIVE - Main config
│   └── policy.yaml               ✓ ACTIVE - Policy definitions
│
├── configs/                      [REFERENCE - Template configs]
│   ├── unbound.conf              ✓ REFERENCE - DNS template
│   └── nftables.conf             ✓ REFERENCE - Firewall template
│
├── ui/                           [ACTIVE - Web interface]
│   └── index.html                ✓ ACTIVE - Control plane UI
│
├── tests/                        [ACTIVE - Test suite]
│   ├── validate_core.sh          ✓ ACTIVE - Core validation
│   ├── test_core.sh              ✓ ACTIVE - Core tests
│   └── test_report.sh            ✓ ACTIVE - Report tests
│
├── docs/                         [MIXED - Documentation]
│   ├── ARCHITECTURE.md           ✓ AUTHORITATIVE - System architecture
│   ├── CONTROL_RESTORATION.md    ✓ AUTHORITATIVE - Control system docs
│   ├── QUICKSTART_CONTROL.md     ✓ AUTHORITATIVE - Quick start guide
│   ├── REPORTING_SYSTEM.md       ✓ AUTHORITATIVE - Reporting docs
│   ├── DNS_SOVEREIGNTY_GUARD.md  ✓ AUTHORITATIVE - DNS guard docs
│   ├── DNS_GUARD_QUICKREF.md     ✓ REFERENCE - Quick reference
│   ├── CONTROL_RESTORATION_SUMMARY.md ⚠ DUPLICATE - Superseded by CONTROL_RESTORATION.md
│   ├── PHASE2_COMPLETE.md        ⚠ HISTORICAL - Phase completion marker
│   ├── PHASE3_COMPLETE.md        ⚠ HISTORICAL - Phase completion marker
│   ├── PHASE4_COMPLETE.md        ⚠ HISTORICAL - Phase completion marker
│   ├── PROJECT_COMPLETE.md       ⚠ HISTORICAL - Phase completion marker
│   └── REPORTING_COMPLETE.md     ⚠ HISTORICAL - Phase completion marker
│
├── hardening-framework/          [⚠ ORPHANED - Parallel implementation]
│   ├── hardenctl                 ✗ ORPHANED - Superseded by bin/pbp
│   ├── hardenctl_simple          ✗ ORPHANED - Unused variant
│   ├── README.md                 ⚠ HISTORICAL
│   ├── core/
│   │   ├── logger.sh             ✗ ORPHANED - Superseded by core/lib/logging.sh
│   │   └── state_manager.sh      ✗ ORPHANED - Superseded by core/state.sh
│   ├── modules/                  [✗ ORPHANED - All superseded by /modules]
│   │   ├── template.sh
│   │   ├── 01_sysctl_harden.sh
│   │   ├── 02_ssh_harden.sh
│   │   ├── 04_ntp_harden.sh      ✗ Superseded by modules/time
│   │   ├── 05_dns_harden.sh      ✗ Superseded by modules/dns
│   │   ├── 06_firewall_harden.sh ✗ Superseded by modules/network
│   │   ├── 07_ipv6_grub.sh
│   │   ├── 10_malware_detect.sh  ✗ Superseded by modules/rootkit
│   │   ├── 20_container_stabilization.sh ✗ Superseded by modules/container
│   │   ├── 30_service_harden.sh
│   │   ├── 40_dns_monitoring.sh  ✗ Superseded by dns-sovereignty-guard
│   │   ├── 50_usb_guard.sh
│   │   ├── 60_auditd.sh          ✗ Superseded by modules/audit
│   │   ├── 70_mount_harden.sh
│   │   ├── 80_fail2ban.sh
│   │   ├── 85_mac_randomize.sh
│   │   └── 90_log_explorer.sh
│   ├── state/
│   │   ├── enabled.json          ⚠ ORPHANED STATE
│   │   └── services_to_harden.list
│   ├── profiles/                 ✗ EMPTY
│   └── logs/                     ✗ EMPTY
│
├── pbp-ops/                      [⚠ PARTIAL - Abandoned Python implementation]
│   ├── ui/
│   │   └── app.py                ⚠ PARTIAL - FastAPI/Uvicorn web app (unused)
│   ├── lib/
│   │   └── pbp_core.py           ⚠ PARTIAL - Python core library (unused)
│   ├── modules/                  [⚠ DUPLICATE - Shell wrappers]
│   │   ├── time/
│   │   ├── dns/
│   │   ├── network/
│   │   ├── rootkit/
│   │   ├── firewall/
│   │   ├── system/
│   │   ├── container/
│   │   └── ipv6/
│   │       └── [Each contains: install.sh, run.sh, status.sh - DUPLICATES]
│   ├── state/
│   │   └── registry.json         ⚠ EMPTY
│   ├── reports/                  ✗ EMPTY DIRECTORIES
│   ├── logs/                     ✗ EMPTY
│   ├── scripts/                  ✗ EMPTY
│   ├── configs/                  ✗ EMPTY
│   └── scheduler/                ✗ EMPTY
│
├── pbp-core/                     [⚠ SHADOW - Duplicate implementation]
│   ├── bin/
│   │   ├── pbp.sh                ⚠ DUPLICATE - Superseded by /bin/pbp
│   │   ├── pbp-dashboard.sh      ⚠ DUPLICATE - Superseded by /bin/pbp-dashboard
│   │   ├── pbp-sentinel.sh       ⚠ PARTIAL - Threat detection (unused)
│   │   ├── pbp-respond.sh        ⚠ PARTIAL - Incident response (unused)
│   │   └── pbp-learn.sh          ⚠ PARTIAL - ML baseline learning (unused)
│   ├── lib/
│   │   └── pbp-lib.sh            ⚠ DUPLICATE - Superseded by core/lib/*
│   ├── modules/
│   │   ├── pbp-integrity.sh      ⚠ DUPLICATE - Superseded by core/integrity.sh
│   │   ├── pbp-network.sh        ⚠ DUPLICATE - Superseded by modules/network
│   │   ├── pbp-container.sh      ⚠ DUPLICATE - Superseded by modules/container
│   │   ├── pbp-privesc.sh        ⚠ PARTIAL - Privilege escalation detection (unused)
│   │   ├── pbp-persistence.sh    ⚠ PARTIAL - Persistence detection (unused)
│   │   └── pbp-outbound.sh       ⚠ PARTIAL - Outbound connection monitoring (unused)
│   └── systemd/
│       ├── pbp-integrity.service ⚠ DUPLICATE - Superseded by /systemd/pbp-integrity.service
│       ├── pbp-integrity.timer   ⚠ DUPLICATE
│       ├── pbp-watch.service     ⚠ PARTIAL - Unused
│       └── pbp-watch.timer       ⚠ PARTIAL - Unused
│
├── install_pbp.sh                ⚠ ORPHANED - Old installer for pbp-core
├── demo.sh                       ✓ ACTIVE - Demo script
│
└── ROOT LEVEL DOCUMENTATION      [MIXED - 22 markdown files]
    ├── README.md                 ✓ AUTHORITATIVE - Main documentation
    ├── README_OLD.md             ⚠ HISTORICAL - Superseded
    ├── LICENSE                   ✓ ACTIVE
    ├── CHANGELOG.md              ✓ ACTIVE
    ├── CONTRIBUTING.md           ✓ ACTIVE
    ├── CODE_OF_CONDUCT.md        ✓ ACTIVE
    ├── SECURITY.md               ✓ ACTIVE
    ├── WIKI.md                   ✓ ACTIVE
    ├── GEMINI.md                 ⚠ HISTORICAL - AI interaction log
    ├── MONITORING.md             ⚠ HISTORICAL - Superseded by docs/
    ├── TEST_RESULTS.md           ⚠ HISTORICAL - Test output
    ├── UNBOUND_TLS_STATUS.md     ⚠ HISTORICAL - DNS test output
    ├── START_HERE.md             ⚠ HISTORICAL - Phase marker
    ├── DELIVERABLES.md           ⚠ HISTORICAL - Phase marker
    ├── CONTROL_RESTORATION_COMPLETE.md ⚠ HISTORICAL - Phase marker
    ├── DNS_INCIDENT_COMPLETE.md  ⚠ HISTORICAL - Incident report
    ├── DNS_SOVEREIGNTY_GUARD_COMPLETE.md ⚠ HISTORICAL - Phase marker
    ├── INCIDENT_RESPONSE_SUMMARY.md ⚠ HISTORICAL - Incident report
    ├── ROOT_CAUSE_REPORT.md      ⚠ HISTORICAL - Incident report
    ├── DNS_VALIDATION_CHECKLIST.md ⚠ HISTORICAL - Checklist
    ├── MONITORING_GAP_REPORT.md  ⚠ HISTORICAL - Gap analysis
    ├── DNS_ARCHITECTURE_FIXED.md ⚠ HISTORICAL - Architecture doc
    └── DNS_HARDENING.md          ⚠ HISTORICAL - Hardening guide

.github/                          [ACTIVE - GitHub integration]
├── workflows/
│   ├── shellcheck.yml            ✓ ACTIVE - CI/CD
│   └── wiki-sync.yml             ✓ ACTIVE - Wiki automation
└── ISSUE_TEMPLATE/               ✓ ACTIVE
```

---

## FILE CLASSIFICATION SUMMARY

### ✓ ACTIVE (Core Operational)
- `/bin/*` - 5 executables
- `/core/*` - 8 core scripts + 6 libraries
- `/modules/*` - 7 security modules (35 scripts total)
- `/reporting/*` - 1 engine + 2 parsers + 1 template
- `/bughunt/bughunt.sh`
- `/systemd/*` - 6 units
- `/config/*` - 2 files
- `/ui/index.html`
- `/tests/*` - 3 test scripts
- `/scripts/install*.sh` - 4 installers
- `/scripts/sync-wiki.sh`
- `/bin/dns-sovereignty-guard`
- `README.md`, `LICENSE`, `CHANGELOG.md`, `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`, `SECURITY.md`, `WIKI.md`
- `docs/ARCHITECTURE.md`, `docs/CONTROL_RESTORATION.md`, `docs/QUICKSTART_CONTROL.md`, `docs/REPORTING_SYSTEM.md`, `docs/DNS_SOVEREIGNTY_GUARD.md`

**Total: ~90 active operational files**

### ✓ REFERENCE (Templates/Examples)
- `/modules/_template/*` - 5 template files
- `/configs/*` - 2 configuration templates
- `docs/DNS_GUARD_QUICKREF.md`

**Total: ~8 reference files**

### ⚠ DUPLICATE (Superseded by newer implementations)
- `/scripts/dns_*.sh` - 8 DNS scripts (superseded by modules/dns + dns-sovereignty-guard)
- `/scripts/ntp_harden.sh` (superseded by modules/time)
- `/scripts/port_harden.sh` (superseded by modules/network)
- `/scripts/service_harden.sh` (superseded by modules/audit)
- `/pbp-core/*` - Entire directory (superseded by /core + /bin)
- `/pbp-ops/modules/*` - 8 module directories (superseded by /modules)

**Total: ~60 duplicate files**

### ⚠ PARTIAL (Incomplete implementations)
- `/pbp-core/bin/pbp-sentinel.sh` - Threat detection (stub)
- `/pbp-core/bin/pbp-respond.sh` - Incident response (stub)
- `/pbp-core/bin/pbp-learn.sh` - ML baseline (stub)
- `/pbp-core/modules/pbp-privesc.sh` - Privesc detection (stub)
- `/pbp-core/modules/pbp-persistence.sh` - Persistence detection (stub)
- `/pbp-core/modules/pbp-outbound.sh` - Connection monitoring (stub)
- `/pbp-ops/ui/app.py` - FastAPI web app (incomplete)
- `/pbp-ops/lib/pbp_core.py` - Python library (incomplete)
- `/scripts/install_dns_enhancements.sh` - DNS enhancements (partial)

**Total: ~12 partial files**

### ✗ ORPHANED (No references, not executed)
- `/hardening-framework/*` - Entire directory (80+ files)
- `/pbp-ops/*` - Entire directory except modules (20+ files)
- `/scripts/docker_dns_fix.sh` - Docker-specific (PBP uses Podman)
- `/scripts/install_ops.sh` - PBP-Ops installer (unused)
- `/install_pbp.sh` - Old pbp-core installer

**Total: ~110 orphaned files**

### ⚠ HISTORICAL (Documentation artifacts)
- Root-level completion markers: 15 files
- `docs/PHASE*_COMPLETE.md` - 4 files
- `docs/CONTROL_RESTORATION_SUMMARY.md`
- `docs/REPORTING_COMPLETE.md`
- `README_OLD.md`
- `GEMINI.md`
- Various incident reports and checklists

**Total: ~25 historical files**

### ✗ GENERATED (Git objects, empty directories)
- `.git/objects/*` - 500+ git objects
- Empty directories in pbp-ops, hardening-framework

**Total: 500+ generated files**

---

## CRITICAL FINDINGS

### 1. THREE PARALLEL IMPLEMENTATIONS
The repository contains THREE competing implementations of the same functionality:

**A. Core PBP System** (ACTIVE)
- Location: `/core`, `/modules`, `/bin`
- Status: **OPERATIONAL**
- Architecture: Modular, policy-driven, operator sovereignty
- Used by: Main `pbp` CLI

**B. Hardening Framework** (ORPHANED)
- Location: `/hardening-framework`
- Status: **ABANDONED**
- Architecture: Numbered modules, whiptail TUI
- Used by: Nothing (hardenctl not referenced)
- **VERDICT: DELETE CANDIDATE**

**C. PBP-Ops** (PARTIAL)
- Location: `/pbp-ops`
- Status: **INCOMPLETE**
- Architecture: Python FastAPI + shell wrappers
- Used by: Nothing (app.py never deployed)
- **VERDICT: DELETE CANDIDATE**

**D. PBP-Core** (SHADOW)
- Location: `/pbp-core`
- Status: **SUPERSEDED**
- Architecture: Threat detection + incident response
- Used by: Nothing (pbp-sentinel.sh never deployed)
- **VERDICT: MERGE OR DELETE**

### 2. DNS IMPLEMENTATION CHAOS
**8 DNS scripts in `/scripts`** superseded by:
- `modules/dns/*` (5 scripts)
- `bin/dns-sovereignty-guard` (1 daemon)
- `scripts/install_dns_guard.sh` (1 installer)

**Recommendation:** Delete 8 old DNS scripts

### 3. DOCUMENTATION EXPLOSION
**22 root-level markdown files**, including:
- 15 completion markers / phase reports
- 5 incident reports
- 2 README files

**Recommendation:** Archive historical docs to `docs/archive/`

### 4. EMPTY DIRECTORIES
- `pbp-ops/reports/*` - 8 empty subdirectories
- `pbp-ops/logs`, `scripts`, `configs`, `scheduler` - all empty
- `hardening-framework/profiles`, `logs` - empty

**Recommendation:** Remove empty directories

---

## EXECUTION ENTRY POINTS

### Primary Executables (ACTIVE)
1. `/bin/pbp` - Main CLI (sources `/core/engine.sh`)
2. `/bin/pbp-control` - Web control plane (Python HTTP server)
3. `/bin/pbp-dashboard` - TUI dashboard (sources `/core/state.sh`, `/core/health.sh`)
4. `/bin/pbp-report` - Report wrapper (execs `/reporting/engine.sh`)
5. `/bin/dns-sovereignty-guard` - DNS monitoring daemon

### Orphaned Executables (NOT USED)
1. `/hardening-framework/hardenctl` - Whiptail TUI (no references)
2. `/hardening-framework/hardenctl_simple` - Simplified variant (no references)
3. `/pbp-core/bin/pbp.sh` - Duplicate CLI (no references)
4. `/pbp-core/bin/pbp-sentinel.sh` - Threat detection (no references)
5. `/pbp-core/bin/pbp-respond.sh` - Incident response (no references)
6. `/pbp-core/bin/pbp-learn.sh` - ML baseline (no references)

### Installers (ACTIVE)
1. `/scripts/install.sh` - Main PBP installer
2. `/scripts/install_control.sh` - Control plane installer
3. `/scripts/install_reporting_deps.sh` - Report dependencies
4. `/scripts/install_dns_guard.sh` - DNS guard installer

### Orphaned Installers
1. `/scripts/install_ops.sh` - PBP-Ops installer (references non-existent Python app)
2. `/install_pbp.sh` - Old pbp-core installer (references pbp-sentinel.sh)

---

## SYSTEMD UNITS

### Active Units
1. `systemd/pbp-integrity.service` - File integrity monitoring
2. `systemd/pbp-scan-daily.service` + `.timer` - Daily security scans
3. `systemd/pbp-audit-weekly.service` + `.timer` - Weekly audits
4. `systemd/dns-sovereignty-guard.service` - DNS monitoring daemon

### Duplicate Units (ORPHANED)
1. `pbp-core/systemd/pbp-integrity.service` - Duplicate
2. `pbp-core/systemd/pbp-integrity.timer` - Duplicate
3. `pbp-core/systemd/pbp-watch.service` - Unused
4. `pbp-core/systemd/pbp-watch.timer` - Unused

---

## CONFIGURATION FILES

### Active Configuration
- `/config/pbp.conf` - Main configuration
- `/config/policy.yaml` - Policy definitions

### Reference Templates
- `/configs/unbound.conf` - DNS template
- `/configs/nftables.conf` - Firewall template

### Orphaned State
- `/hardening-framework/state/enabled.json` - Old state file
- `/pbp-ops/state/registry.json` - Empty state file

---

## NEXT STEPS

Proceed to **PHASE 2: EXECUTION_GRAPH.md** to trace actual execution paths and identify dead code.
