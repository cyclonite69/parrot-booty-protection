# OPERATOR CONTROL CONSOLE
## Post-Audit Phase: Unified Control Interface
**Date:** 2026-02-26  
**Phase:** Consolidation → Control  
**Status:** Design Specification

---

## DESIGN PHILOSOPHY

**Principle:** Enhance operator sovereignty, don't replace CLI.

**Goals:**
1. Single pane of glass for security posture
2. Real-time monitoring without polling
3. Approval workflow for all changes
4. Audit trail for all actions
5. Zero autonomous behavior

**Non-Goals:**
- ❌ Replace `pbp` CLI
- ❌ Auto-remediation
- ❌ Cloud dependencies
- ❌ Complex frameworks

---

## CURRENT STATE ANALYSIS

### Existing Control Interfaces

**1. CLI (`/bin/pbp`)**
- Status: ✓ OPERATIONAL
- Strengths: Complete, scriptable, operator-controlled
- Weaknesses: No real-time view, manual refresh

**2. TUI Dashboard (`/bin/pbp-dashboard`)**
- Status: ✓ OPERATIONAL
- Strengths: Real-time, interactive
- Weaknesses: Terminal-only, limited actions

**3. Web Control Plane (`/bin/pbp-control`)**
- Status: ✓ AVAILABLE (manual start)
- Strengths: Browser-based, visual
- Weaknesses: Static HTML, no backend, no real-time updates

**4. DNS Sovereignty Guard**
- Status: ✓ DEPLOYED
- Strengths: Continuous monitoring, alerting
- Weaknesses: DNS-only, no UI integration

---

## PROPOSED ARCHITECTURE

### Unified Control Console

```
┌─────────────────────────────────────────────────────────────┐
│                    OPERATOR CONTROL CONSOLE                 │
│                     (localhost:7777)                        │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐    │
│  │   Security   │  │   Alerts &   │  │   Approval   │    │
│  │   Posture    │  │   Events     │  │   Queue      │    │
│  │              │  │              │  │              │    │
│  │ • Modules    │  │ • Real-time  │  │ • Pending    │    │
│  │ • Health     │  │ • Severity   │  │ • History    │    │
│  │ • Risk Score │  │ • Timeline   │  │ • Audit Log  │    │
│  └──────────────┘  └──────────────┘  └──────────────┘    │
│                                                             │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐    │
│  │   System     │  │   Reports    │  │   Actions    │    │
│  │   Status     │  │              │  │              │    │
│  │              │  │ • Latest     │  │ • Scan       │    │
│  │ • Services   │  │ • History    │  │ • Enable     │    │
│  │ • Timers     │  │ • Compare    │  │ • Disable    │    │
│  │ • Processes  │  │ • Export     │  │ • Rollback   │    │
│  └──────────────┘  └──────────────┘  └──────────────┘    │
│                                                             │
└─────────────────────────────────────────────────────────────┘
         │                    │                    │
         ▼                    ▼                    ▼
    ┌─────────┐          ┌─────────┐         ┌─────────┐
    │  Core   │          │  Event  │         │  CLI    │
    │  Engine │◄────────►│  Stream │◄───────►│  Bridge │
    └─────────┘          └─────────┘         └─────────┘
         │                    │                    │
         ▼                    ▼                    ▼
    Modules/*           Logs/Events           pbp commands
```

---

## COMPONENT DESIGN

### 1. Event Stream (NEW)

**Purpose:** Real-time event distribution without polling

**Implementation:** Server-Sent Events (SSE)

**Location:** `/opt/pbp/control/event-stream.sh`

```bash
#!/bin/bash
# Event stream daemon - broadcasts system events via SSE

EVENT_FIFO="/var/run/pbp/events.fifo"
EVENT_LOG="/var/log/pbp/events.jsonl"

mkfifo "$EVENT_FIFO" 2>/dev/null

# Tail multiple sources into event stream
tail -f \
  /var/log/pbp/integrity-alerts.log \
  /var/log/pbp/dns-alerts.log \
  /var/log/pbp/actions.jsonl \
  2>/dev/null | while read -r line; do
    
    # Convert to JSON event
    timestamp=$(date -Iseconds)
    echo "{\"timestamp\":\"$timestamp\",\"data\":\"$line\"}" >> "$EVENT_LOG"
    echo "$line" > "$EVENT_FIFO"
done
```

**Systemd Unit:** `pbp-event-stream.service`

---

### 2. Control API (NEW)

**Purpose:** Backend for web console, wraps CLI commands

**Implementation:** Minimal bash CGI + socat

**Location:** `/opt/pbp/control/api.sh`

```bash
#!/bin/bash
# Control API - HTTP endpoints for web console

handle_request() {
    local method="$1"
    local path="$2"
    
    case "$path" in
        /api/status)
            pbp status --json
            ;;
        /api/modules)
            pbp list --json
            ;;
        /api/health)
            pbp health --json
            ;;
        /api/alerts)
            tail -50 /var/log/pbp/integrity-alerts.log | jq -Rs 'split("\n")'
            ;;
        /api/events)
            # SSE endpoint
            echo "Content-Type: text/event-stream"
            echo "Cache-Control: no-cache"
            echo ""
            tail -f /var/run/pbp/events.fifo
            ;;
        /api/approve/*)
            # Approval endpoint (requires authentication)
            action_id="${path##*/}"
            pbp approve "$action_id"
            ;;
        *)
            echo '{"error":"Not found"}'
            ;;
    esac
}

# Simple HTTP server
while true; do
    echo -e "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\n\r\n$(handle_request GET "$REQUEST_URI")" | nc -l -p 7778
done
```

---

### 3. Enhanced Web UI (UPGRADE)

**Purpose:** Interactive dashboard with real-time updates

**Location:** `/opt/pbp/ui/console.html`

**Key Features:**
- Real-time event stream (SSE)
- Module status cards
- Alert timeline
- Approval workflow
- Action buttons (scan, enable, disable)
- Report viewer

**Technology Stack:**
- HTML5 + CSS3 (no frameworks)
- Vanilla JavaScript (no dependencies)
- Server-Sent Events (SSE)
- Fetch API for actions

---

### 4. Approval Queue (NEW)

**Purpose:** Operator approval for all state changes

**Implementation:** JSON queue + CLI approval

**Location:** `/var/lib/pbp/approval-queue/`

**Workflow:**
```
1. Action requested (enable module, disable service)
2. Action added to approval queue
3. Operator notified (console + alert)
4. Operator reviews action
5. Operator approves/rejects
6. Action executed or cancelled
7. Audit log updated
```

**Queue Entry Format:**
```json
{
  "id": "req-20260226-230743",
  "timestamp": "2026-02-26T23:07:43-05:00",
  "action": "enable",
  "module": "dns",
  "requester": "operator",
  "status": "pending",
  "details": {
    "changes": ["Install unbound", "Configure DoT", "Update resolv.conf"],
    "risks": ["DNS service restart", "Brief connectivity loss"],
    "rollback": "available"
  }
}
```

---

### 5. CLI Bridge (ENHANCE)

**Purpose:** Make CLI commands output JSON for API consumption

**Implementation:** Add `--json` flag to all `pbp` commands

**Example:**
```bash
# Current
pbp status
# Output: Human-readable text

# Enhanced
pbp status --json
# Output: {"modules":[{"name":"dns","status":"enabled","health":"ok"}]}
```

**Changes Required:**
- Modify `/bin/pbp` to support `--json` flag
- Update core functions to output JSON when flag present
- Maintain backward compatibility (default: human-readable)

---

## IMPLEMENTATION PLAN

### Phase 1: Event Stream (Week 1)

**Tasks:**
1. Create event stream daemon (`control/event-stream.sh`)
2. Create systemd unit (`pbp-event-stream.service`)
3. Integrate with existing logs
4. Test SSE delivery

**Deliverables:**
- Real-time event broadcasting
- No polling required

---

### Phase 2: JSON Output (Week 1)

**Tasks:**
1. Add `--json` flag to `/bin/pbp`
2. Update `cmd_status()`, `cmd_list()`, `cmd_health()` to output JSON
3. Test JSON parsing in web UI

**Deliverables:**
- CLI commands output JSON
- API can consume CLI output

---

### Phase 3: Control API (Week 2)

**Tasks:**
1. Create API handler (`control/api.sh`)
2. Implement endpoints (status, modules, health, alerts, events)
3. Add authentication (token-based)
4. Test API responses

**Deliverables:**
- HTTP API for web console
- Authenticated endpoints

---

### Phase 4: Enhanced Web UI (Week 2)

**Tasks:**
1. Create new console UI (`ui/console.html`)
2. Implement SSE client
3. Add module status cards
4. Add alert timeline
5. Add action buttons
6. Test real-time updates

**Deliverables:**
- Interactive web console
- Real-time monitoring

---

### Phase 5: Approval Queue (Week 3)

**Tasks:**
1. Create approval queue system (`control/approval-queue.sh`)
2. Integrate with core engine
3. Add approval CLI commands (`pbp approve`, `pbp reject`)
4. Add approval UI in web console
5. Test approval workflow

**Deliverables:**
- Operator approval for all changes
- Audit trail for approvals

---

### Phase 6: Integration & Testing (Week 3)

**Tasks:**
1. Integrate all components
2. End-to-end testing
3. Documentation updates
4. Security audit

**Deliverables:**
- Unified control console
- Complete documentation

---

## FILE STRUCTURE

```
/opt/pbp/
├── control/                      [NEW]
│   ├── event-stream.sh           [NEW] Event broadcasting
│   ├── api.sh                    [NEW] HTTP API handler
│   ├── approval-queue.sh         [NEW] Approval workflow
│   └── auth.sh                   [NEW] Authentication
│
├── ui/
│   ├── index.html                [EXISTING] Static dashboard
│   └── console.html              [NEW] Interactive console
│
├── bin/
│   ├── pbp                       [ENHANCE] Add --json flag
│   ├── pbp-control               [ENHANCE] Start API + event stream
│   └── pbp-approve               [NEW] Approval CLI
│
└── systemd/
    ├── pbp-event-stream.service  [NEW]
    └── pbp-control-api.service   [NEW]
```

---

## SECURITY CONSIDERATIONS

### Authentication

**Method:** Token-based (no passwords)

**Implementation:**
```bash
# Generate token on first start
TOKEN=$(openssl rand -hex 32)
echo "$TOKEN" > /var/lib/pbp/control-token
chmod 600 /var/lib/pbp/control-token

# Require token for API access
if [[ "$HTTP_AUTHORIZATION" != "Bearer $TOKEN" ]]; then
    echo '{"error":"Unauthorized"}'
    exit 1
fi
```

**Access:**
- Token displayed on console start
- Token required for all API calls
- Token rotates on restart

---

### Network Binding

**Bind to localhost only:**
```bash
# Only accessible from local machine
socat TCP-LISTEN:7778,bind=127.0.0.1,fork EXEC:./api.sh
```

**No remote access** (operator must be on the machine)

---

### Approval Workflow

**All state changes require approval:**
- Enable module → approval required
- Disable module → approval required
- Modify configuration → approval required
- Rollback → approval required

**Exceptions (no approval):**
- Read-only operations (status, list, health)
- Scans (read-only)
- Report viewing (read-only)

---

## OPERATOR SOVEREIGNTY PRESERVATION

### CLI Remains Primary

**Console is a view, not a replacement:**
- All console actions call `pbp` CLI
- CLI can be used independently
- Console cannot bypass CLI
- No hidden automation

### Approval Required

**No autonomous actions:**
- Operator must approve all changes
- Approval queue visible in console
- Approval history audited
- Rejected actions logged

### Rollback Always Available

**Every change is reversible:**
- Backup created before change
- Rollback command available
- Rollback requires approval
- Rollback history tracked

---

## MINIMAL IMPLEMENTATION

**Start with essentials:**

1. **Event Stream** (50 lines)
   - Tail logs → SSE

2. **JSON Output** (100 lines)
   - Add `--json` flag to `pbp`

3. **Simple API** (150 lines)
   - Wrap CLI commands
   - Serve SSE

4. **Enhanced UI** (300 lines)
   - SSE client
   - Module cards
   - Alert timeline

**Total:** ~600 lines of code

**No frameworks, no dependencies, no complexity**

---

## SUCCESS CRITERIA

Console is successful if:

1. ✓ Operator sees real-time security posture
2. ✓ Operator approves all changes
3. ✓ CLI remains fully functional
4. ✓ No autonomous behavior
5. ✓ Audit trail complete
6. ✓ Rollback always available
7. ✓ Zero external dependencies
8. ✓ Localhost-only access
9. ✓ Token authentication
10. ✓ Minimal code footprint

---

## NEXT STEPS

**After audit cleanup:**

1. Execute DEPRECATION_PLAN.md (remove dead code)
2. Implement event stream (Phase 1)
3. Add JSON output to CLI (Phase 2)
4. Build control API (Phase 3)
5. Create enhanced UI (Phase 4)
6. Add approval queue (Phase 5)
7. Integration testing (Phase 6)

**Estimated Timeline:** 3 weeks  
**Risk:** LOW (additive, no rewrites)  
**Benefit:** HIGH (unified control interface)

---

## ALTERNATIVE: MINIMAL CONSOLE (1 Week)

**If 3 weeks is too long, start with minimal version:**

**Week 1 Deliverable:**
- Event stream (SSE)
- JSON output (`pbp --json`)
- Simple API (status, modules, health, events)
- Basic UI (real-time updates only)

**Defer to later:**
- Approval queue
- Action buttons
- Report viewer
- Advanced features

**This gives you real-time monitoring immediately, approval workflow later.**

---

**Ready to implement?** Choose:
1. Full console (3 weeks)
2. Minimal console (1 week)
3. Execute cleanup first, then console
