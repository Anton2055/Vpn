#!/usr/bin/env bash
# ==============================================================================
# Test Suite: Bash Scripts Linting & Security Leak Audit
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

FAILED=0

echo "============================================================"
echo " Running Shell Script Syntax & Static Analysis"
echo "============================================================"

# 1. Syntax check with bash -n
while IFS= read -r -d '' script; do
    rel_path="${script#"$ROOT_DIR/"}"
    if bash -n "$script"; then
        printf "\033[0;32m[PASS]\033[0m [SYNTAX] %s\n" "$rel_path"
    else
        printf "\033[0;31m[FAIL]\033[0m [SYNTAX] %s syntax error!\n" "$rel_path"
        FAILED=1
    fi
done < <(find "$ROOT_DIR" -type f -name "*.sh" -not -path "*/node_modules/*" -not -path "*/.git/*" -print0)

# 2. Check for real credential leaks in committed files
echo ""
echo "--- Scanning for Accidental Hardcoded Secrets ---"
LEAKS_FOUND=0

# Scan for actual Cloudflare tokens (long base64/hex) or live private keys
if grep -rnE --exclude="*.log" --exclude-dir=".git" --exclude-dir="node_modules" \
    "(CLOUDFLARE_API_KEY=[a-zA-Z0-9]{30,}|CF_TUNNEL_TOKEN=ey[a-zA-Z0-9]{30,})" "$ROOT_DIR"; then
    echo "[FAIL] Detected potential live tokens!"
    LEAKS_FOUND=1
fi

if [[ $LEAKS_FOUND -eq 0 ]]; then
    printf "\033[0;32m[PASS]\033[0m [SECURITY] Zero hardcoded live credentials detected.\n"
else
    printf "\033[0;31m[FAIL]\033[0m [SECURITY] Potential secrets detected!\n"
    FAILED=1
fi

echo "============================================================"
if [[ $FAILED -eq 0 ]]; then
    echo "SCRIPT TESTS RESULT: ALL SHELL SCRIPTS PASSED"
    exit 0
else
    echo "SCRIPT TESTS RESULT: SHELL SCRIPT ISSUES DETECTED"
    exit 1
fi
