#!/bin/bash
# pbp-network.sh - Network Behavior Sentinel

source "/opt/pbp/lib/pbp-lib.sh"

[ ! -f "$BASELINE_FILE" ] && exit 0

APPROVED_PORTS=$(cat "$BASELINE_FILE" | grep -Po '"approved_ports": "\K[^"]*')
CURRENT_PORTS=$(ss -tuln | awk 'NR>1 {print $5}' | cut -d: -f2 | sort -u | xargs)

# Detect new ports
for port in $CURRENT_PORTS; do
    if [[ ! " $APPROVED_PORTS " =~ " $port " ]]; then
        pbp_alert "HIGH" "NETWORK" "UNKNOWN SERVICE DETECTED on Port: $port"
        echo "Port $port appeared at $(date)" >> "$REPORT_DIR/network_delta.txt"
        set_pbp_state "SUSPICIOUS" "New listening port detected: $port"
    fi
done

pbp_log "NETWORK" "SCAN_COMPLETE" "Port scan compared to baseline."
