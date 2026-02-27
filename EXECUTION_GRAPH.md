# EXECUTION_GRAPH.md
## Execution Trace Analysis
**Generated:** 2026-02-26  
**Purpose:** Map actual execution paths and identify dead code

---

## EXECUTION ENTRY POINTS

### 1. PRIMARY CLI: `/bin/pbp`

**Execution Flow:**
```
/bin/pbp
├── sources: /core/engine.sh
│   ├── sources: /core/lib/logging.sh
│   ├── sources: /core/state.sh
│   ├── sources: /core/registry.sh
│   ├── sources: /core/lib/backup.sh
│   └── sources: /core/health.sh
│
├── cmd_enable <module>
│   └── calls: module_enable() in engine.sh
│       ├── calls: get_module_hook() in registry.sh
│       ├── executes: /modules/<module>/install.sh
│       ├── executes: /modules/<module>/enable.sh
│       ├── calls: create_backup() in lib/backup.sh
│       └── calls: set_module_status() in state.sh
│
├── cmd_disable <module>
│   └── calls: module_disable() in engine.sh
│       ├── executes: /modules/<module>/disable.sh
│       └── calls: set_module_status() in state.sh
│
├── cmd_scan [module]
│   └── calls: scan_all() or module_scan() in engine.sh
│       └── executes: /modules/<module>/scan.sh
│
├── cmd_rollback <module>
│   └── sources: /core/rollback.sh
│       └── calls: rollback_module()
│
├── cmd_control {start|stop|status}
│   └── executes: /bin/pbp-control
│       └── spawns: python3 -m http.server (serves /ui/index.html)
│
├── cmd_integrity
│   └── executes: /core/integrity.sh check
│
├── cmd_alerts
│   └── reads: /var/log/pbp/integrity-alerts.log
│
├── cmd_health
│   └── sources: /core/health.sh
│       └── calls: check_system_health(), check_module_health()
│           └── executes: /modules/<module>/health.sh
│
├── cmd_list
│   └── sources: /core/registry.sh, /core/state.sh
│       └── reads: /modules/*/manifest.json
│
├── cmd_report [id]
│   └── sources: /core/lib/report_viewer.sh
│       └── reads: /var/log/pbp/reports/json/*.json
│
├── cmd_dashboard
│   └── executes: /bin/pbp-dashboard
│       └── sources: /core/state.sh, /core/health.sh, /core/lib/report.sh
│
└── cmd_bughunt
    └── executes: /bughunt/bughunt.sh
        └── runs comprehensive system validation
```

**Files Executed by `pbp` CLI:**
- `/core/engine.sh` ✓
- `/core/state.sh` ✓
- `/core/registry.sh` ✓
- `/core/health.sh` ✓
- `/core/rollback.sh` ✓
- `/core/integrity.sh` ✓
- `/core/lib/logging.sh` ✓
- `/core/lib/backup.sh` ✓
- `/core/lib/validation.sh` ✓
- `/core/lib/report.sh` ✓
- `/core/lib/report_viewer.sh` ✓
- `/core/lib/html_report.sh` ✓
- `/modules/*/install.sh` ✓
- `/modules/*/enable.sh` ✓
- `/modules/*/disable.sh` ✓
- `/modules/*/health.sh` ✓
- `/modules/*/scan.sh` ✓
- `/bin/pbp-control` ✓
- `/bin/pbp-dashboard` ✓
- `/bughunt/bughunt.sh` ✓

---

### 2. REPORT GENERATOR: `/bin/pbp-report`

**Execution Flow:**
```
/bin/pbp-report <scanner> <input_file>
└── executes: /reporting/engine.sh
    ├── sources: /core/lib/logging.sh
    ├── sources: /core/lib/validation.sh
    ├── calls: parse_<scanner>() 
    │   └── executes: /reporting/parsers/<scanner>.sh
    │       └── outputs: JSON to /var/log/pbp/reports/json/
    ├── generates: HTML from /reporting/templates/report.html.j2
    │   └── outputs: /var/log/pbp/reports/html/
    └── generates: PDF via wkhtmltopdf
        └── outputs: /var/log/pbp/reports/pdf/
```

**Files Executed by `pbp-report`:**
- `/reporting/engine.sh` ✓
- `/reporting/parsers/rkhunter.sh` ✓
- `/reporting/parsers/nmap.sh` ✓
- `/reporting/templates/report.html.j2` ✓
- `/core/lib/logging.sh` ✓
- `/core/lib/validation.sh` ✓

---

### 3. DNS MONITORING: `/bin/dns-sovereignty-guard`

**Execution Flow:**
```
/bin/dns-sovereignty-guard {monitor|init|check}
├── monitor_loop()
│   ├── check_resolv_conf()
│   │   └── reads: /etc/resolv.conf
│   ├── check_immutable()
│   │   └── runs: lsattr /etc/resolv.conf
│   ├── check_dns_server()
│   │   └── reads: /etc/resolv.conf
│   ├── check_port_53()
│   │   └── runs: ss -tlnp | grep :53
│   ├── check_nm_dns()
│   │   └── reads: /etc/NetworkManager/conf.d/90-dns-hardening.conf
│   └── check_upstream()
│       └── reads: /etc/unbound/unbound.conf
│
├── alert()
│   ├── writes: /var/log/pbp/dns-alerts.log
│   ├── writes: /var/lib/pbp/dns-guard/events.jsonl
│   └── sends: email (if configured)
│
└── init_baseline()
    ├── writes: /var/lib/pbp/dns-guard/resolv.hash
    ├── writes: /var/lib/pbp/dns-guard/immutable.state
    ├── writes: /var/lib/pbp/dns-guard/expected_dns.txt
    └── writes: /var/lib/pbp/dns-guard/unbound.hash
```

**Files Executed:**
- `/bin/dns-sovereignty-guard` ✓ (standalone, no dependencies)

**Systemd Integration:**
- `systemd/dns-sovereignty-guard.service` ✓ (runs dns-sovereignty-guard monitor)

---

### 4. INSTALLERS

#### A. Main Installer: `/scripts/install.sh`
```
/scripts/install.sh
├── creates: /opt/pbp/
├── copies: /core/* → /opt/pbp/core/
├── copies: /modules/* → /opt/pbp/modules/
├── copies: /bin/* → /opt/pbp/bin/
├── copies: /reporting/* → /opt/pbp/reporting/
├── copies: /bughunt/* → /opt/pbp/bughunt/
├── copies: /config/* → /opt/pbp/config/
├── symlinks: /opt/pbp/bin/pbp → /usr/local/bin/pbp
└── creates: /var/lib/pbp/, /var/log/pbp/
```

#### B. Control Plane Installer: `/scripts/install_control.sh`
```
/scripts/install_control.sh
├── copies: /ui/* → /opt/pbp/ui/
├── copies: /bin/pbp-control → /opt/pbp/bin/
├── copies: /core/policy.sh → /opt/pbp/core/
├── copies: /core/integrity.sh → /opt/pbp/core/
├── copies: /core/alerts.sh → /opt/pbp/core/
└── installs: python3-pip (for HTTP server)
```

#### C. DNS Guard Installer: `/scripts/install_dns_guard.sh`
```
/scripts/install_dns_guard.sh
├── copies: /bin/dns-sovereignty-guard → /usr/local/bin/
├── copies: systemd/dns-sovereignty-guard.service → /etc/systemd/system/
├── creates: /var/lib/pbp/dns-guard/
├── creates: /var/log/pbp/
└── enables: dns-sovereignty-guard.service
```

#### D. Reporting Dependencies: `/scripts/install_reporting_deps.sh`
```
/scripts/install_reporting_deps.sh
├── installs: python3-jinja2
├── installs: wkhtmltopdf
└── installs: jq
```

**Files Executed by Installers:**
- `/scripts/install.sh` ✓
- `/scripts/install_control.sh` ✓
- `/scripts/install_dns_guard.sh` ✓
- `/scripts/install_reporting_deps.sh` ✓

---

### 5. SYSTEMD UNITS

#### A. Integrity Monitoring
```
systemd/pbp-integrity.service
└── ExecStart=/opt/pbp/core/integrity.sh monitor
    └── runs continuous file integrity checks
```

#### B. Daily Scans
```
systemd/pbp-scan-daily.timer
└── triggers: systemd/pbp-scan-daily.service
    └── ExecStart=/opt/pbp/bin/pbp scan
        └── runs full security scan
```

#### C. Weekly Audits
```
systemd/pbp-audit-weekly.timer
└── triggers: systemd/pbp-audit-weekly.service
    └── ExecStart=/opt/pbp/bin/pbp scan audit
        └── runs audit module scan
```

#### D. DNS Monitoring
```
systemd/dns-sovereignty-guard.service
└── ExecStart=/usr/local/bin/dns-sovereignty-guard monitor
    └── runs continuous DNS monitoring
```

**Files Executed by Systemd:**
- `systemd/pbp-integrity.service` ✓ → `/core/integrity.sh`
- `systemd/pbp-scan-daily.service` ✓ → `/bin/pbp`
- `systemd/pbp-audit-weekly.service` ✓ → `/bin/pbp`
- `systemd/dns-sovereignty-guard.service` ✓ → `/bin/dns-sovereignty-guard`

---

### 6. MODULE EXECUTION

Each module follows the same lifecycle:

```
/modules/<module>/
├── manifest.json          [READ by registry.sh]
├── install.sh             [EXEC by engine.sh → module_install()]
├── enable.sh              [EXEC by engine.sh → module_enable()]
├── disable.sh             [EXEC by engine.sh → module_disable()]
├── health.sh              [EXEC by health.sh → check_module_health()]
└── scan.sh                [EXEC by engine.sh → module_scan()]
```

**Active Modules:**
1. `modules/time/*` ✓ (NTS time synchronization)
2. `modules/dns/*` ✓ (Encrypted DNS via Unbound)
3. `modules/network/*` ✓ (nftables firewall)
4. `modules/container/*` ✓ (Podman security)
5. `modules/audit/*` ✓ (auditd monitoring)
6. `modules/rootkit/*` ✓ (rkhunter + chkrootkit)
7. `modules/recon/*` ✓ (nmap scanning)

**Template Module:**
- `modules/_template/*` ✓ (reference only, not executed)

---

## DEAD CODE ANALYSIS

### ✗ NEVER EXECUTED

#### A. Hardening Framework (ENTIRE DIRECTORY)
```
/hardening-framework/
├── hardenctl                      ✗ NO REFERENCES
├── hardenctl_simple               ✗ NO REFERENCES
├── core/logger.sh                 ✗ NO REFERENCES
├── core/state_manager.sh          ✗ NO REFERENCES
└── modules/*.sh (17 files)        ✗ NO REFERENCES
```

**Evidence:**
- `grep -r "hardenctl" /home/dbcooper/parrot-booty-protection --exclude-dir=hardening-framework` → 0 results
- No systemd units reference hardenctl
- No installers reference hardenctl
- `/bin/pbp` does not source hardening-framework

**Verdict:** DEAD CODE - DELETE ENTIRE DIRECTORY

---

#### B. PBP-Ops (PARTIAL DIRECTORY)
```
/pbp-ops/
├── ui/app.py                      ✗ NO REFERENCES (FastAPI app never deployed)
├── lib/pbp_core.py                ✗ NO REFERENCES (Python library unused)
├── modules/*/install.sh           ✗ DUPLICATES (superseded by /modules)
├── modules/*/run.sh               ✗ DUPLICATES
├── modules/*/status.sh            ✗ DUPLICATES
└── state/registry.json            ✗ EMPTY FILE
```

**Evidence:**
- `grep -r "app.py" /home/dbcooper/parrot-booty-protection --exclude-dir=pbp-ops` → 0 results
- `grep -r "pbp_core.py" /home/dbcooper/parrot-booty-protection --exclude-dir=pbp-ops` → 0 results
- `/scripts/install_ops.sh` references `app.py` but is never executed
- No systemd units reference pbp-ops

**Verdict:** DEAD CODE - DELETE ENTIRE DIRECTORY

---

#### C. PBP-Core (SHADOW IMPLEMENTATION)
```
/pbp-core/
├── bin/pbp.sh                     ✗ DUPLICATE (superseded by /bin/pbp)
├── bin/pbp-dashboard.sh           ✗ DUPLICATE (superseded by /bin/pbp-dashboard)
├── bin/pbp-sentinel.sh            ✗ PARTIAL (threat detection stub)
├── bin/pbp-respond.sh             ✗ PARTIAL (incident response stub)
├── bin/pbp-learn.sh               ✗ PARTIAL (ML baseline stub)
├── lib/pbp-lib.sh                 ✗ DUPLICATE (superseded by /core/lib/*)
├── modules/pbp-integrity.sh       ✗ DUPLICATE (superseded by /core/integrity.sh)
├── modules/pbp-network.sh         ✗ DUPLICATE (superseded by /modules/network)
├── modules/pbp-container.sh       ✗ DUPLICATE (superseded by /modules/container)
├── modules/pbp-privesc.sh         ✗ PARTIAL (privesc detection stub)
├── modules/pbp-persistence.sh     ✗ PARTIAL (persistence detection stub)
├── modules/pbp-outbound.sh        ✗ PARTIAL (connection monitoring stub)
└── systemd/*.service              ✗ DUPLICATES (superseded by /systemd)
```

**Evidence:**
- `grep -r "pbp-sentinel" /home/dbcooper/parrot-booty-protection --exclude-dir=pbp-core` → 1 result (install_pbp.sh, which is also dead)
- `grep -r "pbp-respond" /home/dbcooper/parrot-booty-protection --exclude-dir=pbp-core` → 0 results
- `grep -r "pbp-learn" /home/dbcooper/parrot-booty-protection --exclude-dir=pbp-core` → 0 results
- `/bin/pbp` does not source pbp-core

**Verdict:** DEAD CODE - DELETE ENTIRE DIRECTORY (or extract useful stubs for future use)

---

#### D. Old DNS Scripts
```
/scripts/
├── dns_harden.sh                  ✗ SUPERSEDED by modules/dns/enable.sh
├── dns_monitor.sh                 ✗ SUPERSEDED by dns-sovereignty-guard
├── dns_status.sh                  ✗ SUPERSEDED by modules/dns/health.sh
├── dns_alert.sh                   ✗ SUPERSEDED by dns-sovereignty-guard
├── dns_restore.sh                 ✗ SUPERSEDED by core/rollback.sh
├── dns_tls_monitor.sh             ✗ SUPERSEDED by dns-sovereignty-guard
├── dns_monitoring_install.sh      ✗ SUPERSEDED by install_dns_guard.sh
└── dns_monitoring_uninstall.sh    ✗ SUPERSEDED by uninstall_dns_guard.sh
```

**Evidence:**
- `grep -r "dns_harden.sh" /home/dbcooper/parrot-booty-protection --exclude=dns_harden.sh` → 0 results
- `grep -r "dns_monitor.sh" /home/dbcooper/parrot-booty-protection --exclude=dns_monitor.sh` → 0 results
- `/bin/pbp` does not reference any of these scripts
- `modules/dns/enable.sh` contains newer implementation

**Verdict:** DEAD CODE - DELETE 8 DNS SCRIPTS

---

#### E. Old Hardening Scripts
```
/scripts/
├── ntp_harden.sh                  ✗ SUPERSEDED by modules/time
├── port_harden.sh                 ✗ SUPERSEDED by modules/network
├── service_harden.sh              ✗ SUPERSEDED by modules/audit
└── docker_dns_fix.sh              ✗ DOCKER-SPECIFIC (PBP uses Podman)
```

**Evidence:**
- `grep -r "ntp_harden.sh" /home/dbcooper/parrot-booty-protection --exclude=ntp_harden.sh` → 0 results
- `grep -r "port_harden.sh" /home/dbcooper/parrot-booty-protection --exclude=port_harden.sh` → 0 results
- `grep -r "service_harden.sh" /home/dbcooper/parrot-booty-protection --exclude=service_harden.sh` → 0 results
- `grep -r "docker_dns_fix.sh" /home/dbcooper/parrot-booty-protection --exclude=docker_dns_fix.sh` → 0 results

**Verdict:** DEAD CODE - DELETE 4 SCRIPTS

---

#### F. Orphaned Installers
```
/scripts/
├── install_ops.sh                 ✗ INSTALLS pbp-ops (which is dead)
└── /install_pbp.sh                ✗ INSTALLS pbp-core (which is dead)
```

**Evidence:**
- `install_ops.sh` references `/pbp-ops/ui/app.py` (dead code)
- `install_pbp.sh` references `/pbp-core/bin/pbp-sentinel.sh` (dead code)
- Neither installer is referenced in README.md or docs/

**Verdict:** DEAD CODE - DELETE 2 INSTALLERS

---

#### G. Duplicate Systemd Units
```
/pbp-core/systemd/
├── pbp-integrity.service          ✗ DUPLICATE (superseded by /systemd/pbp-integrity.service)
├── pbp-integrity.timer            ✗ DUPLICATE
├── pbp-watch.service              ✗ UNUSED (no references)
└── pbp-watch.timer                ✗ UNUSED
```

**Evidence:**
- `/systemd/pbp-integrity.service` is the active version
- `grep -r "pbp-watch" /home/dbcooper/parrot-booty-protection --exclude-dir=pbp-core` → 0 results

**Verdict:** DEAD CODE - DELETE 4 SYSTEMD UNITS

---

## SHADOW CODE ANALYSIS

### Competing Implementations

#### 1. DNS Monitoring
**THREE implementations exist:**

**A. dns-sovereignty-guard (ACTIVE)**
- Location: `/bin/dns-sovereignty-guard`
- Features: Continuous monitoring, alerting, baseline tracking
- Status: ✓ DEPLOYED via systemd

**B. Old DNS Scripts (DEAD)**
- Location: `/scripts/dns_monitor.sh`, `dns_alert.sh`, `dns_tls_monitor.sh`
- Features: Basic monitoring, manual execution
- Status: ✗ SUPERSEDED

**C. Hardening Framework DNS (DEAD)**
- Location: `/hardening-framework/modules/40_dns_monitoring.sh`
- Features: Whiptail TUI integration
- Status: ✗ ORPHANED

**Verdict:** Keep A, delete B and C

---

#### 2. Integrity Monitoring
**TWO implementations exist:**

**A. Core Integrity (ACTIVE)**
- Location: `/core/integrity.sh`
- Features: File hashing, alerting, policy-driven
- Status: ✓ DEPLOYED via systemd

**B. PBP-Core Integrity (DEAD)**
- Location: `/pbp-core/modules/pbp-integrity.sh`
- Features: Basic file monitoring
- Status: ✗ DUPLICATE

**Verdict:** Keep A, delete B

---

#### 3. Module System
**THREE implementations exist:**

**A. Core Modules (ACTIVE)**
- Location: `/modules/*`
- Architecture: manifest.json + 5 hooks per module
- Status: ✓ OPERATIONAL

**B. Hardening Framework Modules (DEAD)**
- Location: `/hardening-framework/modules/*`
- Architecture: Numbered modules, single script per module
- Status: ✗ ORPHANED

**C. PBP-Ops Modules (DEAD)**
- Location: `/pbp-ops/modules/*`
- Architecture: Shell wrappers for Python backend
- Status: ✗ PARTIAL

**Verdict:** Keep A, delete B and C

---

## EXECUTION SUMMARY

### ✓ ACTIVE EXECUTION PATHS (90 files)
- `/bin/pbp` → `/core/*` → `/modules/*`
- `/bin/pbp-report` → `/reporting/*`
- `/bin/dns-sovereignty-guard` (standalone)
- `/bin/pbp-control` → `/ui/index.html`
- `/bin/pbp-dashboard` → `/core/*`
- `/scripts/install*.sh` (4 installers)
- `/systemd/*.service` → various executables
- `/bughunt/bughunt.sh`

### ✗ DEAD CODE (180+ files)
- `/hardening-framework/*` (80+ files)
- `/pbp-ops/*` (40+ files)
- `/pbp-core/*` (40+ files)
- `/scripts/dns_*.sh` (8 files)
- `/scripts/ntp_harden.sh`, `port_harden.sh`, `service_harden.sh`, `docker_dns_fix.sh` (4 files)
- `/scripts/install_ops.sh`, `/install_pbp.sh` (2 files)

### ⚠ PARTIAL CODE (12 files)
- `/pbp-core/bin/pbp-sentinel.sh` (threat detection stub)
- `/pbp-core/bin/pbp-respond.sh` (incident response stub)
- `/pbp-core/bin/pbp-learn.sh` (ML baseline stub)
- `/pbp-core/modules/pbp-privesc.sh` (privesc detection stub)
- `/pbp-core/modules/pbp-persistence.sh` (persistence detection stub)
- `/pbp-core/modules/pbp-outbound.sh` (connection monitoring stub)
- `/pbp-ops/ui/app.py` (FastAPI web app incomplete)
- `/pbp-ops/lib/pbp_core.py` (Python library incomplete)
- `/scripts/install_dns_enhancements.sh` (partial implementation)

---

## NEXT STEPS

Proceed to **PHASE 3: DOCUMENT_STATUS.md** to audit documentation authority and identify conflicting/superseded docs.
