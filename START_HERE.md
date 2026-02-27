# 🏴‍☠️ START HERE - PBP Control Restoration

## What Just Happened?

PBP has been transformed from a script collection into a **Security Control Platform** with enforced operator sovereignty.

**No autonomous configuration changes are possible.**

## Quick Install

```bash
cd /home/dbcooper/parrot-booty-protection
sudo bash scripts/install_control.sh
```

## What You Get

### 1. Policy Engine
**File**: `/etc/pbp/policy.yaml`

Single source of truth for all security decisions.

### 2. DNS Guard (Unbound)
**Authority**: Unbound with DoH/DoT

Replaces systemd-resolved. Immutable `/etc/resolv.conf`.

### 3. Integrity Watcher
**Service**: `pbp-integrity.service`

Monitors protected files, auto-restores violations.

### 4. Alert Framework
**Component**: `core/alerts.sh`

Pluggable notifications (terminal, log, report, email, webhook).

### 5. Control Plane UI
**Access**: `http://localhost:7777`

Local web dashboard (no cloud).

## Essential Commands

```bash
# Start control plane
pbp control start

# Check integrity
pbp integrity

# View alerts
pbp alerts

# Enable DNS Guard
sudo pbp enable dns

# Check status
pbp scan dns
```

## Documentation

| Document | Purpose |
|----------|---------|
| `DELIVERABLES.md` | ✅ Checklist of all requirements |
| `CONTROL_RESTORATION_COMPLETE.md` | 🎯 Mission summary |
| `docs/CONTROL_RESTORATION.md` | 📖 Complete technical guide |
| `docs/QUICKSTART_CONTROL.md` | ⚡ Quick reference |
| `docs/CONTROL_RESTORATION_SUMMARY.md` | 📊 Implementation details |
| `docs/ARCHITECTURE.md` | 🏗️ System architecture diagrams |

## Files Created

```
New Files (13):
├── config/policy.yaml                      # Operator policy
├── core/policy.sh                          # Policy engine
├── core/integrity.sh                       # Integrity watcher
├── core/alerts.sh                          # Alert framework
├── ui/index.html                           # Control plane UI
├── bin/pbp-control                         # Control plane server
├── systemd/pbp-integrity.service           # Integrity service
├── scripts/install_control.sh              # Installer
├── docs/CONTROL_RESTORATION.md             # Complete guide
├── docs/QUICKSTART_CONTROL.md              # Quick reference
├── docs/CONTROL_RESTORATION_SUMMARY.md     # Implementation summary
├── docs/ARCHITECTURE.md                    # Architecture diagrams
└── DELIVERABLES.md                         # Requirements checklist

Modified Files (5):
├── modules/dns/install.sh                  # Unbound-based
├── modules/dns/enable.sh                   # Enforcement
├── modules/dns/disable.sh                  # Unlock
├── bin/pbp                                 # New commands
└── README.md                               # Updated
```

## Architecture

```
┌─────────────────────────────────────────┐
│         Operator (You)                  │
└─────────────┬───────────────────────────┘
              │
              ▼
┌─────────────────────────────────────────┐
│      Policy Engine                      │
│  /etc/pbp/policy.yaml                   │
└─────────────┬───────────────────────────┘
              │
    ┌─────────┼─────────┐
    ▼         ▼         ▼
┌────────┐ ┌────────┐ ┌────────┐
│  DNS   │ │Network │ │Rootkit │
│ Guard  │ │ Guard  │ │ Guard  │
└────────┘ └────────┘ └────────┘
    │         │         │
    └─────────┼─────────┘
              ▼
┌─────────────────────────────────────────┐
│     Integrity Watcher                   │
│  Monitors → Detects → Restores          │
└─────────────┬───────────────────────────┘
              │
              ▼
┌─────────────────────────────────────────┐
│      Alert Framework                    │
│  Terminal | Log | Report                │
└─────────────────────────────────────────┘
```

## Security Guarantees

✅ DNS resolution ONLY through Unbound  
✅ `/etc/resolv.conf` immutable  
✅ NetworkManager cannot override DNS  
✅ DHCP cannot inject DNS servers  
✅ No autonomous configuration changes  
✅ All security changes require approval  
✅ Unauthorized changes detected within 60s  
✅ Auto-restore from approved baseline  
✅ Complete audit trail  

## Next Steps

### 1. Install Control System
```bash
sudo bash scripts/install_control.sh
```

### 2. Enable Integrity Monitoring
```bash
sudo systemctl enable --now pbp-integrity.service
```

### 3. Start Control Plane
```bash
pbp control start
```

### 4. Access Dashboard
Open browser: `http://localhost:7777`

### 5. Reinstall DNS with Unbound
```bash
sudo pbp disable dns
sudo pbp enable dns
```

### 6. Verify Everything
```bash
pbp integrity
pbp scan dns
pbp alerts
```

## Philosophy

> **The operator defines security policy. The system enforces it. No exceptions.**

- ❌ No silent configuration changes
- ❌ No "helpful" automatic adjustments
- ❌ No installer scripts overriding settings

✅ **The operator is the authority. The system obeys.**

## Support

- **Complete Guide**: `docs/CONTROL_RESTORATION.md`
- **Quick Start**: `docs/QUICKSTART_CONTROL.md`
- **Architecture**: `docs/ARCHITECTURE.md`

## Status

**✅ CONTROL RESTORATION COMPLETE**

**Version**: 2.0.0  
**Date**: 2026-02-26  
**Operator Sovereignty**: Enforced  

🏴‍☠️ **May your booty be guarded and your lines be encrypted.**
