#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PBP_ROOT="${PBP_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
source "${PBP_ROOT}/core/lib/report.sh"

findings='[]'

# Check for running containers
running_containers=$(podman ps -q 2>/dev/null | wc -l || echo "0")

# Check for privileged containers
if podman ps --filter "label=privileged=true" --format "{{.ID}}" 2>/dev/null | grep -q .; then
    findings=$(echo "$findings" | jq '. += [{
        "id": "CONT-001",
        "severity": "HIGH",
        "title": "Privileged containers detected",
        "description": "Running containers with elevated privileges",
        "remediation": "Avoid privileged containers, use capabilities instead"
    }]')
fi

# Check for containers running as root
root_containers=$(podman ps --format "{{.ID}}" 2>/dev/null | while read cid; do
    if podman inspect "$cid" 2>/dev/null | jq -e '.[] | select(.Config.User == "root" or .Config.User == "0")' &>/dev/null; then
        echo "$cid"
    fi
done | wc -l)

if [[ "$root_containers" -gt 0 ]]; then
    findings=$(echo "$findings" | jq --arg cnt "$root_containers" '. += [{
        "id": "CONT-002",
        "severity": "MEDIUM",
        "title": "Containers running as root",
        "description": ($cnt + " containers running with root user"),
        "remediation": "Use non-root users in containers"
    }]')
fi

# Check for images with known vulnerabilities (basic check)
if command -v trivy &>/dev/null; then
    vuln_images=$(podman images --format "{{.Repository}}:{{.Tag}}" 2>/dev/null | while read img; do
        if trivy image --severity HIGH,CRITICAL --quiet "$img" 2>/dev/null | grep -q "Total:"; then
            echo "$img"
        fi
    done | wc -l)
    
    if [[ "$vuln_images" -gt 0 ]]; then
        findings=$(echo "$findings" | jq --arg cnt "$vuln_images" '. += [{
            "id": "CONT-003",
            "severity": "HIGH",
            "title": "Vulnerable container images",
            "description": ($cnt + " images with HIGH/CRITICAL vulnerabilities"),
            "remediation": "Update or rebuild vulnerable images"
        }]')
    fi
fi

risk_score=$(calculate_risk_score "$findings")

report_data=$(jq -n \
    --argjson findings "$findings" \
    --arg score "$risk_score" \
    --arg running "$running_containers" \
    '{
        module: "container",
        findings: $findings,
        risk_score: ($score | tonumber),
        running_containers: ($running | tonumber),
        status: (if ($score | tonumber) > 10 then "warning" else "pass" end)
    }')

report_id=$(create_report "scan" "$report_data")
echo "Container security scan complete: ${report_id}"
