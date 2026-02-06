#!/bin/bash

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOGFILE="/tmp/dns_harden_${TIMESTAMP}.log"
BACKUP_DIR="/root/dns_backups/harden_${TIMESTAMP}"

log() { echo -e "${GREEN}[$(date '+%H:%M:%S')] $1${NC}" | tee -a "$LOGFILE"; }
error() { echo -e "${RED}[$(date '+%H:%M:%S')] ERROR: $1${NC}" | tee -a "$LOGFILE"; exit 1; }
warn() { echo -e "${YELLOW}[$(date '+%H:%M:%S')] WARNING: $1${NC}" | tee -a "$LOGFILE"; }

[[ $EUID -ne 0 ]] && error "Must run as root"

log "DNS Hardening Script Started"
log "Logfile: $LOGFILE"
mkdir -p "$BACKUP_DIR"

log "Backing up current configs"
cp /etc/resolv.conf "$BACKUP_DIR/resolv.conf.bak" 2>/dev/null || true
cp /etc/NetworkManager/NetworkManager.conf "$BACKUP_DIR/NetworkManager.conf.bak" 2>/dev/null || true

log "Removing immutable flag if exists"
chattr -i /etc/resolv.conf 2>/dev/null || true

log "Removing symlink and creating static file"
rm -f /etc/resolv.conf

log "Creating hardened resolv.conf"
cat > /etc/resolv.conf << 'EOF'
# Hardened DNS Configuration - DO NOT MODIFY
nameserver 127.0.0.1
nameserver 1.1.1.1
nameserver 1.0.0.1
nameserver 9.9.9.9
options timeout:2
options attempts:3
options edns0
options trust-ad
EOF

log "Setting immutable flag on resolv.conf"
chattr +i /etc/resolv.conf

log "Configuring NetworkManager to not manage DNS"
mkdir -p /etc/NetworkManager/conf.d
cat > /etc/NetworkManager/conf.d/dns-hardening.conf << 'EOF'
[main]
dns=none
systemd-resolved=false
rc-manager=unmanaged
EOF

log "Restarting NetworkManager"
systemctl restart NetworkManager 2>/dev/null || warn "NetworkManager restart failed"

log "Verifying immutable flag"
lsattr /etc/resolv.conf | grep -q -- '----i---------' && log "Immutable flag confirmed" || warn "Immutable flag not set"

log "Testing DNS resolution"
if timeout 5 nslookup google.com >/dev/null 2>&1; then
    log "DNS test PASSED"
else
    error "DNS test FAILED"
fi

echo -e "\n${GREEN}=== DNS HARDENING COMPLETE ===${NC}" | tee -a "$LOGFILE"
echo "Backup: $BACKUP_DIR" | tee -a "$LOGFILE"
echo "Logfile: $LOGFILE"
echo "To unharden: sudo chattr -i /etc/resolv.conf"
