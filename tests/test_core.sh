#!/bin/bash
# PBP Core Engine Test Suite

set -eo pipefail

PBP_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PBP_ROOT

# Use temporary directories for testing
export PBP_STATE_DIR="/tmp/pbp-test/state"
export PBP_LOG_DIR="/tmp/pbp-test/log"
export PBP_BACKUP_DIR="/tmp/pbp-test/backups"

# Setup test environment
setup_test_env() {
    rm -rf /tmp/pbp-test
    mkdir -p "$PBP_STATE_DIR" "$PBP_LOG_DIR" "$PBP_BACKUP_DIR"
}

# Cleanup test environment
cleanup_test_env() {
    rm -rf /tmp/pbp-test
}

# Test counter
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

test_assert() {
    local description="$1"
    local command="$2"
    
    ((TESTS_RUN++))
    
    set +e
    eval "$command" &>/dev/null
    local result=$?
    set -e
    
    if [[ $result -eq 0 ]]; then
        echo "✓ ${description}"
        ((TESTS_PASSED++))
        return 0
    else
        echo "✗ ${description}"
        ((TESTS_FAILED++))
        return 0  # Don't exit on test failure
    fi
}

# Test state management
test_state() {
    echo "=== Testing State Management ==="
    
    source "${PBP_ROOT}/core/state.sh"
    
    test_assert "Initialize state" "init_state"
    test_assert "State file created" "[[ -f ${PBP_STATE_DIR}/modules.state ]]"
    test_assert "Set module state" "set_module_state test_module enabled '{}'"
    test_assert "Get module status" "[[ \$(get_module_status test_module) == 'enabled' ]]"
    test_assert "List enabled modules" "list_enabled_modules | grep -q test_module"
    
    echo
}

# Test logging
test_logging() {
    echo "=== Testing Logging ==="
    
    source "${PBP_ROOT}/core/lib/logging.sh"
    
    test_assert "Ensure log directory" "ensure_log_dir"
    test_assert "Log info message" "log_info 'Test message'"
    test_assert "Log action" "log_action 'test' 'module' 'success' 'details'"
    test_assert "Audit log exists" "[[ -f ${PBP_LOG_DIR}/audit.log ]]"
    
    echo
}

# Test backup system
test_backup() {
    echo "=== Testing Backup System ==="
    
    source "${PBP_ROOT}/core/lib/backup.sh"
    
    # Create test file
    local test_file="/tmp/pbp-test-file"
    echo "test content" > "$test_file"
    
    test_assert "Create backup" "backup_id=\$(create_backup test_module $test_file)"
    test_assert "List backups" "list_backups test_module | grep -q ."
    test_assert "Verify backup" "verify_backup test_module \$(list_backups test_module | head -n1)"
    
    rm -f "$test_file"
    echo
}

# Test registry
test_registry() {
    echo "=== Testing Module Registry ==="
    
    source "${PBP_ROOT}/core/registry.sh"
    
    test_assert "List available modules" "list_available_modules | grep -q ."
    test_assert "Validate manifest" "validate_manifest ${PBP_ROOT}/modules/_template/manifest.json"
    test_assert "Get module manifest" "get_module_manifest _template | jq -e .name"
    
    echo
}

# Test validation
test_validation() {
    echo "=== Testing Validation ==="
    
    source "${PBP_ROOT}/core/lib/validation.sh"
    
    test_assert "Validate command (jq)" "validate_command jq"
    test_assert "Validate disk space" "validate_disk_space 1"
    
    echo
}

# Test report generation
test_reports() {
    echo "=== Testing Report Generation ==="
    
    source "${PBP_ROOT}/core/lib/report.sh"
    
    local test_data='{"test": "data"}'
    test_assert "Create report" "report_id=\$(create_report test '$test_data')"
    test_assert "Get report" "get_report \$(list_reports test | head -n1) | jq -e .report_id"
    test_assert "Verify report" "verify_report \$(list_reports test | head -n1)"
    
    echo
}

# Run all tests
main() {
    echo "PBP Core Engine Test Suite"
    echo "=========================="
    echo
    
    setup_test_env
    
    test_logging
    test_state
    test_backup
    test_registry
    test_validation
    test_reports
    
    cleanup_test_env
    
    echo "=========================="
    echo "Tests run: ${TESTS_RUN}"
    echo "Passed: ${TESTS_PASSED}"
    echo "Failed: ${TESTS_FAILED}"
    echo
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo "✓ All tests passed"
        exit 0
    else
        echo "✗ Some tests failed"
        exit 1
    fi
}

main "$@"
