#!/bin/bash
# pbp-outbound.sh - Outbound Intelligence Monitor
# Tracks established connections and maps them to processes.

source "/opt/pbp/lib/pbp-lib.sh"

REPORT="$REPORT_DIR/outbound_intelligence.txt"
echo "--- Outbound Traffic Audit: $(date) ---" > "$REPORT"

# 1. Capture Established Outbound Connections (Excluding local network)
# Format: Local-Address:Port Remote-Address:Port User Process
# We filter out typical local ranges (10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16, 127.0.0.1)
echo "[Established External Connections]" >> "$REPORT"
ss -atupn | grep 'ESTAB' | grep -vE '127\.0\.0\.1|192\.168\.|10\.|172\.(1[6-9]|2[0-9]|3[0-1])\.' >> "$REPORT" || echo "No active external connections." >> "$REPORT"

pbp_log "OUTBOUND" "SCAN_COMPLETE" "Outbound intelligence report updated."
