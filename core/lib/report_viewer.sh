#!/bin/bash
# Report Viewer

PBP_ROOT="${PBP_ROOT:-/opt/pbp}"
source "${PBP_ROOT}/core/lib/report.sh"

view_report() {
    local report_id="$1"
    local format="${2:-json}"
    
    case "$format" in
        json)
            local json_path="${PBP_REPORT_DIR}/json/${report_id}.json"
            if [[ -f "$json_path" ]]; then
                jq '.' "$json_path"
            else
                echo "Report not found: ${report_id}"
                return 1
            fi
            ;;
        html)
            local html_path="${PBP_REPORT_DIR}/html/${report_id}.html"
            if [[ -f "$html_path" ]]; then
                if command -v xdg-open &>/dev/null; then
                    xdg-open "$html_path"
                else
                    echo "HTML report: ${html_path}"
                    echo "Open in browser to view"
                fi
            else
                echo "HTML report not found: ${report_id}"
                return 1
            fi
            ;;
        summary)
            local json_path="${PBP_REPORT_DIR}/json/${report_id}.json"
            if [[ ! -f "$json_path" ]]; then
                echo "Report not found: ${report_id}"
                return 1
            fi
            
            local report=$(cat "$json_path")
            local timestamp=$(echo "$report" | jq -r '.timestamp')
            local type=$(echo "$report" | jq -r '.type')
            
            echo "Report: ${report_id}"
            echo "Time: ${timestamp}"
            echo "Type: ${type}"
            echo
            
            # Show module summaries
            echo "$report" | jq -r '.data | to_entries[] | 
                "Module: \(.key)\n  Risk Score: \(.value.risk_score // 0)\n  Findings: \(.value.findings | length)\n"'
            ;;
    esac
}

list_reports_interactive() {
    local reports=$(list_reports | head -20)
    
    if [[ -z "$reports" ]]; then
        echo "No reports found"
        return 0
    fi
    
    echo "Recent Reports:"
    echo "==============="
    echo
    
    local i=1
    for report_id in $reports; do
        local json_path="${PBP_REPORT_DIR}/json/${report_id}.json"
        local timestamp=$(jq -r '.timestamp' "$json_path" 2>/dev/null || echo "unknown")
        local risk=$(jq -r '.data | to_entries | map(.value.risk_score // 0) | add' "$json_path" 2>/dev/null || echo "0")
        
        printf "%2d. %s (Risk: %s) - %s\n" "$i" "$report_id" "$risk" "$timestamp"
        ((i++))
    done
}

compare_reports() {
    local report1="$1"
    local report2="$2"
    
    local json1="${PBP_REPORT_DIR}/json/${report1}.json"
    local json2="${PBP_REPORT_DIR}/json/${report2}.json"
    
    if [[ ! -f "$json1" || ! -f "$json2" ]]; then
        echo "One or both reports not found"
        return 1
    fi
    
    echo "Comparing Reports"
    echo "================="
    echo "Baseline: ${report1}"
    echo "Current:  ${report2}"
    echo
    
    # Compare risk scores
    local risk1=$(jq -r '.data | to_entries | map(.value.risk_score // 0) | add' "$json1")
    local risk2=$(jq -r '.data | to_entries | map(.value.risk_score // 0) | add' "$json2")
    local risk_delta=$((risk2 - risk1))
    
    echo "Risk Score Change: ${risk1} → ${risk2} (${risk_delta:+${risk_delta}})"
    echo
    
    # Compare findings count
    local findings1=$(jq -r '.data | to_entries | map(.value.findings | length) | add' "$json1")
    local findings2=$(jq -r '.data | to_entries | map(.value.findings | length) | add' "$json2")
    
    echo "Findings: ${findings1} → ${findings2}"
    echo
    
    # Module-by-module comparison
    echo "Module Changes:"
    jq -r '.data | keys[]' "$json1" | while read module; do
        local mod_risk1=$(jq -r ".data.${module}.risk_score // 0" "$json1")
        local mod_risk2=$(jq -r ".data.${module}.risk_score // 0" "$json2")
        local delta=$((mod_risk2 - mod_risk1))
        
        if [[ $delta -ne 0 ]]; then
            printf "  %s: %s → %s (%+d)\n" "$module" "$mod_risk1" "$mod_risk2" "$delta"
        fi
    done
}
