#!/bin/bash
# nmap Output Parser
set -euo pipefail

raw_file="${1:-}"

if [[ ! -f "$raw_file" ]]; then
    echo '{"error": "Input file not found"}' >&2
    exit 1
fi

# Parse nmap output
findings='[]'
open_ports=()

while IFS= read -r line; do
    if echo "$line" | grep -q "^[0-9].*open"; then
        port=$(echo "$line" | awk '{print $1}' | cut -d'/' -f1)
        service=$(echo "$line" | awk '{print $3}' | tr -cd '[:alnum:]-')
        
        open_ports+=("$port")
        
        severity="LOW"
        if [[ "$port" =~ ^(23|21|512|513|514)$ ]]; then
            severity="HIGH"  # Insecure services
        elif [[ "$port" =~ ^(3306|5432|27017|6379)$ ]]; then
            severity="MEDIUM"  # Database ports
        fi
        
        findings=$(echo "$findings" | jq --arg port "$port" --arg svc "$service" --arg sev "$severity" '. += [{
            severity: $sev,
            description: ("Port " + $port + " open (" + $svc + ")"),
            remediation: "Review if this port should be exposed"
        }]')
    fi
done < "$raw_file"

# Calculate risk
port_count=${#open_ports[@]}
risk_score=$((port_count * 2))

# Increase risk for dangerous ports
if echo "${open_ports[*]}" | grep -qE "23|21|512|513|514"; then
    risk_score=$((risk_score + 20))
fi

jq -n \
    --arg hostname "$(hostname)" \
    --arg timestamp "$(date -Iseconds)" \
    --arg scanner "nmap" \
    --arg risk "$risk_score" \
    --argjson findings "$findings" \
    --arg ports "${open_ports[*]}" \
    '{
        hostname: $hostname,
        timestamp: $timestamp,
        scanner: $scanner,
        risk_score: ($risk | tonumber),
        findings: $findings,
        summary: {
            open_ports: ($ports | split(" ") | length),
            ports: $ports
        }
    }'
