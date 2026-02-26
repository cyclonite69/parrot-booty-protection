#!/bin/bash
# pbp-integrity.sh - File Integrity Monitoring (FIM)
# Uses AIDE to detect tampering with critical system files.

source "/opt/pbp/lib/pbp-lib.sh"

AIDE_DB="/var/lib/aide/aide.db.gz"
AIDE_DB_NEW="/var/lib/aide/aide.db.new.gz"

# 1. Ensure AIDE is installed
if ! command -v aide >/dev/null; then
    pbp_alert "NOTICE" "INTEGRITY" "AIDE not found. Installing the sentry..."
    sudo apt-get update -q && sudo apt-get install -y aide aide-common
fi

# 2. Initialize Database if missing
if [ ! -f "$AIDE_DB" ]; then
    pbp_alert "WARNING" "INTEGRITY" "Initializing integrity database. This may take a moment..."
    sudo aideinit --force --yes
    pbp_log "INTEGRITY" "DB_INIT" "AIDE database established."
    exit 0
fi

# 3. Run Integrity Check
pbp_log "INTEGRITY" "CHECK_START" "Starting file integrity scan..."
REPORT_FILE="$REPORT_DIR/integrity_alert_$(date +%Y%m%d_%H%M%S).txt"

if sudo aide --check > "$REPORT_FILE" 2>&1; then
    pbp_log "INTEGRITY" "CHECK_PASS" "No tampering detected. The hull is sound."
    rm "$REPORT_FILE"
else
    pbp_alert "HIGH" "INTEGRITY" "FILE TAMPERING DETECTED! Check $REPORT_FILE for details."
    set_pbp_state "SUSPICIOUS" "File integrity check failed."
    
    # Save a summary to the main log
    grep -A 10 "Summary:" "$REPORT_FILE" >> "$LOG_DIR/pbp.log"
fi
