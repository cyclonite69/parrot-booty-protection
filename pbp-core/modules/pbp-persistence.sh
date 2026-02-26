#!/bin/bash
# pbp-persistence.sh - Audit attacker persistence locations

source "/opt/pbp/lib/pbp-lib.sh"

REPORT="$REPORT_DIR/persistence_audit.txt"
echo "--- Persistence Audit: $(date) ---" > "$REPORT"

# 1. Audit Systemd Services
echo "[Systemd Services]" >> "$REPORT"
systemctl list-unit-files --type=service | grep "enabled" >> "$REPORT"

# 2. Audit Cron Jobs
echo -e "
[Cron Jobs]" >> "$REPORT"
for user in $(cut -f1 -d: /etc/passwd); do
    crontab -u "$user" -l 2>/dev/null | grep -v "^#" && echo "User: $user" >> "$REPORT"
done

# 3. Audit shell initialization
echo -e "
[Shell Initialization]" >> "$REPORT"
ls -la /etc/profile.d/ >> "$REPORT"
ls -la /etc/rc.local 2>/dev/null >> "$REPORT"

pbp_log "PERSISTENCE" "SCAN_COMPLETE" "Persistence report updated."
