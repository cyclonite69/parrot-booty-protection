# ACTIVE_SECURITY_STACK.md
## Running Security Protections
**Generated:** 2026-02-26  
**Purpose:** Document ONLY actively deployed security layers

---

## OPERATIONAL SECURITY LAYERS

### Layer 1: Time Synchronization
**Module:** `modules/time`  
**Status:** ✓ OPERATIONAL (when enabled)  
**Technology:** chrony + NTS  
**Protection:** Prevents time-based attacks, ensures certificate validity

**Active Components:**
- chrony daemon with NTS authentication
- NTP pool: time.cloudflare.com (NTS-enabled)
- Systemd service: chronyd.service

**Health Check:** `pbp health time` or `modules/time/health.sh`

**Scan:** `pbp scan time` or `modules/time/scan.sh`

---

### Layer 2: DNS Security
**Module:** `modules/dns`  
**Status:** ✓ OPERATIONAL (when enabled)  
**Technology:** Unbound + DoT (DNS-over-TLS)  
**Protection:** Blocks DNS hijacking, surveillance, cache poisoning

**Active Components:**
- Unbound recursive resolver (127.0.0.1:53)
- DoT upstream: 1.1.1.1@853 (Cloudflare)
- DNSSEC validation enabled
- /etc/resolv.conf → 127.0.0.1
- Immutable flag on /etc/resolv.conf
- NetworkManager DNS management disabled

**Health Check:** `pbp health dns` or `modules/dns/health.sh`

**Scan:** `pbp scan dns` or `modules/dns/scan.sh`

---

### Layer 3: DNS Sovereignty Monitoring
**Daemon:** `dns-sovereignty-guard`  
**Status:** ✓ DEPLOYED (systemd service)  
**Technology:** Bash monitoring daemon  
**Protection:** Continuous DNS configuration monitoring, alerting on violations

**Active Components:**
- Systemd service: dns-sovereignty-guard.service
- Monitoring interval: 30 seconds
- Baseline tracking: /var/lib/pbp/dns-guard/
- Alert log: /var/log/pbp/dns-alerts.log
- Event log: /var/lib/pbp/dns-guard/events.jsonl

**Checks Performed:**
- resolv.conf integrity (SHA256 hash)
- Immutable flag status
- DNS server configuration (127.0.0.1)
- Port 53 ownership (unbound)
- NetworkManager DNS bypass
- Unbound configuration integrity

**Alert Channels:**
- Terminal banner (if TTY)
- Log file (/var/log/pbp/dns-alerts.log)
- JSON events (/var/lib/pbp/dns-guard/events.jsonl)
- Email (if configured)

**Control:** `systemctl status dns-sovereignty-guard`

---

### Layer 4: Network Firewall
**Module:** `modules/network`  
**Status:** ✓ OPERATIONAL (when enabled)  
**Technology:** nftables  
**Protection:** Default-deny policy, connection tracking, egress filtering

**Active Components:**
- nftables ruleset
- Default policy: DROP
- Allowed: loopback, established connections, SSH (22)
- Stateful connection tracking
- Systemd service: nftables.service

**Health Check:** `pbp health network` or `modules/network/health.sh`

**Scan:** `pbp scan network` or `modules/network/scan.sh`

---

### Layer 5: Container Security
**Module:** `modules/container`  
**Status:** ✓ OPERATIONAL (when enabled)  
**Technology:** Podman (rootless)  
**Protection:** Prevents privilege escalation, container breakouts

**Active Components:**
- Podman rootless configuration
- User namespace isolation
- Seccomp profiles
- No privileged containers allowed
- cgroup v2 resource limits

**Health Check:** `pbp health container` or `modules/container/health.sh`

**Scan:** `pbp scan container` or `modules/container/scan.sh`

---

### Layer 6: System Auditing
**Module:** `modules/audit`  
**Status:** ✓ OPERATIONAL (when enabled)  
**Technology:** auditd  
**Protection:** Detects unauthorized changes, tracks privileged commands

**Active Components:**
- auditd daemon
- Audit rules: /etc/audit/rules.d/pbp.rules
- Log: /var/log/audit/audit.log
- Monitored: /etc, /usr/bin, /usr/sbin, privileged commands

**Health Check:** `pbp health audit` or `modules/audit/health.sh`

**Scan:** `pbp scan audit` or `modules/audit/scan.sh`

---

### Layer 7: Rootkit Detection
**Module:** `modules/rootkit`  
**Status:** ✓ OPERATIONAL (when enabled)  
**Technology:** rkhunter + chkrootkit  
**Protection:** Identifies rootkits, hidden processes, file tampering

**Active Components:**
- rkhunter scanner
- chkrootkit scanner
- Database: /var/lib/rkhunter/
- Scheduled scans: pbp-audit-weekly.timer

**Health Check:** `pbp health rootkit` or `modules/rootkit/health.sh`

**Scan:** `pbp scan rootkit` or `modules/rootkit/scan.sh`

---

### Layer 8: Network Reconnaissance
**Module:** `modules/recon`  
**Status:** ✓ OPERATIONAL (when enabled)  
**Technology:** nmap  
**Protection:** Maps attack surface, detects misconfigurations

**Active Components:**
- nmap scanner
- Scans: localhost, open ports, service versions
- Scheduled scans: pbp-scan-daily.timer

**Health Check:** `pbp health recon` or `modules/recon/health.sh`

**Scan:** `pbp scan recon` or `modules/recon/scan.sh`

---

### Layer 9: File Integrity Monitoring
**Service:** `pbp-integrity`  
**Status:** ✓ DEPLOYED (systemd service)  
**Technology:** SHA256 hashing  
**Protection:** Detects unauthorized file modifications

**Active Components:**
- Systemd service: pbp-integrity.service
- Monitoring: /etc, /opt/pbp, /usr/local/bin
- Baseline: /var/lib/pbp/integrity/
- Alert log: /var/log/pbp/integrity-alerts.log

**Control:** `systemctl status pbp-integrity`

**Manual Check:** `pbp integrity`

---

### Layer 10: Policy Enforcement
**Service:** `core/policy.sh`  
**Status:** ✓ OPERATIONAL  
**Technology:** YAML policy definitions  
**Protection:** Enforces operator sovereignty, prevents autonomous changes

**Active Components:**
- Policy file: /opt/pbp/config/policy.yaml
- Enforcement: All module operations require policy approval
- Protected files: /etc/resolv.conf, /etc/unbound/unbound.conf, /etc/nftables.conf

**Policy Rules:**
- require_approval: true (all operations)
- allow_rollback: true
- protected_files: [list of critical configs]

---

### Layer 11: Alert System
**Service:** `core/alerts.sh`  
**Status:** ✓ OPERATIONAL  
**Technology:** Log-based alerting  
**Protection:** Notifies operator of security violations

**Active Components:**
- Alert log: /var/log/pbp/integrity-alerts.log
- Alert viewer: `pbp alerts`
- Integration: integrity monitoring, DNS guard

**Alert Types:**
- File integrity violations
- DNS configuration changes
- Policy violations

---

## AUTOMATED MONITORING

### Systemd Timers

**1. Daily Security Scans**
- Timer: `pbp-scan-daily.timer`
- Service: `pbp-scan-daily.service`
- Schedule: Daily at 02:00
- Command: `pbp scan`
- Output: /var/log/pbp/reports/

**2. Weekly Deep Audits**
- Timer: `pbp-audit-weekly.timer`
- Service: `pbp-audit-weekly.service`
- Schedule: Weekly on Sunday at 03:00
- Command: `pbp scan audit`
- Output: /var/log/pbp/reports/

**3. Continuous Integrity Monitoring**
- Service: `pbp-integrity.service`
- Type: Simple (continuous)
- Command: `/opt/pbp/core/integrity.sh monitor`
- Output: /var/log/pbp/integrity-alerts.log

**4. Continuous DNS Monitoring**
- Service: `dns-sovereignty-guard.service`
- Type: Simple (continuous)
- Command: `/usr/local/bin/dns-sovereignty-guard monitor`
- Output: /var/log/pbp/dns-alerts.log

**Control:**
```bash
systemctl list-timers pbp-*
systemctl status pbp-integrity
systemctl status dns-sovereignty-guard
```

---

## CONTROL PLANE

### Web Dashboard
**Service:** `pbp-control`  
**Status:** ✓ AVAILABLE (manual start)  
**Technology:** Python HTTP server  
**Access:** http://localhost:7777

**Features:**
- Module status overview
- Health check results
- Security scan reports
- Quick actions

**Control:**
```bash
pbp control start
pbp control stop
pbp control status
```

---

### TUI Dashboard
**Command:** `pbp dashboard`  
**Status:** ✓ AVAILABLE  
**Technology:** Bash + ANSI escape codes

**Features:**
- Real-time module status
- Health monitoring
- Risk summary
- Quick actions (scan, reports, health)

**Control:**
```bash
pbp dashboard
```

---

## REPORTING SYSTEM

### Report Generation
**Engine:** `/reporting/engine.sh`  
**Status:** ✓ OPERATIONAL  
**Technology:** Bash + jq + Jinja2 + wkhtmltopdf

**Supported Scanners:**
- rkhunter
- nmap
- (extensible via parsers)

**Output Formats:**
- JSON (machine-readable)
- HTML (human-readable)
- PDF (professional reports)
- SHA256 checksums (integrity verification)

**Usage:**
```bash
pbp-report rkhunter /tmp/rkhunter.txt
pbp reports
pbp report <id>
pbp report <id> html
```

---

### Bug Hunt Validator
**Script:** `/bughunt/bughunt.sh`  
**Status:** ✓ OPERATIONAL  
**Technology:** Bash comprehensive validator

**Validates:**
- Configuration integrity
- Firewall rules (duplicates, policies)
- Service health
- NTS time synchronization
- DNS hardening (DoT, DNSSEC)
- Container privileges
- Open ports
- File permissions

**Output:**
- master-report.json
- master-report.html
- master-report.pdf

**Usage:**
```bash
sudo pbp bughunt
```

---

## SECURITY POSTURE SUMMARY

### Active Protections (When Enabled)
1. ✓ NTS-authenticated time synchronization
2. ✓ Encrypted DNS (DoT) with DNSSEC
3. ✓ Continuous DNS monitoring (dns-sovereignty-guard)
4. ✓ Stateful firewall (nftables, default-deny)
5. ✓ Rootless container security (Podman)
6. ✓ System activity auditing (auditd)
7. ✓ Rootkit detection (rkhunter + chkrootkit)
8. ✓ Network exposure validation (nmap)
9. ✓ File integrity monitoring (continuous)
10. ✓ Policy enforcement (operator sovereignty)
11. ✓ Alert system (log-based)

### Automated Monitoring
1. ✓ Daily security scans (02:00)
2. ✓ Weekly deep audits (Sunday 03:00)
3. ✓ Continuous integrity monitoring
4. ✓ Continuous DNS monitoring

### Operator Tools
1. ✓ CLI interface (`pbp`)
2. ✓ Web control plane (localhost:7777)
3. ✓ TUI dashboard
4. ✓ Report generation (JSON/HTML/PDF)
5. ✓ Bug hunt validator
6. ✓ Rollback system

---

## DEPLOYMENT STATUS

### Installed by Default
- Core engine (`/core/*`)
- All modules (`/modules/*`)
- CLI tools (`/bin/pbp`, `/bin/pbp-dashboard`, `/bin/pbp-report`)
- Reporting system (`/reporting/*`)
- Bug hunt validator (`/bughunt/*`)

### Requires Manual Installation
- Control plane: `scripts/install_control.sh`
- DNS guard: `scripts/install_dns_guard.sh`
- Reporting dependencies: `scripts/install_reporting_deps.sh`

### Requires Manual Enablement
- Security modules: `pbp enable <module>`
- Systemd timers: `systemctl enable --now pbp-scan-daily.timer`
- Systemd services: `systemctl enable --now pbp-integrity.service`

---

## VERIFICATION COMMANDS

```bash
# Check module status
pbp list
pbp status

# Check health
pbp health

# Check integrity
pbp integrity

# Check alerts
pbp alerts

# Check systemd services
systemctl status pbp-integrity
systemctl status dns-sovereignty-guard
systemctl list-timers pbp-*

# Run security scan
sudo pbp scan

# Run bug hunt
sudo pbp bughunt

# View reports
pbp reports
```

---

## NEXT STEPS

Proceed to **PHASE 7: DEPRECATION_PLAN.md** for exact cleanup commands.
