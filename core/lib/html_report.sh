#!/bin/bash
# HTML Report Generator

generate_html_report() {
    local json_report="$1"
    local output_file="$2"
    
    local report_id=$(echo "$json_report" | jq -r '.report_id')
    local timestamp=$(echo "$json_report" | jq -r '.timestamp')
    local report_type=$(echo "$json_report" | jq -r '.type')
    local overall_risk=$(echo "$json_report" | jq -r '.data.risk_score // 0')
    
    # Determine risk level
    local risk_class="secure"
    local risk_label="SECURE"
    if [[ $overall_risk -gt 100 ]]; then
        risk_class="critical"
        risk_label="CRITICAL"
    elif [[ $overall_risk -gt 50 ]]; then
        risk_class="elevated"
        risk_label="ELEVATED"
    elif [[ $overall_risk -gt 20 ]]; then
        risk_class="moderate"
        risk_label="MODERATE"
    fi
    
    cat > "$output_file" << EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>PBP Security Report - ${report_id}</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: 'Courier New', monospace; background: #0a0e27; color: #e0e0e0; padding: 20px; }
        .container { max-width: 1200px; margin: 0 auto; }
        .header { background: linear-gradient(135deg, #1a1f3a 0%, #2d3561 100%); padding: 30px; border-radius: 8px; margin-bottom: 20px; border: 2px solid #3d4785; }
        .header h1 { color: #00ff88; font-size: 2em; margin-bottom: 10px; }
        .header .meta { color: #888; font-size: 0.9em; }
        .risk-badge { display: inline-block; padding: 10px 20px; border-radius: 5px; font-weight: bold; font-size: 1.2em; margin: 15px 0; }
        .risk-badge.secure { background: #00ff88; color: #0a0e27; }
        .risk-badge.moderate { background: #ffa500; color: #0a0e27; }
        .risk-badge.elevated { background: #ff6b35; color: #fff; }
        .risk-badge.critical { background: #ff0055; color: #fff; }
        .section { background: #1a1f3a; padding: 20px; margin-bottom: 20px; border-radius: 8px; border: 1px solid #2d3561; }
        .section h2 { color: #00d4ff; margin-bottom: 15px; border-bottom: 2px solid #2d3561; padding-bottom: 10px; }
        .finding { background: #0f1329; padding: 15px; margin-bottom: 10px; border-radius: 5px; border-left: 4px solid #666; }
        .finding.critical { border-left-color: #ff0055; }
        .finding.high { border-left-color: #ff6b35; }
        .finding.medium { border-left-color: #ffa500; }
        .finding.low { border-left-color: #00ff88; }
        .finding-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 10px; }
        .finding-title { color: #fff; font-weight: bold; font-size: 1.1em; }
        .severity { padding: 3px 10px; border-radius: 3px; font-size: 0.8em; font-weight: bold; }
        .severity.critical { background: #ff0055; color: #fff; }
        .severity.high { background: #ff6b35; color: #fff; }
        .severity.medium { background: #ffa500; color: #0a0e27; }
        .severity.low { background: #00ff88; color: #0a0e27; }
        .finding-desc { color: #aaa; margin-bottom: 10px; }
        .finding-remedy { color: #00d4ff; font-style: italic; }
        .stats { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 15px; }
        .stat-card { background: #0f1329; padding: 15px; border-radius: 5px; text-align: center; border: 1px solid #2d3561; }
        .stat-value { font-size: 2em; color: #00ff88; font-weight: bold; }
        .stat-label { color: #888; font-size: 0.9em; margin-top: 5px; }
        .footer { text-align: center; color: #666; margin-top: 30px; padding: 20px; border-top: 1px solid #2d3561; }
        .no-findings { color: #00ff88; text-align: center; padding: 20px; font-size: 1.1em; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🏴‍☠️ Parrot Booty Protection</h1>
            <div class="meta">
                Report ID: ${report_id}<br>
                Generated: ${timestamp}<br>
                Type: ${report_type}
            </div>
            <div class="risk-badge ${risk_class}">
                Risk Level: ${risk_label} (${overall_risk})
            </div>
        </div>
EOF

    # Add module-specific sections
    local modules=$(echo "$json_report" | jq -r '.data | keys[]' 2>/dev/null || echo "")
    
    if [[ -n "$modules" ]]; then
        for module in $modules; do
            local module_data=$(echo "$json_report" | jq -c ".data.${module}" 2>/dev/null)
            [[ "$module_data" == "null" ]] && continue
            
            local findings=$(echo "$module_data" | jq -c '.findings // []')
            local finding_count=$(echo "$findings" | jq 'length')
            local module_risk=$(echo "$module_data" | jq -r '.risk_score // 0')
            
            cat >> "$output_file" << EOF
        <div class="section">
            <h2>📦 ${module^^} Module</h2>
            <div class="stats">
                <div class="stat-card">
                    <div class="stat-value">${finding_count}</div>
                    <div class="stat-label">Findings</div>
                </div>
                <div class="stat-card">
                    <div class="stat-value">${module_risk}</div>
                    <div class="stat-label">Risk Score</div>
                </div>
            </div>
EOF
            
            if [[ $finding_count -gt 0 ]]; then
                echo "$findings" | jq -c '.[]' | while read -r finding; do
                    local id=$(echo "$finding" | jq -r '.id')
                    local severity=$(echo "$finding" | jq -r '.severity' | tr '[:upper:]' '[:lower:]')
                    local title=$(echo "$finding" | jq -r '.title')
                    local desc=$(echo "$finding" | jq -r '.description')
                    local remedy=$(echo "$finding" | jq -r '.remediation')
                    
                    cat >> "$output_file" << EOF
            <div class="finding ${severity}">
                <div class="finding-header">
                    <span class="finding-title">${title}</span>
                    <span class="severity ${severity}">${severity^^}</span>
                </div>
                <div class="finding-desc">${desc}</div>
                <div class="finding-remedy">💡 ${remedy}</div>
            </div>
EOF
                done
            else
                echo '            <div class="no-findings">✓ No security issues detected</div>' >> "$output_file"
            fi
            
            echo "        </div>" >> "$output_file"
        done
    fi
    
    cat >> "$output_file" << EOF
        <div class="footer">
            Generated by Parrot Booty Protection v1.0.0<br>
            Report checksum: $(sha256sum "$json_report" 2>/dev/null | awk '{print $1}')
        </div>
    </div>
</body>
</html>
EOF
}
