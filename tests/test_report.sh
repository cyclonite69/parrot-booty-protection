#!/bin/bash
# Generate test report

PBP_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PBP_ROOT
export PBP_REPORT_DIR="/tmp/pbp-test-reports"

mkdir -p "$PBP_REPORT_DIR"/{json,html,checksums}

source "${PBP_ROOT}/core/lib/report.sh"

# Create sample report data
report_data=$(jq -n '{
    network: {
        module: "network",
        risk_score: 15,
        status: "pass",
        findings: [
            {
                id: "NET-001",
                severity: "MEDIUM",
                title: "Multiple open ports detected",
                description: "Found 8 listening ports on the system",
                remediation: "Review and close unnecessary services"
            },
            {
                id: "NET-002",
                severity: "LOW",
                title: "IPv6 disabled",
                description: "IPv6 is not available on this system",
                remediation: "None required if intentional"
            }
        ]
    },
    dns: {
        module: "dns",
        risk_score: 5,
        status: "pass",
        findings: [
            {
                id: "DNS-001",
                severity: "HIGH",
                title: "DNS over TLS not enabled",
                description: "DNS queries are not encrypted",
                remediation: "Enable DoT in systemd-resolved configuration"
            }
        ]
    },
    time: {
        module: "time",
        risk_score: 0,
        status: "pass",
        findings: []
    }
}')

echo "Generating test report..."
report_id=$(create_report "scan" "$report_data")

echo
echo "✓ Test report generated: ${report_id}"
echo
echo "JSON: ${PBP_REPORT_DIR}/json/${report_id}.json"
echo "HTML: ${PBP_REPORT_DIR}/html/${report_id}.html"
echo
echo "Open HTML report in browser:"
echo "  xdg-open ${PBP_REPORT_DIR}/html/${report_id}.html"
