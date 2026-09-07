#!/usr/bin/env bash
# ==============================================================================
# Test Suite: Configuration Syntax & Xray Core Validation
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

FAILED=0

# Locate Xray binary
XRAY_BIN=""
if command -v xray &>/dev/null; then
    XRAY_BIN="xray"
elif [[ -x "/tmp/xray-test/xray" ]]; then
    XRAY_BIN="/tmp/xray-test/xray"
fi

if [[ -z "$XRAY_BIN" ]]; then
    echo "[TEST-CONFIG] WARNING: No xray executable found. Testing JSON syntax only."
fi

echo "============================================================"
echo " Running Xray Configuration Tests"
echo "============================================================"

check_config() {
    local file="$1"
    local name
    name=$(basename "$file")
    
    # 1. JSON Lint test
    if python3 -m json.tool "$file" >/dev/null 2>&1 || jq . "$file" >/dev/null 2>&1; then
        printf "\033[0;32m[PASS]\033[0m [JSON-SYNTAX] %s is valid JSON\n" "$name"
    else
        printf "\033[0;31m[FAIL]\033[0m [JSON-SYNTAX] %s has JSON syntax errors!\n" "$name"
        FAILED=1
        return
    fi

    # 2. Xray Core Validation test (if binary present and file is full config)
    if [[ -n "$XRAY_BIN" && "$name" != "routing.template.json" ]]; then
        if "$XRAY_BIN" -test -config "$file" &>/dev/null; then
            printf "\033[0;32m[PASS]\033[0m [XRAY-TEST]   %s passed xray -test -config\n" "$name"
        else
            printf "\033[0;31m[FAIL]\033[0m [XRAY-TEST]   %s failed xray -test -config!\n" "$name"
            FAILED=1
        fi
    fi
}

for cfg in "$ROOT_DIR"/config/xray/*.json; do
    check_config "$cfg"
done

echo "============================================================"
if [[ $FAILED -eq 0 ]]; then
    echo "CONFIG TESTS RESULT: ALL CONFIGURATIONS PASSED"
    exit 0
else
    echo "CONFIG TESTS RESULT: CONFIGURATION ERRORS DETECTED"
    exit 1
fi
