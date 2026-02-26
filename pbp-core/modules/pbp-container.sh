#!/bin/bash
# pbp-container.sh - Container Security Watchman
# Monitors for unauthorized images, privileged containers, and host mounts.

source "/opt/pbp/lib/pbp-lib.sh"

[ ! -f "$BASELINE_FILE" ] && exit 0

REPORT="$REPORT_DIR/container_watch.txt"
APPROVED_IMAGES=$(cat "$BASELINE_FILE" | grep -Po '"approved_images": "\K[^"]*')

echo "--- Container Audit: $(date) ---" > "$REPORT"

# 1. Detect Unauthorized Images
CURRENT_IMAGES=$(podman ps --format "{{.Image}}" | sort -u | xargs 2>/dev/null || echo "")

for img in $CURRENT_IMAGES; do
    if [[ ! " $APPROVED_IMAGES " =~ " $img " ]]; then
        pbp_alert "WARNING" "CONTAINER" "UNAUTHORIZED IMAGE DETECTED: $img"
        echo "Alert: Unauthorized image $img running at $(date)" >> "$REPORT"
    fi
done

# 2. Check for Privileged Containers
PRIV_COUNT=$(podman ps --format "{{.ID}} {{.Image}}" --filter "privileged=true" | wc -l)
if [ "$PRIV_COUNT" -gt 0 ]; then
    PRIV_LIST=$(podman ps --format "{{.ID}} {{.Image}}" --filter "privileged=true")
    pbp_alert "HIGH" "CONTAINER" "$PRIV_COUNT Privileged containers detected! Possible security risk."
    echo "CRITICAL: Privileged containers found:" >> "$REPORT"
    echo "$PRIV_LIST" >> "$REPORT"
    set_pbp_state "SUSPICIOUS" "Privileged containers detected."
fi

# 3. Check for Sensitive Host Mounts (e.g., /etc, /root, /var/run/docker.sock)
SENSITIVE_MOUNTS=$(podman ps --format "{{.ID}}" | xargs -I {} podman inspect {} --format '{{ range .Mounts }}{{ .Source }}{{ end }}' 2>/dev/null | grep -E "^/etc|^/root|^/var/run|^/dev" || true)

if [ -n "$SENSITIVE_MOUNTS" ]; then
    pbp_alert "HIGH" "CONTAINER" "SENSITIVE HOST MOUNTS DETECTED in active containers."
    echo "Warning: Sensitive host paths mounted:" >> "$REPORT"
    echo "$SENSITIVE_MOUNTS" >> "$REPORT"
fi

pbp_log "CONTAINER" "SCAN_COMPLETE" "Container watch cycle finished."
