#!/bin/bash
# pbp-persistence.sh - Audit attacker persistence locations

source "/opt/pbp/lib/pbp-lib.sh"

REPORT="$REPORT_DIR/persistence_audit.txt"
[ ! -f "$BASELINE_FILE" ] && exit 0

echo "--- Persistence Audit: $(date) ---" > "$REPORT"

# 1. Audit Systemd Services
APPROVED_SERVICES=$(cat "$BASELINE_FILE" | grep -Po '"approved_services": "\K[^"]*')
CURRENT_SERVICES=$(systemctl list-units --type=service --state=running --no-legend | awk '{print $1}' | sort | xargs)

risk=0
echo "[Unauthorized Services]" >> "$REPORT"
for srv in $CURRENT_SERVICES; do
    if [[ ! " $APPROVED_SERVICES " =~ " $srv " ]]; then
        echo "Alert: Unknown running service $srv" >> "$REPORT"
        pbp_alert "WARNING" "PERSISTENCE" "UNKNOWN RUNNING SERVICE detected: $srv"
        risk=1
    fi
done

pbp_emit_signal "persistence_risk" "$risk"
pbp_log "PERSISTENCE" "SCAN_COMPLETE" "Persistence audit finished. Risk: $risk"
