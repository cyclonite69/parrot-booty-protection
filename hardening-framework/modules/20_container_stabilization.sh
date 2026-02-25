#!/bin/bash
# 20_container_stabilization.sh - Container Runtime Stabilization
# DESCRIPTION: Configures Podman as Docker CLI backend, ensures rootless networking.
# DEPENDENCIES: podman, docker-compose-plugin

MODULE_NAME="container_stabilization"
MODULE_DESC="Container Runtime (Podman/Docker CLI) Stabilization"
MODULE_VERSION="1.0"
PLUGIN_DIR="/usr/libexec/docker/cli-plugins"
USER_HOME="/home/${SUDO_USER:-$USER}"

install() {
    log_info "Stabilizing Container Runtime (Podman -> Docker CLI)..."
    
    # 1. Install Podman and Docker CLI compatibility
    apt-get update -q
    DEBIAN_FRONTEND=noninteractive apt-get install -y podman podman-docker docker-compose-plugin

    # 2. Enable Lingering for Rootless Containers
    if [ -n "${SUDO_USER:-}" ]; then
        log_info "Enabling linger for user: ${SUDO_USER}"
        loginctl enable-linger "${SUDO_USER}"
    fi

    # 3. Suppress Emulation Warning
    mkdir -p /etc/containers/nodocker
    touch /etc/containers/nodocker/nodocker

    # 4. Migrate Podman System
    # Must be run as the target user, tricky if we are root.
    if [ -n "${SUDO_USER:-}" ]; then
        log_info "Migrating Podman system for user: ${SUDO_USER}..."
        su - "${SUDO_USER}" -c "podman system migrate" || true
    fi

    # 5. Ensure Docker socket is available (rootless)
    if [ -n "${SUDO_USER:-}" ]; then
        log_info "Enabling podman.socket user service..."
        su - "${SUDO_USER}" -c "systemctl --user enable --now podman.socket" || true
        # Symlink docker.sock if needed? podman-docker usually handles this via update-alternatives or socket activation
    fi

    if verify; then
        log_info "Container runtime stabilized."
        return 0
    else
        log_error "Container runtime verification failed."
        rollback
        return 1
    fi
}

status() {
    # Check if podman-docker is installed
    if dpkg -l | grep -q "podman-docker"; then
        echo "active"
    else
        echo "inactive"
    fi
}

verify() {
    if ! command -v docker >/dev/null; then
        return 1
    fi
    
    # Try running hello-world (dry-run style, check version)
    if docker --version >/dev/null; then
        return 0
    fi
    return 1
}

rollback() {
    log_info "Reverting container stabilization settings..."
    rm /etc/containers/nodocker/nodocker 2>/dev/null
    rmdir /etc/containers/nodocker 2>/dev/null
    
    # We leave packages installed to avoid breaking user workflows.
    log_info "Emulation warning restored. Packages left intact."
}
