#!/bin/bash
# state_manager.sh - Manages the enabled modules state using JSON
# Requires: jq

STATE_FILE="state/enabled.json"

init_state() {
    if [ ! -f "$STATE_FILE" ]; then
        echo "{}" > "$STATE_FILE"
    fi
}

save_state() {
    local module_name="$1"
    local enabled="$2" # true/false
    
    local tmp_file=$(mktemp)
    
    if [ "$enabled" = "true" ]; then
        jq --arg mod "$module_name" '.[$mod] = true' "$STATE_FILE" > "$tmp_file"
    else
        jq --arg mod "$module_name" 'del(.[$mod])' "$STATE_FILE" > "$tmp_file"
    fi
    
    mv "$tmp_file" "$STATE_FILE"
}

is_enabled() {
    local module_name="$1"
    
    if [ ! -f "$STATE_FILE" ]; then
        echo "false"
        return 0
    fi
    
    if jq -e --arg mod "$module_name" 'has($mod)' "$STATE_FILE" >/dev/null; then
        echo "true"
    else
        echo "false"
    fi
}
