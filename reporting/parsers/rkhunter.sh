#!/bin/bash
# rkhunter Output Parser
set -euo pipefail

raw_file="${1:-}"

if [[ ! -f "$raw_file" ]]; then
    echo '{"error": "Input file not found"}' >&2
    exit 1
fi

# Parse rkhunter output
warnings=$(grep -i "warning" "$raw_file" | wc -l || echo "0")
infections=$(grep -i "infected" "$raw_file" | wc -l || echo "0")

# Extract findings
findings='[]'

while IFS= read -r line; do
    if echo "$line" | grep -qi "warning\|infected"; then
        # Sanitize input
        line=$(echo "$line" | tr -cd '[:print:]' | head -c 200)
        
        severity="MEDIUM"
        if echo "$line" | grep -qi "infected"; then
            severity="CRITICAL"
        fi
        
        findings=$(echo "$findings" | jq --arg line "$line" --arg sev "$severity" '. += [{
            severity: $sev,
            description: $line,
            remediation: "Review rkhunter log for details"
        }]')
    fi
done < "$raw_file"

# Calculate risk score
risk_score=$((infections * 10 + warnings * 2))

# Generate normalized JSON
jq -n \
    --arg hostname "$(hostname)" \
    --arg timestamp "$(date -Iseconds)" \
    --arg scanner "rkhunter" \
    --arg risk "$risk_score" \
    --argjson findings "$findings" \
    '{
        hostname: $hostname,
        timestamp: $timestamp,
        scanner: $scanner,
        risk_score: ($risk | tonumber),
        findings: $findings,
        summary: {
            warnings: ($findings | map(select(.severity == "MEDIUM")) | length),
            infections: ($findings | map(select(.severity == "CRITICAL")) | length)
        }
    }'
