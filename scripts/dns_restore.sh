#!/bin/bash

# DNS Emergency Restoration Script for Parrot OS
# Purpose: Restore basic DNS when hardened configs fail
# Usage: sudo ./dns_restore.sh

set -euo pipefail

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging setup
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOGFILE="/tmp/dns_restore_${TIMESTAMP}.log"
BACKUP_DIR="/root/dns_backups/backup_${TIMESTAMP}"

# Logging functions
log() {
    echo -e "${GREEN}[$(date '+%H:%M:%S')] $1${NC}" | tee -a "$LOGFILE"
}

error() {
    echo -e "${RED}[$(date '+%H:%M:%S')] ERROR: $1${NC}" | tee -a "$LOGFILE"
}

warn() {
    echo -e "${YELLOW}[$(date '+%H:%M:%S')] WARNING: $1${NC}" | tee -a "$LOGFILE"
}

# Root check
require_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root"
        exit 1
    fi
}

# DNS test function
test_dns() {
    local hostname=${1:-google.com}
    timeout 2 nslookup "$hostname" >/dev/null 2>&1
}

# Main restoration function
restore_dns() {
    log "Starting DNS emergency restoration"
    
    # Step 1: Stop services
    log "Step 1: Stopping DNS services"
    systemctl stop unbound 2>/dev/null || true
    systemctl stop systemd-resolved 2>/dev/null || true
    
    # Step 2: Backup current configs
    log "Step 2: Backing up current configurations"
    mkdir -p "$BACKUP_DIR"
    cp /etc/resolv.conf "$BACKUP_DIR/" 2>/dev/null || true
    cp /etc/unbound/unbound.conf "$BACKUP_DIR/" 2>/dev/null || true
    cp /etc/systemd/resolved.conf "$BACKUP_DIR/" 2>/dev/null || true
    log "Backup saved to: $BACKUP_DIR"
    
    # Step 3: Restore basic resolv.conf
    log "Step 3: Restoring basic /etc/resolv.conf"
    cat > /etc/resolv.conf << 'EOF'
# Emergency DNS restoration - basic public resolvers
nameserver 1.1.1.1
nameserver 1.0.0.1
nameserver 9.9.9.9
nameserver 149.112.112.112
nameserver 8.8.8.8
nameserver 8.8.4.4
EOF
    
    # Step 4: Test DNS immediately
    log "Step 4: Testing DNS resolution"
    if test_dns google.com; then
        log "DNS test PASSED"
    else
        error "DNS test FAILED - check network connectivity"
        return 1
    fi
    
    # Step 5: Disable problematic services
    log "Step 5: Masking problematic services"
    systemctl mask unbound 2>/dev/null || true
    systemctl mask systemd-resolved 2>/dev/null || true
    
    # Step 6: Reset systemd-resolved config
    log "Step 6: Resetting systemd-resolved configuration"
    cat > /etc/systemd/resolved.conf << 'EOF'
[Resolve]
#DNS=
#FallbackDNS=
#Domains=
#LLMNR=yes
#MulticastDNS=yes
#DNSSEC=no
#DNSOverTLS=no
#Cache=yes
#DNSStubListener=yes
EOF
    
    # Step 7: Run sequential DNS tests
    log "Step 7: Running comprehensive DNS tests"
    local test_domains=("google.com" "example.com" "cloudflare.com")
    local failed_tests=0
    
    for domain in "${test_domains[@]}"; do
        if test_dns "$domain"; then
            log "DNS test for $domain: PASSED"
        else
            error "DNS test for $domain: FAILED"
            ((failed_tests++))
        fi
    done
    
    if [[ $failed_tests -eq 0 ]]; then
        log "All DNS tests PASSED"
    else
        warn "$failed_tests DNS tests failed"
    fi
    
    # Step 8: Display system status
    log "Step 8: System status report"
    echo -e "\n${GREEN}=== DNS RESTORATION COMPLETE ===${NC}"
    echo -e "${GREEN}Active nameservers:${NC}"
    grep nameserver /etc/resolv.conf
    
    echo -e "\n${GREEN}DNS resolution test:${NC}"
    if nslookup google.com; then
        log "Final DNS test: SUCCESS"
    else
        error "Final DNS test: FAILED"
    fi
    
    echo -e "\n${GREEN}Service status:${NC}"
    systemctl is-active unbound || echo "unbound: inactive (expected)"
    systemctl is-active systemd-resolved || echo "systemd-resolved: inactive (expected)"
    
    # Step 9: Provide re-hardening instructions
    echo -e "\n${YELLOW}=== NEXT STEPS FOR RE-HARDENING ===${NC}"
    echo "1. Unmask services: sudo systemctl unmask unbound"
    echo "2. Review unbound.conf with proper fallback configuration"
    echo "3. Test incrementally: dig @127.0.0.1 google.com"
    echo "4. Re-enable services one by one"
    echo "5. Keep this script available for future emergencies"
    
    log "Restoration completed. Logfile: $LOGFILE"
}

# Main execution
main() {
    require_root
    log "DNS Emergency Restoration Script Started"
    log "Logfile: $LOGFILE"
    
    restore_dns
    
    echo -e "\n${GREEN}Emergency restoration completed successfully!${NC}"
    echo -e "Logfile saved to: ${GREEN}$LOGFILE${NC}"
    echo -e "Backup saved to: ${GREEN}$BACKUP_DIR${NC}"
}

main "$@"
