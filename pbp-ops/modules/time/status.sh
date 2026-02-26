#!/bin/bash
# status.sh for time module
if chronyc sources | grep -q " N "; then
    echo "active"
else
    echo "inactive"
fi
