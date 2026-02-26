#!/bin/bash
# status.sh for system module
if [ -f /etc/sysctl.d/99-pbp-hardening.conf ]; then
    echo "active"
else
    echo "inactive"
fi
