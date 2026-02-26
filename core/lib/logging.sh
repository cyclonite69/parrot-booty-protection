#!/bin/bash
# PBP Logging Library

PBP_LOG_DIR="${PBP_LOG_DIR:-/var/log/pbp}"
PBP_AUDIT_LOG="${PBP_LOG_DIR}/audit.log"

log_level() {
    local level="$1"
    local message="$2"
    local timestamp=$(date -Iseconds)
    local caller="${BASH_SOURCE[2]##*/}:${BASH_LINENO[1]}"
    
    local log_msg="[${timestamp}] [${level}] [${caller}] ${message}"
    
    # Try to write to log file if writable, otherwise just stderr
    if [[ -w "${PBP_AUDIT_LOG}" ]] || [[ ! -e "${PBP_AUDIT_LOG}" && -w "${PBP_LOG_DIR}" ]]; then
        echo "${log_msg}" | tee -a "${PBP_AUDIT_LOG}" >&2
    else
        echo "${log_msg}" >&2
    fi
    
    if [[ "${level}" == "ERROR" || "${level}" == "CRITICAL" ]]; then
        logger -t pbp -p user.err "${level}: ${message}" 2>/dev/null || true
    fi
}

log_info() { log_level "INFO" "$1"; }
log_warn() { log_level "WARN" "$1"; }
log_error() { log_level "ERROR" "$1"; }
log_critical() { log_level "CRITICAL" "$1"; }

log_action() {
    local action="$1"
    local module="$2"
    local result="$3"
    local details="${4:-}"
    
    local entry=$(jq -n \
        --arg ts "$(date -Iseconds)" \
        --arg act "$action" \
        --arg mod "$module" \
        --arg res "$result" \
        --arg det "$details" \
        --arg user "$USER" \
        '{timestamp: $ts, action: $act, module: $mod, result: $res, details: $det, user: $user}')
    
    echo "$entry" >> "${PBP_LOG_DIR}/actions.jsonl"
    log_info "Action: ${action} ${module} -> ${result}"
}

ensure_log_dir() {
    mkdir -p "${PBP_LOG_DIR}"/{reports/{json,html,checksums},modules}
    chmod 750 "${PBP_LOG_DIR}"
    touch "${PBP_AUDIT_LOG}" "${PBP_LOG_DIR}/actions.jsonl"
    chmod 640 "${PBP_AUDIT_LOG}" "${PBP_LOG_DIR}/actions.jsonl"
}
