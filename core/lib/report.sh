#!/bin/bash
# PBP Report Generation Library

PBP_REPORT_DIR="${PBP_REPORT_DIR:-/var/log/pbp/reports}"

# Source logging if not already loaded
if ! declare -f log_info &>/dev/null; then
    PBP_ROOT="${PBP_ROOT:-/opt/pbp}"
    source "${PBP_ROOT}/core/lib/logging.sh"
fi

generate_report_id() {
    local type="$1"
    echo "${type}_$(date +%Y%m%d_%H%M%S)"
}

create_report() {
    local report_type="$1"
    local report_data="$2"
    
    local report_id=$(generate_report_id "$report_type")
    local json_path="${PBP_REPORT_DIR}/json/${report_id}.json"
    local html_path="${PBP_REPORT_DIR}/html/${report_id}.html"
    local checksum_path="${PBP_REPORT_DIR}/checksums/${report_id}.sha256"
    
    mkdir -p "${PBP_REPORT_DIR}"/{json,html,checksums}
    
    # Add metadata
    local report=$(jq -n \
        --arg id "$report_id" \
        --arg type "$report_type" \
        --arg ts "$(date -Iseconds)" \
        --argjson data "$report_data" \
        '{
            report_id: $id,
            type: $type,
            timestamp: $ts,
            data: $data
        }')
    
    echo "$report" > "$json_path"
    chmod 640 "$json_path"
    
    # Generate HTML report
    if [[ -f "${PBP_ROOT}/core/lib/html_report.sh" ]]; then
        source "${PBP_ROOT}/core/lib/html_report.sh"
        generate_html_report "$report" "$html_path"
        chmod 640 "$html_path"
    fi
    
    # Generate checksum
    sha256sum "$json_path" | awk '{print $1}' > "$checksum_path"
    chmod 640 "$checksum_path"
    
    log_info "Report created: ${report_id}"
    echo "$report_id"
}

get_report() {
    local report_id="$1"
    local json_path="${PBP_REPORT_DIR}/json/${report_id}.json"
    
    if [[ ! -f "$json_path" ]]; then
        log_error "Report not found: ${report_id}"
        return 1
    fi
    
    cat "$json_path"
}

list_reports() {
    local type="${1:-}"
    
    if [[ ! -d "${PBP_REPORT_DIR}/json" ]]; then
        return 0
    fi
    
    if [[ -n "$type" ]]; then
        find "${PBP_REPORT_DIR}/json" -name "${type}_*.json" -type f | \
            xargs -n1 basename | \
            sed 's/.json$//' | \
            sort -r
    else
        find "${PBP_REPORT_DIR}/json" -name "*.json" -type f | \
            xargs -n1 basename | \
            sed 's/.json$//' | \
            sort -r
    fi
}

verify_report() {
    local report_id="$1"
    local json_path="${PBP_REPORT_DIR}/json/${report_id}.json"
    local checksum_path="${PBP_REPORT_DIR}/checksums/${report_id}.sha256"
    
    if [[ ! -f "$json_path" || ! -f "$checksum_path" ]]; then
        return 1
    fi
    
    local expected=$(cat "$checksum_path")
    local actual=$(sha256sum "$json_path" | awk '{print $1}')
    
    [[ "$expected" == "$actual" ]]
}

calculate_risk_score() {
    local findings="$1"
    
    local critical=$(echo "$findings" | jq '[.[] | select(.severity == "CRITICAL")] | length')
    local high=$(echo "$findings" | jq '[.[] | select(.severity == "HIGH")] | length')
    local medium=$(echo "$findings" | jq '[.[] | select(.severity == "MEDIUM")] | length')
    local low=$(echo "$findings" | jq '[.[] | select(.severity == "LOW")] | length')
    
    echo $((critical * 10 + high * 5 + medium * 2 + low * 1))
}
