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

    # 2. State Recalculation
    # Check for outdated packages signal (basic check)
    if apt list --upgradable 2>/dev/null | grep -q upgradable; then
        pbp_emit_signal "outdated_packages" "1"
    else
        pbp_emit_signal "outdated_packages" "0"
    fi

    recalculate_ship_state

    # 3. Sleep until next watch
    sleep 300 # Wait 5 minutes between full scans
done
