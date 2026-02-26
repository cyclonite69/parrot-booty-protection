#!/bin/bash
# Simple PBP Core Validation

PBP_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PBP_ROOT
export PBP_STATE_DIR="/tmp/pbp-validate/state"
export PBP_LOG_DIR="/tmp/pbp-validate/log"
export PBP_BACKUP_DIR="/tmp/pbp-validate/backups"
export PBP_REPORT_DIR="/tmp/pbp-validate/reports"

echo "PBP Core Engine Validation"
echo "==========================="
echo

# Setup
rm -rf /tmp/pbp-validate
mkdir -p "$PBP_STATE_DIR" "$PBP_LOG_DIR" "$PBP_BACKUP_DIR"

# Test 1: Logging
echo -n "Testing logging... "
source "${PBP_ROOT}/core/lib/logging.sh"
ensure_log_dir
log_info "Test message"
if [[ -f "${PBP_LOG_DIR}/audit.log" ]]; then
    echo "✓"
else
    echo "✗"
    exit 1
fi

# Test 2: State management
echo -n "Testing state management... "
source "${PBP_ROOT}/core/state.sh"
init_state
set_module_state "test" "enabled" '{}'
if [[ "$(get_module_status test)" == "enabled" ]]; then
    echo "✓"
else
    echo "✗"
    exit 1
fi

# Test 3: Module registry
echo -n "Testing module registry... "
source "${PBP_ROOT}/core/registry.sh"
if validate_manifest "${PBP_ROOT}/modules/_template/manifest.json"; then
    echo "✓"
else
    echo "✗"
    exit 1
fi

# Test 4: Backup system
echo -n "Testing backup system... "
source "${PBP_ROOT}/core/lib/backup.sh"
echo "test" > /tmp/pbp-test-file
backup_id=$(create_backup "test" /tmp/pbp-test-file)
if verify_backup "test" "$backup_id"; then
    echo "✓"
else
    echo "✗"
    exit 1
fi

# Test 5: Report generation
echo -n "Testing report generation... "
source "${PBP_ROOT}/core/lib/report.sh"
report_id=$(create_report "test" '{"data": "test"}')
if verify_report "$report_id"; then
    echo "✓"
else
    echo "✗"
    exit 1
fi

# Cleanup
rm -rf /tmp/pbp-validate /tmp/pbp-test-file

echo
echo "✓ All core components validated successfully"
