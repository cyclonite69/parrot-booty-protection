#!/bin/bash
# status.sh for network module
if command -v nmap >/dev/null; then
    echo "active"
else
    echo "inactive"
fi
