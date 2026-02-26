# PBP Universal Reporting & Bug Hunt System

## Overview

The PBP reporting system provides standardized PDF and JSON report generation for all security scanners, plus a comprehensive bug hunt mode for system validation.

## Architecture

```
Scanner → Parser → Normalized JSON → HTML Template → PDF
```

All reports are stored in `/var/log/pbp/reports/<timestamp>/` with:
- Raw scanner output
- Normalized JSON
- HTML report
- PDF report
- SHA256 checksums

## Installation

### Install Dependencies

```bash
sudo bash scripts/install_reporting_deps.sh
```

This installs:
- pandoc
- wkhtmltopdf
- jq
- python3-jinja2

## Usage

### Generate Report from Scanner Output

```bash
# Run scanner and save output
rkhunter --check > /tmp/rkhunter.txt

# Generate report
sudo pbp-report rkhunter /tmp/rkhunter.txt

# Output: /var/log/pbp/reports/<timestamp>/
```

### Run Bug Hunt

```bash
# Comprehensive system validation
sudo pbp bughunt

# Generates:
# - master-report.json
# - master-report.html
# - master-report.pdf
```

## Supported Scanners

- **rkhunter** - Rootkit detection
- **chkrootkit** - Rootkit detection
- **lynis** - System auditing
- **nmap** - Port scanning
- **nftables** - Firewall audit
- **sysctl** - Kernel parameter audit
- **container** - Container security
- **aws** - External AWS scan results

## Bug Hunt Checks

The bug hunt performs:

1. **Configuration Validation** - Checks for missing configs
2. **Firewall Rules** - Detects duplicates, missing policies
3. **Service Health** - Identifies broken services
4. **NTS Time Sync** - Verifies encrypted time sources
5. **DNS Hardening** - Validates DoT and DNSSEC
6. **Container Privileges** - Inspects for privileged containers
7. **Open Ports** - Scans for exposed services
8. **File Permissions** - Checks for insecure permissions

## Report Format

### JSON Structure

```json
{
  "hostname": "server01",
  "timestamp": "2026-02-26T09:00:00Z",
  "scanner": "rkhunter",
  "risk_score": 15,
  "findings": [
    {
      "severity": "HIGH",
      "description": "Suspicious file detected",
      "remediation": "Review and remove if malicious"
    }
  ],
  "summary": {
    "warnings": 3,
    "infections": 0
  }
}
```

### Risk Scoring

- **CRITICAL**: 10 points per finding
- **HIGH**: 5 points per finding
- **MEDIUM**: 2 points per finding
- **LOW**: 1 point per finding

**Risk Bands**:
- 0-20: LOW
- 21-50: MEDIUM
- 51-100: HIGH
- 100+: CRITICAL

## Security Features

### Report Immutability

Reports are made immutable after generation:
```bash
chattr +i report.json report.pdf
```

### Integrity Verification

All reports include SHA256 checksums:
```bash
sha256sum -c report.json.sha256
```

### Access Control

- Reports stored with 600 permissions (root-only)
- Report directory has 700 permissions
- No world-readable data

### Input Sanitization

- All user input is validated
- HTML output is escaped
- JSON is validated before processing
- File paths are whitelisted

## Adding New Parsers

Create a parser in `reporting/parsers/<scanner>.sh`:

```bash
#!/bin/bash
set -euo pipefail

raw_file="${1:-}"

# Parse raw output
# Extract findings
# Calculate risk score

# Output normalized JSON
jq -n \
    --arg hostname "$(hostname)" \
    --arg timestamp "$(date -Iseconds)" \
    --arg scanner "myscan" \
    --arg risk "$risk_score" \
    --argjson findings "$findings" \
    '{
        hostname: $hostname,
        timestamp: $timestamp,
        scanner: $scanner,
        risk_score: ($risk | tonumber),
        findings: $findings
    }'
```

Make it executable:
```bash
chmod +x reporting/parsers/myscan.sh
```

## Integration with Modules

Update module scan hooks to use reporting engine:

```bash
# modules/rootkit/scan.sh
rkhunter --check > /tmp/rkhunter-$$.txt
pbp-report rkhunter /tmp/rkhunter-$$.txt
rm /tmp/rkhunter-$$.txt
```

## Troubleshooting

### PDF Generation Fails

Check wkhtmltopdf installation:
```bash
wkhtmltopdf --version
```

### Python Jinja2 Errors

Verify Jinja2 is installed:
```bash
python3 -c "import jinja2; print(jinja2.__version__)"
```

### Permission Denied

Ensure running as root:
```bash
sudo pbp bughunt
```

## Examples

### Generate rkhunter Report

```bash
sudo rkhunter --check --skip-keypress > /tmp/rkhunter.txt
sudo pbp-report rkhunter /tmp/rkhunter.txt
```

### Generate nmap Report

```bash
sudo nmap -sV localhost > /tmp/nmap.txt
sudo pbp-report nmap /tmp/nmap.txt
```

### Run Full Bug Hunt

```bash
sudo pbp bughunt
```

Output:
```
Bug Hunt Complete!
==================
Report Location: /var/log/pbp/reports/bughunt_20260226_090000
Risk Score: 25
Total Findings: 8

View reports:
  JSON: /var/log/pbp/reports/bughunt_20260226_090000/master-report.json
  HTML: /var/log/pbp/reports/bughunt_20260226_090000/master-report.html
  PDF:  /var/log/pbp/reports/bughunt_20260226_090000/master-report.pdf
```

## Future Enhancements

- Email report delivery
- Scheduled bug hunts via systemd timer
- Report comparison over time
- Trend analysis
- Integration with SIEM systems
- Custom report templates
- Multi-host aggregation
