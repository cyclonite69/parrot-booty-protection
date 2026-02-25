#!/bin/bash
# logger.sh - Central logging for the hardening framework

# LOG_FILE is the main system log
LOG_FILE="/var/log/hardenctl.log"

# MODULE_RUN_LOG is a temporary log file for a specific module's current execution
# It's set by hardenctl before sourcing a module.

log_message() {
    local level="$1"
    local msg="$2"
    local timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    local full_message="$timestamp [$level] $msg"
    
    echo "$full_message" | tee -a "$LOG_FILE"
    
    # If MODULE_RUN_LOG is set and not empty, append to it as well
    if [ -n "$MODULE_RUN_LOG" ]; then
        echo "$full_message" >> "$MODULE_RUN_LOG"
    fi
}

log_info() {
    log_message "INFO" "$1"
}

log_warn() {
    log_message "WARN" "$1"
}

log_error() {
    log_message "ERROR" "$1" >&2
}

log_step() {
    local msg="$1"
    echo "" | tee -a "$LOG_FILE"
    echo "=== $msg ===" | tee -a "$LOG_FILE"
    if [ -n "$MODULE_RUN_LOG" ]; then
        echo "" >> "$MODULE_RUN_LOG"
        echo "=== $msg ===" >> "$MODULE_RUN_LOG"
    fi
}
