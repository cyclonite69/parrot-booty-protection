#!/bin/bash
# pbp-sentinel - Central Security Sentinel for Parrot Booty Protection

source "$(dirname "$0")/../lib/pbp-lib.sh"

echo -e "${GREEN}🦜 Parrot Booty Sentinel is on watch!${NC}"
pbp_log "SENTINEL" "STARTED" "Sentinel daemon initiated watch cycle."

# Load Baseline
if [ ! -f "$BASELINE_FILE" ]; then
    pbp_alert "WARNING" "SENTINEL" "No baseline found! Sailing blind. Run 'pbp learn' first."
fi

while true; do
    # 1. Run Monitoring Modules
    for module in "$PBP_ROOT/modules"/*.sh; do
        if [ -x "$module" ]; then
            "$module" >> "$LOG_DIR/sentinel_run.log" 2>&1
        fi
    done

    # 2. State Recalculation (Mental Logic)
    # Check if any high alerts were logged in the last 10 minutes
    if grep -q "ALERT_HIGH\|ALERT_CRITICAL" "$LOG_DIR/pbp.log"; then
        set_pbp_state "SUSPICIOUS" "High severity alerts detected in logs."
    fi

    # 3. Sleep until next watch
    sleep 300 # Wait 5 minutes between full scans
done
