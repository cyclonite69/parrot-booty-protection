#!/bin/bash
# status.sh for container module
if command -v podman >/dev/null; then
    echo "active"
else
    echo "inactive"
fi
