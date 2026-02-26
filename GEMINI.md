# GEMINI.md

## Project Overview: Parrot Booty Protection (PBP)

**Parrot Booty Protection** is a full-scale Security Operations Platform designed for Parrot OS. It provides real-time visibility, automated auditing, and a centralized Command Center to safeguard your digital treasure.

The platform has evolved into an **Integrated Defense Console** providing:
- **Modular Control**: Selectable modules for DNS, Time, Firewall, and more.
- **Web Command Center**: High-contrast, real-time dashboard for ops.
- **Continuous Awareness**: Background sentinel and scheduled scans.
- **The Captain's Ledger**: Integrated report viewer for evidence and auditing.

## Key Components

| Component | Description |
| --- | --- |
| **Ops Console** | FastAPI-powered web dashboard at `http://localhost:8080`. |
| `pbp-sentinel` | Background daemon coordinating continuous monitoring. |
| **Module Engine** | Standardized `install`, `run`, and `status` scripts for each defense. |
| **State & Signal** | Real-time security posture and exposure scoring. |

## Key Files

| File | Description |
| --- | --- |
| `pbp-ops/ui/app.py` | The Command Center Web Dashboard (High-Contrast Theme). |
| `pbp-ops/lib/pbp_core.py` | The orchestration engine for running modules and logs. |
| `scripts/install_ops.sh` | The primary platform deployment script. |
| `pbp-ops/modules/` | Selectable defense modules (Rootkit, Network, etc.). |
| `pbp-core/` | The background sentinel and CLI components. |

## Building and Running

### Platform Deployment

To deploy the full Ops Console and Sentinel:

```bash
sudo bash scripts/install_ops.sh
```

### Accessing the Quarterdeck

Once deployed, the Command Center is available at:
**`http://localhost:8080`**

From the UI, you can:
1. **Install Rigging**: Set up dependencies for individual modules.
2. **Batten Down**: Execute a security scan or hardening task.
3. **Inspect**: Verify the real-time status of a module.
4. **Open Ledger**: View the timestamped report for any operation.

## Integrated Modules

- **Rootkit Sentry:** Scans for deep system infections (rkhunter/chkrootkit).
- **Network Exposure:** Proactive port scanning and service fingerprinting (Nmap).
- **DNS Hardening:** DoT/DNSSEC configuration and leak protection.
- **Encrypted Time:** NTS-authenticated time synchronization (Chrony).
- **Firewall Base:** Strict nftables ruleset with default-deny inbound.
- **System Hardening:** Kernel sysctl, service scuttling, and SSH security.
- **Container Audit:** Security review of rootless Podman/Docker.
- **IPv6 Policy:** Granular control and disablement of IPv6 signals.

## Development Conventions

- **Theming**: "Midnight Quarterdeck" high-contrast theme (Black/White/Gold).
- **Non-Destructive**: All modules must include backups and support rollback.
- **Professional Pirate Tone**: Maintain the Parrot Booty Protection character in all reports and UI strings.
