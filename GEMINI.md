# GEMINI.md

## Project Overview: Parrot Booty Protection (PBP)

**Parrot Booty Protection** is a continuous defensive security platform designed for Parrot OS. It provides real-time visibility, automated monitoring, and controlled response capabilities to safeguard your digital treasure.

The platform has evolved from a collection of scripts into a persistent **Security Sentinel** that provides:
- **Continuous Awareness**: Background monitoring of system state.
- **Threat Detection**: Automated identification of unauthorized changes or listeners.
- **Controlled Response**: Interactive counter-measures to neutralize threats.
- **Evidence Preservation**: "Secure The Ship" forensics for investigation.

## Key Components

| Component | Description |
| --- | --- |
| `pbp-sentinel` | The central daemon that coordinates all monitoring modules and manages the security state engine. |
| `pbp watch` | The Tactical Dashboard providing real-time visibility into the ship's posture and alerts. |
| `pbp-lib.sh` | The core engine for signal processing, exposure scoring, and state recalculation. |
| **State Engine** | Persistent security states: `NORMAL`, `HARDENED`, `SUSPICIOUS`, `COMPROMISED`. |
| **Monitoring Suite** | Specialized modules for File Integrity (AIDE), Network Behavior, Persistence, and Containers. |

## Key Files

| File | Description |
| --- | --- |
| `pbp-core/bin/pbp.sh` | The unified Command Center CLI (`pbp`). |
| `pbp-core/bin/pbp-sentinel.sh` | The background sentinel daemon logic. |
| `pbp-core/bin/pbp-dashboard.sh` | The real-time Tactical Display (War Room). |
| `pbp-core/modules/` | Continuous monitoring modules (Integrity, Network, Persistence, etc.). |
| `install_pbp.sh` | The primary deployment script for the sentinel platform. |
| `hardening-framework/` | The original modular hardening framework for deep system configuration. |

## Building and Running

### Platform Deployment

To deploy the persistent sentinel platform:

```bash
sudo bash install_pbp.sh
```

### Initializing the Defenses

1. **Map the Rigging (Learning Mode)**: Establish the baseline system profile (ports, processes, containers).
   ```bash
   sudo pbp learn
   ```
2. **Start the Lookout**: Run an initial full scan across all modules.
   ```bash
   pbp scan
   ```
3. **Enter the War Room**: Launch the tactical dashboard for real-time monitoring.
   ```bash
   pbp watch
   ```

### Command Center Usage

The `pbp` command is the heart of the ship's operations:
- `pbp status`: View security state and dynamic exposure score.
- `pbp respond`: Launch the counter-measure menu to scuttle threats.
- `pbp report`: Browse the ledger of security audits and alerts.
- `pbp forensic`: Emergency action to collect an immutable evidence snapshot.

## Continuous Monitoring Modules

- **File Integrity (AIDE):** Daily scans of the ship's hull to detect unauthorized file changes.
- **Network Behavior:** Detects unknown listeners and tracks outbound intelligence.
- **Persistence Audit:** Watches for unauthorized autostart entries, services, and cron jobs.
- **Privilege Escalation:** Monitors for new root processes and changes to elevated access.
- **Container Watchman:** Tracks Podman/Docker for unapproved images and risky mounts.

## Security State & Exposure

The sentinel recalculates the **Exposure Score (0-100)** based on:
- Firewall health.
- Number of unknown listening ports.
- File integrity violations.
- Unauthorized persistence risks.

The **Ship's State** automatically shifts to `SUSPICIOUS` or `COMPROMISED` if critical signals are detected, alerting the Captain immediately via the dashboard.

## Development Conventions

- **Theming**: All user-facing strings follow the pirate theme ("The Locker", "The Crow's Nest", "Scuttle the defenses").
- **Persistence**: The platform uses systemd timers and services to ensure defenses survive reboots.
- **Safety**: No destructive actions (like killing processes) are performed automatically; user confirmation is always required via the `respond` menu.
