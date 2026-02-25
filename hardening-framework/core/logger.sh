#!/bin/bash
# logger.sh - Central logging for the hardening framework

LOG_FILE="/var/log/hardenctl.log"

log_info() {
    local msg="$1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] $msg" | tee -a "$LOG_FILE"
}

log_warn() {
    local msg="$1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [WARN] $msg" | tee -a "$LOG_FILE"
}

log_error() {
    local msg="$1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [ERROR] $msg" | tee -a "$LOG_FILE" >&2
}

log_step() {
    local msg="$1"
    echo "" | tee -a "$LOG_FILE"
    echo "=== $msg ===" | tee -a "$LOG_FILE"
}
