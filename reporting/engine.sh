#!/bin/bash
# PBP Universal Reporting Engine
set -euo pipefail

PBP_ROOT="${PBP_ROOT:-/opt/pbp}"
REPORT_ROOT="/var/log/pbp/reports"

source "${PBP_ROOT}/core/lib/logging.sh"

# Generate unique report ID
generate_report_id() {
    echo "$(date +%Y%m%d_%H%M%S)_$(hostname -s)"
}

# Create report directory structure
init_report_dir() {
    local report_id="$1"
    local report_dir="${REPORT_ROOT}/${report_id}"
    
    mkdir -p "${report_dir}"/{raw,json,html,pdf,checksums}
    chmod 700 "${report_dir}"
    
    echo "$report_dir"
}

# Parse scanner output to normalized JSON
parse_scanner_output() {
    local scanner="$1"
    local raw_file="$2"
    local output_file="$3"
    
    local parser="${PBP_ROOT}/reporting/parsers/${scanner}.sh"
    
    if [[ ! -x "$parser" ]]; then
        log_error "Parser not found: $scanner"
        return 1
    fi
    
    # Execute parser with input validation
    if ! bash "$parser" "$raw_file" > "$output_file" 2>/dev/null; then
        log_error "Parser failed: $scanner"
        return 1
    fi
    
    # Validate output is valid JSON
    if ! jq empty "$output_file" 2>/dev/null; then
        log_error "Parser produced invalid JSON: $scanner"
        return 1
    fi
    
    return 0
}

# Generate HTML from JSON using template
generate_html() {
    local json_file="$1"
    local html_file="$2"
    local template="${PBP_ROOT}/reporting/templates/report.html.j2"
    
    # Use Python for Jinja2 templating (safer than bash string manipulation)
    python3 - "$json_file" "$html_file" "$template" << 'PYTHON'
import sys
import json
from jinja2 import Template
import html

json_file, html_file, template_file = sys.argv[1:4]

# Load data
with open(json_file) as f:
    data = json.load(f)

# Load template
with open(template_file) as f:
    template = Template(f.read())

# Escape all user-controlled data
def escape_recursive(obj):
    if isinstance(obj, dict):
        return {k: escape_recursive(v) for k, v in obj.items()}
    elif isinstance(obj, list):
        return [escape_recursive(item) for item in obj]
    elif isinstance(obj, str):
        return html.escape(obj)
    return obj

data = escape_recursive(data)

# Render
output = template.render(**data)

# Write
with open(html_file, 'w') as f:
    f.write(output)
PYTHON
}

# Generate PDF from HTML
generate_pdf() {
    local html_file="$1"
    local pdf_file="$2"
    
    # Use wkhtmltopdf with security options
    if ! wkhtmltopdf \
        --enable-local-file-access \
        --no-background \
        --print-media-type \
        --disable-javascript \
        --disable-external-links \
        "$html_file" "$pdf_file" 2>/dev/null; then
        log_error "PDF generation failed"
        return 1
    fi
    
    chmod 600 "$pdf_file"
    return 0
}

# Generate integrity hash
generate_checksum() {
    local file="$1"
    local checksum_file="$2"
    
    sha256sum "$file" | awk '{print $1}' > "$checksum_file"
    chmod 600 "$checksum_file"
}

# Main report generation function
generate_report() {
    local scanner="$1"
    local raw_output="$2"
    
    local report_id=$(generate_report_id)
    local report_dir=$(init_report_dir "$report_id")
    
    log_info "Generating report: $report_id for scanner: $scanner"
    
    # Save raw output
    local raw_file="${report_dir}/raw/${scanner}.txt"
    cp "$raw_output" "$raw_file"
    chmod 600 "$raw_file"
    
    # Parse to JSON
    local json_file="${report_dir}/json/${scanner}.json"
    if ! parse_scanner_output "$scanner" "$raw_file" "$json_file"; then
        log_error "Failed to parse scanner output"
        return 1
    fi
    
    # Generate HTML
    local html_file="${report_dir}/html/${scanner}.html"
    if ! generate_html "$json_file" "$html_file"; then
        log_error "Failed to generate HTML"
        return 1
    fi
    
    # Generate PDF
    local pdf_file="${report_dir}/pdf/${scanner}.pdf"
    if ! generate_pdf "$html_file" "$pdf_file"; then
        log_error "Failed to generate PDF"
        return 1
    fi
    
    # Generate checksums
    generate_checksum "$json_file" "${report_dir}/checksums/${scanner}.json.sha256"
    generate_checksum "$pdf_file" "${report_dir}/checksums/${scanner}.pdf.sha256"
    
    # Make report immutable
    chattr +i "$json_file" "$pdf_file" 2>/dev/null || true
    
    log_info "Report generated: ${report_dir}"
    echo "$report_id"
}

# CLI interface
main() {
    local scanner="${1:-}"
    local raw_output="${2:-}"
    
    if [[ -z "$scanner" || -z "$raw_output" ]]; then
        echo "Usage: pbp-report <scanner> <raw_output_file>"
        echo "Scanners: rkhunter, chkrootkit, lynis, nmap, nftables, sysctl, container, aws"
        exit 1
    fi
    
    if [[ ! -f "$raw_output" ]]; then
        log_error "Raw output file not found: $raw_output"
        exit 1
    fi
    
    generate_report "$scanner" "$raw_output"
}

main "$@"
