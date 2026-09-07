#!/usr/bin/env bash
# ==============================================================================
# Mobile Network Resilience - Linux VPS Uninstaller
# ==============================================================================

set -euo pipefail

if [[ $EUID -ne 0 ]]; then
   echo "CRITICAL: This script must be run as root (use sudo)." >&2
   exit 1
fi

KEEP_DATA="${1:-false}"

echo "Stopping and disabling Xray systemd service..."
systemctl stop xray || true
systemctl disable xray || true
rm -f /etc/systemd/system/xray.service
systemctl daemon-reload

echo "Removing binaries..."
rm -f /usr/local/bin/xray
rm -rf /usr/local/share/xray

if [[ "$KEEP_DATA" != "true" && "$KEEP_DATA" != "--keep-data" ]]; then
    echo "Removing configurations and logs..."
    rm -rf /etc/xray
    rm -rf /var/log/xray
else
    echo "Preserved configuration in /etc/xray as requested."
fi

echo "Uninstallation complete."
