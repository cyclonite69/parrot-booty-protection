# CRUFT_REPORT.md
## Code Duplication & Cruft Detection
**Generated:** 2026-02-26  
**Purpose:** Identify duplicate implementations, partial code, and consolidation targets

---

## DUPLICATE IMPLEMENTATIONS

### 1. DNS Monitoring (3 implementations)

**ACTIVE:** `/bin/dns-sovereignty-guard`
- Features: Continuous monitoring, baseline tracking, alerting, email notifications
- Lines: 142
- Status: ✓ DEPLOYED

**DUPLICATE:** `/scripts/dns_monitor.sh`
- Features: Basic monitoring, manual execution
- Lines: 35
- Status: ✗ SUPERSEDED
- **Action: DELETE**

**DUPLICATE:** `/scripts/dns_tls_monitor.sh`
- Features: TLS-specific monitoring
- Lines: 48
- Status: ✗ SUPERSEDED
- **Action: DELETE**

**DUPLICATE:** `/hardening-framework/modules/40_dns_monitoring.sh`
- Features: Whiptail TUI integration
- Lines: 98
- Status: ✗ ORPHANED
- **Action: DELETE** (with hardening-framework/)

**Consolidation:** Keep dns-sovereignty-guard, delete 3 duplicates

---

### 2. DNS Hardening (3 implementations)

**ACTIVE:** `/modules/dns/enable.sh`
- Features: Unbound installation, DoT configuration, systemd integration
- Lines: 42
- Status: ✓ OPERATIONAL

**DUPLICATE:** `/scripts/dns_harden.sh`
- Features: Unbound setup, basic hardening
- Lines: 168
- Status: ✗ SUPERSEDED
- **Action: DELETE**

**DUPLICATE:** `/hardening-framework/modules/05_dns_harden.sh`
- Features: Unbound + DoH/DoT setup
- Lines: 215
- Status: ✗ ORPHANED
- **Action: DELETE** (with hardening-framework/)

**Consolidation:** Keep modules/dns/enable.sh, delete 2 duplicates

---

### 3. Time Synchronization (2 implementations)

**ACTIVE:** `/modules/time/enable.sh`
- Features: chrony + NTS configuration
- Lines: 28
- Status: ✓ OPERATIONAL

**DUPLICATE:** `/scripts/ntp_harden.sh`
- Features: chrony setup, basic NTS
- Lines: 142
- Status: ✗ SUPERSEDED
- **Action: DELETE**

**DUPLICATE:** `/hardening-framework/modules/04_ntp_harden.sh`
- Features: chrony + NTS setup
- Lines: 72
- Status: ✗ ORPHANED
- **Action: DELETE** (with hardening-framework/)

**Consolidation:** Keep modules/time/enable.sh, delete 2 duplicates

---

### 4. Firewall Management (2 implementations)

**ACTIVE:** `/modules/network/enable.sh`
- Features: nftables configuration, default-deny policy
- Lines: 38
- Status: ✓ OPERATIONAL

**DUPLICATE:** `/scripts/port_harden.sh`
- Features: nftables setup, port management
- Lines: 198
- Status: ✗ SUPERSEDED
- **Action: DELETE**

**DUPLICATE:** `/hardening-framework/modules/06_firewall_harden.sh`
- Features: nftables + iptables setup
- Lines: 108
- Status: ✗ ORPHANED
- **Action: DELETE** (with hardening-framework/)

**Consolidation:** Keep modules/network/enable.sh, delete 2 duplicates

---

### 5. Container Security (2 implementations)

**ACTIVE:** `/modules/container/enable.sh`
- Features: Podman rootless configuration, seccomp profiles
- Lines: 31
- Status: ✓ OPERATIONAL

**DUPLICATE:** `/hardening-framework/modules/20_container_stabilization.sh`
- Features: Docker + Podman hardening
- Lines: 74
- Status: ✗ ORPHANED
- **Action: DELETE** (with hardening-framework/)

**Consolidation:** Keep modules/container/enable.sh, delete 1 duplicate

---

### 6. Audit Monitoring (2 implementations)

**ACTIVE:** `/modules/audit/enable.sh`
- Features: auditd configuration, rule installation
- Lines: 24
- Status: ✓ OPERATIONAL

**DUPLICATE:** `/scripts/service_harden.sh`
- Features: Service auditing, auditd setup
- Lines: 165
- Status: ✗ SUPERSEDED
- **Action: DELETE**

**DUPLICATE:** `/hardening-framework/modules/60_auditd.sh`
- Features: auditd + custom rules
- Lines: 98
- Status: ✗ ORPHANED
- **Action: DELETE** (with hardening-framework/)

**Consolidation:** Keep modules/audit/enable.sh, delete 2 duplicates

---

### 7. Rootkit Detection (2 implementations)

**ACTIVE:** `/modules/rootkit/enable.sh`
- Features: rkhunter + chkrootkit installation
- Lines: 8
- Status: ✓ OPERATIONAL

**DUPLICATE:** `/hardening-framework/modules/10_malware_detect.sh`
- Features: rkhunter + chkrootkit + ClamAV
- Lines: 152
- Status: ✗ ORPHANED
- **Action: DELETE** (with hardening-framework/)

**Consolidation:** Keep modules/rootkit/enable.sh, delete 1 duplicate

---

### 8. Integrity Monitoring (2 implementations)

**ACTIVE:** `/core/integrity.sh`
- Features: File hashing, alerting, policy-driven monitoring
- Lines: 98
- Status: ✓ DEPLOYED

**DUPLICATE:** `/pbp-core/modules/pbp-integrity.sh`
- Features: Basic file monitoring
- Lines: 42
- Status: ✗ SUPERSEDED
- **Action: DELETE** (with pbp-core/)

**Consolidation:** Keep core/integrity.sh, delete 1 duplicate

---

### 9. CLI Interface (2 implementations)

**ACTIVE:** `/bin/pbp`
- Features: Complete CLI with 13 commands, module orchestration
- Lines: 248
- Status: ✓ OPERATIONAL

**DUPLICATE:** `/pbp-core/bin/pbp.sh`
- Features: Basic CLI with 8 commands
- Lines: 118
- Status: ✗ SUPERSEDED
- **Action: DELETE** (with pbp-core/)

**DUPLICATE:** `/hardening-framework/hardenctl`
- Features: Whiptail TUI with module management
- Lines: 298
- Status: ✗ ORPHANED
- **Action: DELETE** (with hardening-framework/)

**Consolidation:** Keep /bin/pbp, delete 2 duplicates

---

### 10. Dashboard (2 implementations)

**ACTIVE:** `/bin/pbp-dashboard`
- Features: TUI dashboard with module status, health checks, risk summary
- Lines: 208
- Status: ✓ OPERATIONAL

**DUPLICATE:** `/pbp-core/bin/pbp-dashboard.sh`
- Features: Basic TUI dashboard
- Lines: 72
- Status: ✗ SUPERSEDED
- **Action: DELETE** (with pbp-core/)

**Consolidation:** Keep /bin/pbp-dashboard, delete 1 duplicate

---

## PARTIAL IMPLEMENTATIONS

### 1. Threat Detection System (STUB)

**Location:** `/pbp-core/bin/pbp-sentinel.sh`
- Purpose: Real-time threat detection
- Status: ⚠ PARTIAL (38 lines, mostly comments)
- Features Implemented:
  - Basic structure
  - Placeholder functions
- Features Missing:
  - Actual threat detection logic
  - Integration with modules
  - Alert system
- **Action: EXTRACT to docs/FUTURE_FEATURES.md or DELETE**

---

### 2. Incident Response System (STUB)

**Location:** `/pbp-core/bin/pbp-respond.sh`
- Purpose: Automated incident response
- Status: ⚠ PARTIAL (82 lines, mostly comments)
- Features Implemented:
  - Response framework
  - Placeholder actions
- Features Missing:
  - Actual response logic
  - Integration with alerts
  - Rollback automation
- **Action: EXTRACT to docs/FUTURE_FEATURES.md or DELETE**

---

### 3. ML Baseline Learning (STUB)

**Location:** `/pbp-core/bin/pbp-learn.sh`
- Purpose: Machine learning baseline establishment
- Status: ⚠ PARTIAL (38 lines, mostly comments)
- Features Implemented:
  - Basic structure
- Features Missing:
  - ML algorithms
  - Baseline storage
  - Anomaly detection
- **Action: EXTRACT to docs/FUTURE_FEATURES.md or DELETE**

---

### 4. Privilege Escalation Detection (STUB)

**Location:** `/pbp-core/modules/pbp-privesc.sh`
- Purpose: Detect privilege escalation attempts
- Status: ⚠ PARTIAL (36 lines, mostly comments)
- Features Implemented:
  - SUID/SGID file monitoring
- Features Missing:
  - Capability monitoring
  - Sudo abuse detection
  - Alert integration
- **Action: EXTRACT to docs/FUTURE_FEATURES.md or DELETE**

---

### 5. Persistence Detection (STUB)

**Location:** `/pbp-core/modules/pbp-persistence.sh`
- Purpose: Detect persistence mechanisms
- Status: ⚠ PARTIAL (28 lines, mostly comments)
- Features Implemented:
  - Cron job monitoring
- Features Missing:
  - Systemd unit monitoring
  - Startup script detection
  - User account monitoring
- **Action: EXTRACT to docs/FUTURE_FEATURES.md or DELETE**

---

### 6. Outbound Connection Monitoring (STUB)

**Location:** `/pbp-core/modules/pbp-outbound.sh`
- Purpose: Monitor outbound network connections
- Status: ⚠ PARTIAL (24 lines, mostly comments)
- Features Implemented:
  - Basic netstat wrapper
- Features Missing:
  - Connection baselining
  - Anomaly detection
  - Alert integration
- **Action: EXTRACT to docs/FUTURE_FEATURES.md or DELETE**

---

### 7. Python Web App (INCOMPLETE)

**Location:** `/pbp-ops/ui/app.py`
- Purpose: FastAPI web dashboard
- Status: ⚠ PARTIAL (248 lines, incomplete)
- Features Implemented:
  - FastAPI structure
  - Basic routes
  - Module status endpoint
- Features Missing:
  - Frontend integration
  - Authentication
  - WebSocket support
  - Deployment configuration
- **Action: DELETE** (superseded by /ui/index.html + pbp-control)

---

### 8. Python Core Library (INCOMPLETE)

**Location:** `/pbp-ops/lib/pbp_core.py`
- Purpose: Python library for PBP operations
- Status: ⚠ PARTIAL (102 lines, incomplete)
- Features Implemented:
  - Module registry
  - Basic state management
- Features Missing:
  - Module execution
  - Error handling
  - Integration with shell scripts
- **Action: DELETE** (not used by any code)

---

### 9. DNS Enhancements Installer (INCOMPLETE)

**Location:** `/scripts/install_dns_enhancements.sh`
- Purpose: Install DNS enhancements
- Status: ⚠ PARTIAL (282 lines, incomplete)
- Features Implemented:
  - Unbound installation
  - DoT configuration
- Features Missing:
  - Integration with modules/dns
  - Rollback support
  - Health checks
- **Action: DELETE** (superseded by modules/dns + install_dns_guard.sh)

---

## OVERLAPPING FUNCTIONALITY

### 1. DNS Alert Systems

**THREE alert mechanisms exist:**

**A. dns-sovereignty-guard** (ACTIVE)
- Alerts: Terminal banner, log file, JSON events, email
- Location: `/bin/dns-sovereignty-guard`
- Status: ✓ DEPLOYED

**B. dns_alert.sh** (DUPLICATE)
- Alerts: Log file only
- Location: `/scripts/dns_alert.sh`
- Status: ✗ SUPERSEDED
- **Action: DELETE**

**C. core/alerts.sh** (ACTIVE)
- Alerts: Generic alert system for all modules
- Location: `/core/alerts.sh`
- Status: ✓ OPERATIONAL
- **Action: KEEP** (different purpose)

**Consolidation:** Keep A and C, delete B

---

### 2. State Management

**THREE state systems exist:**

**A. core/state.sh** (ACTIVE)
- State: Module status, JSON-based, /var/lib/pbp/state/
- Location: `/core/state.sh`
- Status: ✓ OPERATIONAL

**B. hardening-framework/core/state_manager.sh** (DUPLICATE)
- State: Module status, JSON-based, hardening-framework/state/
- Location: `/hardening-framework/core/state_manager.sh`
- Status: ✗ ORPHANED
- **Action: DELETE** (with hardening-framework/)

**C. pbp-ops/state/registry.json** (EMPTY)
- State: Empty JSON file
- Location: `/pbp-ops/state/registry.json`
- Status: ✗ UNUSED
- **Action: DELETE** (with pbp-ops/)

**Consolidation:** Keep A, delete B and C

---

### 3. Logging Systems

**THREE logging systems exist:**

**A. core/lib/logging.sh** (ACTIVE)
- Logging: Structured logging, log levels, /var/log/pbp/
- Location: `/core/lib/logging.sh`
- Status: ✓ OPERATIONAL

**B. hardening-framework/core/logger.sh** (DUPLICATE)
- Logging: Basic logging, hardening-framework/logs/
- Location: `/hardening-framework/core/logger.sh`
- Status: ✗ ORPHANED
- **Action: DELETE** (with hardening-framework/)

**C. pbp-core/lib/pbp-lib.sh** (DUPLICATE)
- Logging: Basic logging functions
- Location: `/pbp-core/lib/pbp-lib.sh`
- Status: ✗ SUPERSEDED
- **Action: DELETE** (with pbp-core/)

**Consolidation:** Keep A, delete B and C

---

## RECYCLED CODE ANALYSIS

### Code Reuse Patterns

**Pattern 1: DNS Scripts → dns-sovereignty-guard**
- `dns_monitor.sh` logic → `check_resolv_conf()`, `check_dns_server()`
- `dns_alert.sh` logic → `alert()` function
- `dns_tls_monitor.sh` logic → `check_upstream()` function
- **Verdict:** Code successfully consolidated

**Pattern 2: Hardening Modules → Core Modules**
- `hardening-framework/modules/05_dns_harden.sh` → `modules/dns/enable.sh`
- `hardening-framework/modules/04_ntp_harden.sh` → `modules/time/enable.sh`
- `hardening-framework/modules/06_firewall_harden.sh` → `modules/network/enable.sh`
- **Verdict:** Code successfully refactored and simplified

**Pattern 3: pbp-core → core**
- `pbp-core/modules/pbp-integrity.sh` → `core/integrity.sh`
- `pbp-core/bin/pbp.sh` → `/bin/pbp`
- `pbp-core/bin/pbp-dashboard.sh` → `/bin/pbp-dashboard`
- **Verdict:** Code successfully migrated

---

## CONSOLIDATION TARGETS

### High Priority (Delete Immediately)

1. **hardening-framework/** (80+ files)
   - Reason: Entire directory is orphaned, no references
   - Impact: None (dead code)
   - Risk: None

2. **pbp-ops/** (40+ files)
   - Reason: Partial implementation, never deployed
   - Impact: None (dead code)
   - Risk: None

3. **pbp-core/** (40+ files)
   - Reason: Superseded by /core and /bin
   - Impact: None (dead code)
   - Risk: None

4. **Old DNS Scripts** (8 files in /scripts)
   - Reason: Superseded by modules/dns + dns-sovereignty-guard
   - Impact: None (dead code)
   - Risk: None

5. **Old Hardening Scripts** (4 files in /scripts)
   - Reason: Superseded by modules/*
   - Impact: None (dead code)
   - Risk: None

6. **Orphaned Installers** (2 files)
   - Reason: Install dead code
   - Impact: None (dead code)
   - Risk: None

**Total Files to Delete:** 180+ files

---

### Medium Priority (Extract or Delete)

1. **Partial Implementations in pbp-core** (6 files)
   - Options:
     - Extract to docs/FUTURE_FEATURES.md
     - Delete entirely
   - Recommendation: Extract useful concepts, delete stubs

2. **Historical Documentation** (21 files)
   - Options:
     - Archive to docs/archive/
     - Delete entirely
   - Recommendation: Archive for reference

---

### Low Priority (Keep for Now)

1. **Empty Directories**
   - pbp-ops/reports/* (8 subdirectories)
   - pbp-ops/logs, scripts, configs, scheduler
   - hardening-framework/profiles, logs
   - Recommendation: Delete with parent directories

---

## DUPLICATION SUMMARY

### Total Duplicate Code
- **DNS:** 3 implementations → 1 active (delete 2)
- **Time:** 2 implementations → 1 active (delete 1)
- **Firewall:** 2 implementations → 1 active (delete 1)
- **Container:** 2 implementations → 1 active (delete 1)
- **Audit:** 2 implementations → 1 active (delete 1)
- **Rootkit:** 2 implementations → 1 active (delete 1)
- **Integrity:** 2 implementations → 1 active (delete 1)
- **CLI:** 3 implementations → 1 active (delete 2)
- **Dashboard:** 2 implementations → 1 active (delete 1)
- **State:** 3 implementations → 1 active (delete 2)
- **Logging:** 3 implementations → 1 active (delete 2)

**Total Duplicate Implementations:** 27  
**Total Duplicate Files:** ~150

### Total Partial Code
- **Threat Detection:** 1 stub
- **Incident Response:** 1 stub
- **ML Baseline:** 1 stub
- **Privesc Detection:** 1 stub
- **Persistence Detection:** 1 stub
- **Outbound Monitoring:** 1 stub
- **Python Web App:** 1 incomplete
- **Python Library:** 1 incomplete
- **DNS Enhancements:** 1 incomplete

**Total Partial Implementations:** 9  
**Total Partial Files:** ~12

---

## NEXT STEPS

Proceed to **PHASE 5: PROMPT_COMPLETION_STATUS.md** to verify which AI prompts completed successfully and which left partial implementations.
