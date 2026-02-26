#!/bin/bash
set -euo pipefail

echo "Configuring Podman security..."

# Create secure policy
mkdir -p /etc/containers
cat > /etc/containers/policy.json << 'EOF'
{
    "default": [
        {
            "type": "reject"
        }
    ],
    "transports": {
        "docker": {
            "docker.io": [
                {
                    "type": "insecureAcceptAnything"
                }
            ],
            "quay.io": [
                {
                    "type": "insecureAcceptAnything"
                }
            ]
        }
    }
}
EOF

# Configure rootless defaults
mkdir -p /etc/containers/containers.conf.d
cat > /etc/containers/containers.conf.d/security.conf << 'EOF'
[containers]
seccomp_profile = "/usr/share/containers/seccomp.json"
no_new_privileges = true
EOF

echo "Container security configured"
