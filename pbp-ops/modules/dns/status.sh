#!/bin/bash
# status.sh for DNS module
if systemctl is-active --quiet unbound && grep -q "nameserver 127.0.0.1" /etc/resolv.conf; then
    echo "active"
else
    echo "inactive"
fi
