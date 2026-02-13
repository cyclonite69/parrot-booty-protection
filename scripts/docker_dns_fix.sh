#!/bin/bash

# Docker DNS Fixer - v1.1
# Purpose: Automatically configure Unbound, nftables, and Docker for container DNS resolution.
# Usage: sudo ./docker_dns_fix.sh [--check|--apply|--dry-run|--revert]

set -euo pipefail

# --- Configuration & Setup ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
NC='\033[0m'

UNBOUND_CONF="/etc/unbound/unbound.conf"
NFT_DOCKER_RULES_PATH="/etc/nftables-docker.conf"
DOCKER_DAEMON_CONF="/etc/docker/daemon.json"
BACKUP_DIR="/root/dns_backups/docker_fix_bak_$(date +%Y%m%d_%H%M%S)"

# --- Logging Functions ---
log() { echo -e "${GREEN}[INFO] $1${NC}"; }
warn() { echo -e "${YELLOW}[WARN] $1${NC}"; }
error() { echo -e "${RED}[ERROR] $1${NC}"; exit 1; }
step() { echo -e "\n${CYAN}>>> $1${NC}"; }
ok() { echo -e "${GREEN}✅ $1${NC}"; }
not_ok() { echo -e "${RED}❌ $1${NC}"; }
dryrun_echo() { echo -e "${BLUE}[DRY-RUN] $1${NC}"; }

# --- Main Logic ---
main() {
    require_root
    
    local MODE="--check"
    if [ -n "${1-}" ]; then
        if [[ "$1" == "--check" || "$1" == "--apply" || "$1" == "--dry-run" || "$1" == "--revert" ]]; then
            MODE=$1
        else
            error "Invalid mode '$1'. Use --check, --apply, --dry-run, or --revert."
        fi
    fi
    log "Running in ${MODE} mode."

    # --- Step 1: Sanity Checks ---
    step "Performing sanity checks..."
    if ! command -v docker &> /dev/null; then error "Docker is not installed."; fi
    if ! systemctl is-active --quiet docker; then error "Docker daemon is not running."; fi
    if ! command -v unbound &> /dev/null; then error "Unbound is not installed."; fi
    if ! systemctl is-active --quiet unbound; then error "Unbound service is not running."; fi
    ok "All required services are running."

    # --- Step 2: Auto-detect Docker Bridge ---
    step "Detecting Docker network..."
    local docker_ip=$(ip -4 addr show docker0 2>/dev/null | grep -oP 'inet \K[\d.]+')
    if [ -z "$docker_ip" ]; then error "Could not detect docker0 interface IP."; fi
    local docker_subnet=$(ip -4 addr show docker0 2>/dev/null | grep -oP 'inet \K[\d.]+\/[\d]+' | cut -d'/' -f1 | cut -d'.' -f1-3).0/24
    ok "Detected docker0 IP: $docker_ip"
    ok "Detected docker0 Subnet: $docker_subnet"

    # --- Step 3: Unbound Configuration ---
    step "Checking Unbound configuration..."
    local unbound_ip_ok=$(grep -q "interface: $docker_ip" "$UNBOUND_CONF" && echo "true" || echo "false")
    local unbound_acl_ok=$(grep -q "access-control: $docker_subnet allow" "$UNBOUND_CONF" && echo "true" || echo "false")
    
    if $unbound_ip_ok; then ok "Unbound is listening on $docker_ip."; else not_ok "Unbound is NOT listening on $docker_ip."; fi
    if $unbound_acl_ok; then ok "Unbound allows access from $docker_subnet."; else not_ok "Unbound does NOT allow access from $docker_subnet."; fi

    # --- Step 4: Nftables Configuration ---
    step "Checking nftables configuration..."
    local nft_include_ok=$(grep -q "include \"$NFT_DOCKER_RULES_PATH\"" "/etc/nftables.conf" && echo "true" || echo "false")
    local nft_file_ok=$(test -f "$NFT_DOCKER_RULES_PATH" && echo "true" || echo "false")

    if $nft_include_ok; then ok "Nftables main config includes Docker rules."; else not_ok "Nftables main config does NOT include Docker rules."; fi
    if $nft_file_ok; then ok "Nftables Docker rule file exists."; else not_ok "Nftables Docker rule file does NOT exist."; fi

    # --- Step 5: Docker Daemon Configuration ---
    step "Checking Docker daemon configuration..."
    local docker_dns_ok=$(grep -q "\"dns\":.*\"$docker_ip\"" "$DOCKER_DAEMON_CONF" 2>/dev/null && echo "true" || echo "false")
    if $docker_dns_ok; then ok "Docker daemon is configured to use host DNS."; else not_ok "Docker daemon is NOT configured to use host DNS."; fi
    
    # --- Act based on mode ---
    if [ "$MODE" == "--check" ]; then
        log "Check complete."
        exit 0
    fi
    
    run_apply_or_dryrun "$MODE" "$docker_ip" "$docker_subnet" "$unbound_ip_ok" "$unbound_acl_ok" "$nft_include_ok" "$nft_file_ok" "$docker_dns_ok"
}

run_apply_or_dryrun() {
    local MODE="$1" docker_ip="$2" docker_subnet="$3" unbound_ip_ok="$4" unbound_acl_ok="$5" nft_include_ok="$6" nft_file_ok="$7" docker_dns_ok="$8"
    local action_needed=false
    
    step "Preparing actions for $MODE mode..."
    
    # Plan Unbound changes
    if ! $unbound_ip_ok || ! $unbound_acl_ok; then
        action_needed=true
        if [ "$MODE" == "--dry-run" ]; then
            dryrun_echo "Would modify $UNBOUND_CONF to listen on and allow access from the Docker bridge."
        elif [ "$MODE" == "--apply" ]; then
            log "Modifying $UNBOUND_CONF..."
            mkdir -p "$BACKUP_DIR" && cp "$UNBOUND_CONF" "$BACKUP_DIR/unbound.conf.bak"
            if ! $unbound_ip_ok; then sed -i "/interface: 127.0.0.1/a \    interface: $docker_ip" "$UNBOUND_CONF"; fi
            if ! $unbound_acl_ok; then sed -i "/access-control: 127.0.0.0\/8 allow/a \    access-control: $docker_subnet allow" "$UNBOUND_CONF"; fi
        fi
    fi

    # Plan Nftables changes
    if ! $nft_include_ok || ! $nft_file_ok; then
        action_needed=true
        if [ "$MODE" == "--dry-run" ]; then
            dryrun_echo "Would create $NFT_DOCKER_RULES_PATH and include it in /etc/nftables.conf."
        elif [ "$MODE" == "--apply" ]; then
            log "Modifying nftables configuration..."
            mkdir -p "$BACKUP_DIR" && cp "/etc/nftables.conf" "$BACKUP_DIR/nftables.conf.bak"
            echo -e "chain input { iifname \"docker0\" udp dport 53 accept; iifname \"docker0\" tcp dport 53 accept; }" > "$NFT_DOCKER_RULES_PATH"
            if ! $nft_include_ok; then echo "include \"$NFT_DOCKER_RULES_PATH\"" >> "/etc/nftables.conf"; fi
        fi
    fi

    # Plan Docker daemon changes
    if ! $docker_dns_ok; then
        action_needed=true
        if [ "$MODE" == "--dry-run" ]; then
            dryrun_echo "Would create/modify $DOCKER_DAEMON_CONF to set host DNS."
        elif [ "$MODE" == "--apply" ]; then
            log "Modifying Docker daemon configuration..."
            if [ -f "$DOCKER_DAEMON_CONF" ]; then mkdir -p "$BACKUP_DIR" && cp "$DOCKER_DAEMON_CONF" "$BACKUP_DIR/daemon.json.bak"; fi
            # This simple approach overwrites existing config. A `jq`-based approach would be safer for complex files.
            echo "{\"dns\": [\"$docker_ip\"]}" > "$DOCKER_DAEMON_CONF"
        fi
    fi

    if ! $action_needed; then
        log "No changes needed."
        exit 0
    fi

    # Restart services
    if [ "$MODE" == "--apply" ]; then
        step "Restarting services..."
        systemctl restart unbound && ok "Unbound restarted." || error "Failed to restart Unbound."
        systemctl restart nftables && ok "Nftables restarted." || error "Failed to restart Nftables."
        systemctl restart docker && ok "Docker restarted." || error "Failed to restart Docker."
        log "All changes applied successfully."
    elif [ "$MODE" == "--dry-run" ]; then
        dryrun_echo "Would restart unbound, nftables, and docker services."
    fi
}

revert() {
    require_root
    step "Reverting Docker DNS configuration..."
    local docker_ip=$(ip -4 addr show docker0 2>/dev/null | grep -oP 'inet \K[\d.]+')
    local docker_subnet=$(ip -4 addr show docker0 2>/dev/null | grep -oP 'inet \K[\d.]+\/[\d]+' | cut -d'/' -f1 | cut -d'.' -f1-3).0/24

    # Revert Unbound
    if [ -n "$docker_ip" ]; then sed -i "/interface: $docker_ip/d" "$UNBOUND_CONF"; fi
    if [ -n "$docker_subnet" ]; then sed -i "/access-control: $docker_subnet allow/d" "$UNBOUND_CONF"; fi
    log "Reverted Unbound config."

    # Revert Nftables
    sed -i "/include \"$NFT_DOCKER_RULES_PATH\"/d" "/etc/nftables.conf"
    rm -f "$NFT_DOCKER_RULES_PATH"
    log "Reverted Nftables config."

    # Revert Docker Daemon
    rm -f "$DOCKER_DAEMON_CONF"
    log "Removed Docker daemon config."

    step "Restarting services..."
    systemctl restart unbound && ok "Unbound restarted."
    systemctl restart nftables && ok "Nftables restarted."
    systemctl restart docker && ok "Docker restarted."
    log "Revert complete."
}

# --- Main Execution ---
case "${1-}" in
    --revert)
        revert
        ;;
    *)
        main "$@"
        ;;
esac
