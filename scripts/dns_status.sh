#!/bin/bash

# DNS Hardening Status Check
# Usage: ./dns_status.sh

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "=== DNS Hardening Status Check ==="
echo "Time: $(date)"
echo ""

# Check immutable flag
if lsattr /etc/resolv.conf 2>/dev/null | grep -q -- '----i---------'; then
    echo -e "${GREEN}✓${NC} Immutable flag: ACTIVE"
    IMMUTABLE=1
else
    echo -e "${RED}✗${NC} Immutable flag: MISSING"
    IMMUTABLE=0
fi

# Check resolv.conf content
if grep -q "127.0.0.1" /etc/resolv.conf 2>/dev/null; then
    echo -e "${GREEN}✓${NC} Resolv.conf: Using localhost resolver"
else
    echo -e "${RED}✗${NC} Resolv.conf: NOT using localhost"
fi

# Check NetworkManager config
if [ -f /etc/NetworkManager/conf.d/dns-hardening.conf ]; then
    echo -e "${GREEN}✓${NC} NetworkManager: DNS management disabled"
else
    echo -e "${YELLOW}⚠${NC} NetworkManager: Hardening config missing"
fi

# Check Unbound
if systemctl is-active unbound >/dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} Unbound: Running"
else
    echo -e "${RED}✗${NC} Unbound: Not running"
fi

# Test DNS resolution
if timeout 3 nslookup google.com >/dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} DNS Resolution: Working"
else
    echo -e "${RED}✗${NC} DNS Resolution: FAILED"
fi

echo ""
if [ $IMMUTABLE -eq 1 ]; then
    echo -e "${GREEN}Status: HARDENED${NC}"
    exit 0
else
    echo -e "${RED}Status: COMPROMISED - Run dns_harden.sh${NC}"
    exit 1
fi
