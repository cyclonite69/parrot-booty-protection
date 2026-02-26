#!/bin/bash
# run.sh for container module
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
REPORT_DIR="/opt/parrot-booty-protection/reports/container"
mkdir -p "$REPORT_DIR"

echo "Auditing Podman environment..."

{
    echo "--- Container Security Audit: $TIMESTAMP ---"
    
    echo -e "
[Rootless Mode Check]"
    if [ "$EUID" -ne 0 ]; then
        echo "PASS: Running in rootless mode."
    else
        echo "WARN: Module executed as root. Audit may be skewed."
    fi

    echo -e "
[Active Containers]"
    podman ps --format "table {{.ID}} {{.Image}} {{.Status}}" || echo "No containers running."

    echo -e "
[Privileged Container Check]"
    PRIV=$(podman ps --filter "privileged=true" --format "{{.ID}}")
    if [ -z "$PRIV" ]; then
        echo "PASS: No privileged containers found."
    else
        echo "FAIL: Privileged containers detected: $PRIV"
    fi

    echo -e "
[Sensitive Mount Check]"
    MOUNTS=$(podman ps --format "{{.ID}}" | xargs -I {} podman inspect {} --format '{{ range .Mounts }}{{ .Source }}{{ end }}' 2>/dev/null | grep -E "^/etc|^/root|^/dev" || true)
    if [ -z "$MOUNTS" ]; then
        echo "PASS: No sensitive host mounts found."
    else
        echo "WARN: Sensitive host paths mounted: $MOUNTS"
    fi

} > "$REPORT_DIR/container_audit_$TIMESTAMP.txt"

echo "Container audit complete."
