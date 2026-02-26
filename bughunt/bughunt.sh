#!/bin/bash
# PBP Bug Hunt - Comprehensive System Validation
set -euo pipefail

PBP_ROOT="${PBP_ROOT:-/opt/pbp}"
source "${PBP_ROOT}/core/lib/logging.sh"

REPORT_ID="bughunt_$(date +%Y%m%d_%H%M%S)"
REPORT_DIR="/var/log/pbp/reports/${REPORT_ID}"

# Initialize report directory
mkdir -p "${REPORT_DIR}"/{raw,json,findings}
chmod 700 "${REPORT_DIR}"

# Aggregate findings
ALL_FINDINGS='[]'
TOTAL_RISK=0

# Add finding to aggregate
add_finding() {
    local category="$1"
    local severity="$2"
    local description="$3"
    local remediation="$4"
    
    ALL_FINDINGS=$(echo "$ALL_FINDINGS" | jq --arg cat "$category" --arg sev "$severity" --arg desc "$description" --arg rem "$remediation" '. += [{
        category: $cat,
        severity: $sev,
        description: $desc,
        remediation: $rem
    }]')
    
    # Update risk score
    case "$severity" in
        CRITICAL) TOTAL_RISK=$((TOTAL_RISK + 10)) ;;
        HIGH) TOTAL_RISK=$((TOTAL_RISK + 5)) ;;
        MEDIUM) TOTAL_RISK=$((TOTAL_RISK + 2)) ;;
        LOW) TOTAL_RISK=$((TOTAL_RISK + 1)) ;;
    esac
}

# 1. Validate Configurations
validate_configs() {
    log_info "Validating configurations..."
    
    # Check if critical configs exist
    local configs=(
        "/etc/chrony/chrony.conf"
        "/etc/systemd/resolved.conf"
        "/etc/nftables.conf"
    )
    
    for config in "${configs[@]}"; do
        if [[ ! -f "$config" ]]; then
            add_finding "config" "HIGH" "Missing configuration: $config" "Run pbp enable for relevant module"
        fi
    done
}

# 2. Check Duplicate Firewall Rules
check_firewall_rules() {
    log_info "Checking firewall rules..."
    
    if ! command -v nft &>/dev/null; then
        add_finding "firewall" "MEDIUM" "nftables not installed" "Install nftables"
        return
    fi
    
    # Check for duplicate rules
    local rules=$(nft list ruleset 2>/dev/null || echo "")
    
    if [[ -z "$rules" ]]; then
        add_finding "firewall" "CRITICAL" "No firewall rules loaded" "Run: sudo pbp enable network"
        return
    fi
    
    # Check for default drop policy
    if ! echo "$rules" | grep -q "policy drop"; then
        add_finding "firewall" "HIGH" "No default drop policy found" "Configure default drop on input chain"
    fi
    
    # Check output chain policy
    if echo "$rules" | grep "chain output" -A5 | grep -q "policy accept"; then
        add_finding "firewall" "HIGH" "Output chain allows all traffic" "Implement egress filtering"
    fi
}

# 3. Detect Broken Services
check_services() {
    log_info "Checking services..."
    
    local services=("chronyd" "systemd-resolved" "auditd")
    
    for svc in "${services[@]}"; do
        if systemctl is-enabled "$svc" &>/dev/null; then
            if ! systemctl is-active "$svc" &>/dev/null; then
                add_finding "service" "HIGH" "Service enabled but not running: $svc" "systemctl start $svc"
            fi
        fi
    done
}

# 4. Verify NTS Time Sync
check_time_sync() {
    log_info "Verifying NTS time synchronization..."
    
    if ! command -v chronyc &>/dev/null; then
        add_finding "time" "MEDIUM" "chrony not installed" "Run: sudo pbp enable time"
        return
    fi
    
    if ! systemctl is-active chronyd &>/dev/null; then
        add_finding "time" "HIGH" "chronyd not running" "systemctl start chronyd"
        return
    fi
    
    # Check NTS authentication
    local nts_count=$(chronyc -n authdata 2>/dev/null | grep -c "NTS" || echo "0")
    if [[ "$nts_count" -eq 0 ]]; then
        add_finding "time" "MEDIUM" "No NTS-authenticated time sources" "Configure NTS servers in chrony.conf"
    fi
    
    # Check synchronization
    if ! chronyc tracking 2>/dev/null | grep -q "Leap status.*Normal"; then
        add_finding "time" "MEDIUM" "Time not synchronized" "Wait for chrony to sync or check network"
    fi
}

# 5. Validate DNS Hardening
check_dns() {
    log_info "Validating DNS hardening..."
    
    if [[ ! -f /etc/systemd/resolved.conf ]]; then
        add_finding "dns" "MEDIUM" "systemd-resolved not configured" "Run: sudo pbp enable dns"
        return
    fi
    
    # Check DoT
    if ! grep -q "DNSOverTLS=yes" /etc/systemd/resolved.conf; then
        add_finding "dns" "HIGH" "DNS over TLS not enabled" "Enable DoT in resolved.conf"
    fi
    
    # Check DNSSEC
    if ! grep -q "DNSSEC=yes" /etc/systemd/resolved.conf; then
        add_finding "dns" "MEDIUM" "DNSSEC not enabled" "Enable DNSSEC in resolved.conf"
    fi
    
    # Test resolution
    if ! resolvectl query cloudflare.com &>/dev/null; then
        add_finding "dns" "CRITICAL" "DNS resolution failing" "Check systemd-resolved status"
    fi
}

# 6. Inspect Container Privileges
check_containers() {
    log_info "Inspecting container privileges..."
    
    if ! command -v podman &>/dev/null; then
        add_finding "container" "LOW" "Podman not installed" "Install podman if using containers"
        return
    fi
    
    # Check for privileged containers
    local privileged=$(podman ps --filter "label=privileged=true" --format "{{.ID}}" 2>/dev/null | wc -l || echo "0")
    if [[ "$privileged" -gt 0 ]]; then
        add_finding "container" "HIGH" "$privileged privileged containers running" "Avoid privileged containers"
    fi
    
    # Check for root containers
    local containers=$(podman ps --format "{{.ID}}" 2>/dev/null || echo "")
    for cid in $containers; do
        local user=$(podman inspect --format '{{.Config.User}}' "$cid" 2>/dev/null || echo "")
        if [[ "$user" == "root" || "$user" == "0" || -z "$user" ]]; then
            add_finding "container" "MEDIUM" "Container $cid running as root" "Use USER directive in Dockerfile"
        fi
    done
}

# 7. Scan Open Ports
check_open_ports() {
    log_info "Scanning open ports..."
    
    if ! command -v ss &>/dev/null; then
        add_finding "network" "LOW" "ss command not available" "Install iproute2"
        return
    fi
    
    # Get listening ports
    local listening=$(ss -tuln | grep LISTEN | wc -l)
    
    if [[ "$listening" -gt 10 ]]; then
        add_finding "network" "MEDIUM" "$listening listening ports detected" "Review and close unnecessary services"
    fi
    
    # Check for dangerous ports
    if ss -tuln | grep -qE ":23 |:21 |:512 |:513 |:514 "; then
        add_finding "network" "CRITICAL" "Insecure services detected (telnet/ftp/rsh)" "Disable insecure services immediately"
    fi
}

# 8. Check File Permissions
check_permissions() {
    log_info "Checking file permissions..."
    
    # Check PBP directories
    if [[ -d /var/log/pbp ]]; then
        local perms=$(stat -c %a /var/log/pbp)
        if [[ "$perms" != "700" ]]; then
            add_finding "permissions" "MEDIUM" "/var/log/pbp has permissive permissions: $perms" "chmod 700 /var/log/pbp"
        fi
    fi
    
    # Check state file
    if [[ -f /var/lib/pbp/state/modules.state ]]; then
        local perms=$(stat -c %a /var/lib/pbp/state/modules.state)
        if [[ "$perms" != "600" ]]; then
            add_finding "permissions" "HIGH" "State file has permissive permissions: $perms" "chmod 600 /var/lib/pbp/state/modules.state"
        fi
    fi
}

# Generate master report
generate_master_report() {
    log_info "Generating master report..."
    
    # Create JSON report
    local json_report=$(jq -n \
        --arg hostname "$(hostname)" \
        --arg timestamp "$(date -Iseconds)" \
        --arg risk "$TOTAL_RISK" \
        --argjson findings "$ALL_FINDINGS" \
        '{
            hostname: $hostname,
            timestamp: $timestamp,
            report_type: "bughunt",
            risk_score: ($risk | tonumber),
            findings: $findings,
            summary: {
                total_findings: ($findings | length),
                critical: ($findings | map(select(.severity == "CRITICAL")) | length),
                high: ($findings | map(select(.severity == "HIGH")) | length),
                medium: ($findings | map(select(.severity == "MEDIUM")) | length),
                low: ($findings | map(select(.severity == "LOW")) | length)
            }
        }')
    
    # Save JSON
    echo "$json_report" > "${REPORT_DIR}/master-report.json"
    chmod 600 "${REPORT_DIR}/master-report.json"
    
    # Generate HTML
    python3 - "${REPORT_DIR}/master-report.json" "${REPORT_DIR}/master-report.html" << 'PYTHON'
import sys, json
from jinja2 import Template

json_file, html_file = sys.argv[1:3]

with open(json_file) as f:
    data = json.load(f)

template = Template('''
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>PBP Bug Hunt Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; background: #f5f5f5; }
        .header { background: #c0392b; color: white; padding: 20px; border-radius: 5px; }
        .summary { background: white; padding: 20px; margin: 20px 0; border-radius: 5px; }
        .finding { padding: 15px; margin: 10px 0; border-left: 4px solid #95a5a6; background: #ecf0f1; }
        .finding.critical { border-left-color: #c0392b; background: #fadbd8; }
        .finding.high { border-left-color: #e74c3c; background: #f5b7b1; }
        .finding.medium { border-left-color: #f39c12; background: #fdebd0; }
        .finding.low { border-left-color: #2ecc71; background: #d5f4e6; }
        .category { display: inline-block; background: #34495e; color: white; padding: 3px 10px; border-radius: 3px; font-size: 0.9em; }
    </style>
</head>
<body>
    <div class="header">
        <h1>🔍 PBP Bug Hunt Report</h1>
        <p>Hostname: {{ hostname }}<br>Timestamp: {{ timestamp }}</p>
    </div>
    <div class="summary">
        <h2>Summary</h2>
        <p>Risk Score: <strong>{{ risk_score }}</strong></p>
        <p>Total Findings: {{ summary.total_findings }}</p>
        <p>Critical: {{ summary.critical }} | High: {{ summary.high }} | Medium: {{ summary.medium }} | Low: {{ summary.low }}</p>
    </div>
    <div>
        <h2>Findings</h2>
        {% for finding in findings %}
        <div class="finding {{ finding.severity|lower }}">
            <span class="category">{{ finding.category }}</span>
            <strong>{{ finding.severity }}</strong>: {{ finding.description }}<br>
            <em>Remediation: {{ finding.remediation }}</em>
        </div>
        {% endfor %}
    </div>
</body>
</html>
''')

with open(html_file, 'w') as f:
    f.write(template.render(**data))
PYTHON
    
    # Generate PDF
    if command -v wkhtmltopdf &>/dev/null; then
        wkhtmltopdf \
            --enable-local-file-access \
            --no-background \
            --disable-javascript \
            "${REPORT_DIR}/master-report.html" \
            "${REPORT_DIR}/master-report.pdf" 2>/dev/null || true
        chmod 600 "${REPORT_DIR}/master-report.pdf"
    fi
    
    # Generate checksum
    sha256sum "${REPORT_DIR}/master-report.json" | awk '{print $1}' > "${REPORT_DIR}/master-report.json.sha256"
    
    log_info "Master report generated: ${REPORT_DIR}"
}

# Main execution
main() {
    log_info "Starting PBP Bug Hunt..."
    
    validate_configs
    check_firewall_rules
    check_services
    check_time_sync
    check_dns
    check_containers
    check_open_ports
    check_permissions
    
    generate_master_report
    
    echo
    echo "Bug Hunt Complete!"
    echo "=================="
    echo "Report Location: ${REPORT_DIR}"
    echo "Risk Score: ${TOTAL_RISK}"
    echo "Total Findings: $(echo "$ALL_FINDINGS" | jq 'length')"
    echo
    echo "View reports:"
    echo "  JSON: ${REPORT_DIR}/master-report.json"
    echo "  HTML: ${REPORT_DIR}/master-report.html"
    echo "  PDF:  ${REPORT_DIR}/master-report.pdf"
}

main "$@"
