#!/bin/bash
# pbp-privesc.sh - Privilege Escalation Monitor
# Detects unauthorized changes to root access or elevated permissions.

source "/opt/pbp/lib/pbp-lib.sh"

[ ! -f "$BASELINE_FILE" ] && exit 0

REPORT="$REPORT_DIR/privesc_audit.txt"
APPROVED_PROCS=$(cat "$BASELINE_FILE" | grep -Po '"approved_root_procs": "\K[^"]*')

echo "--- PrivEsc Audit: $(date) ---" > "$REPORT"

# 1. Audit Sudo Group Membership
echo "[Sudoers Audit]" >> "$REPORT"
grep '^sudo:.*$' /etc/group >> "$REPORT"

# 2. Detect New Root Processes
CURRENT_ROOT_PROCS=$(ps -U root -u root u | awk 'NR>1 {print $11}' | sort -u | xargs)

for proc in $CURRENT_ROOT_PROCS; do
    if [[ ! " $APPROVED_PROCS " =~ " $proc " ]]; then
        # Filter out common transient processes if needed
        pbp_alert "NOTICE" "PRIVESC" "NEW ROOT PROCESS DETECTED: $proc"
        echo "Alert: New root process $proc at $(date)" >> "$REPORT"
    fi
done

# 3. Audit SUID Binaries (Fast Check)
# Compare count of SUID binaries to baseline (simplified)
SUID_COUNT=$(find /usr/bin /usr/sbin -perm -4000 2>/dev/null | wc -l)
echo -e "
[SUID Count]: $SUID_COUNT" >> "$REPORT"

pbp_log "PRIVESC" "SCAN_COMPLETE" "Privilege escalation audit finished."
