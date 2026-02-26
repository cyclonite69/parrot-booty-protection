#!/bin/bash
# pbp-learn.sh - Baseline Learning Mode for PBP

source "$(dirname "$0")/../lib/pbp-lib.sh"

echo -e "${CYAN}🏴‍☠️ Learning Mode Enabled: Mapping the Ship's Rigging...${NC}"

# 1. Capture Listening Ports
echo "Capturing open ports..."
PORTS=$(ss -tuln | awk 'NR>1 {print $5}' | cut -d: -f2 | sort -u | xargs)

# 2. Capture Running Services
echo "Capturing active services..."
SERVICES=$(systemctl list-units --type=service --state=running --no-legend | awk '{print $1}' | sort | xargs)

# 3. Capture Root Processes
echo "Capturing root-owned processes..."
ROOT_PROCS=$(ps -U root -u root u | awk 'NR>1 {print $11}' | sort -u | xargs)

# 4. Capture Containers (Podman)
echo "Capturing container profiles..."
CONTAINERS=$(podman ps --format "{{.Image}}" | sort -u | xargs 2>/dev/null || echo "none")

# Store to Baseline JSON
cat << EOF > "$BASELINE_FILE"
{
  "timestamp": "$(date)",
  "approved_ports": "$PORTS",
  "approved_services": "$SERVICES",
  "approved_root_procs": "$ROOT_PROCS",
  "approved_images": "$CONTAINERS",
  "exposure_score_baseline": 100
}
EOF

pbp_log "LEARNER" "BASELINE_CREATED" "System profile stored at $BASELINE_FILE"
echo -e "${GREEN}✓ Hull integrity verified. Baseline stored in the locker.${NC}"
