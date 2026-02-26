#!/bin/bash
# status.sh for rootkit module
if command -v rkhunter >/dev/null && command -v chkrootkit >/dev/null; then
    echo "active"
else
    echo "inactive"
fi
