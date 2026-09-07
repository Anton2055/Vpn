#!/usr/bin/env bash
# ==============================================================================
# Master Test Runner: Mobile Network Resilience Project
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "============================================================"
echo "  Executing Full Test Suite"
echo "============================================================"

chmod +x "$SCRIPT_DIR"/*.sh

"$SCRIPT_DIR/test-config.sh"
echo ""
"$SCRIPT_DIR/test-scripts.sh"

echo ""
echo "============================================================"
echo "  MASTER TEST SUMMARY: ALL VALIDATIONS SUCCESSFUL"
echo "============================================================"
