#!/usr/bin/env bash
# ==============================================================================
# Mobile Network Resilience - Linux Safe Updater with Rollback
# ==============================================================================

set -euo pipefail

if [[ $EUID -ne 0 ]]; then
   echo "CRITICAL: This script must be run as root." >&2
   exit 1
fi

INSTALL_DIR="/usr/local/bin"
CONFIG_FILE="/etc/xray/config.json"
BACKUP_DIR="/etc/xray/backups"
TMP_DIR="/tmp/xray-update-$$"

mkdir -p "$BACKUP_DIR" "$TMP_DIR"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [XRAY-UPDATE] $1"
}

# 1. Resolve Target Version
LATEST_TAG=$(curl -sL https://api.github.com/repos/XTLS/Xray-core/releases/latest | grep '"tag_name":' | head -n1 | cut -d '"' -f 4 || echo "v26.3.27")
if [[ -z "$LATEST_TAG" ]]; then LATEST_TAG="v26.3.27"; fi

DOWNLOAD_URL="https://github.com/XTLS/Xray-core/releases/download/${LATEST_TAG}/Xray-linux-64.zip"
log "Target version: $LATEST_TAG"

# 2. Download and Extract to Temp Sandbox
log "Downloading update package..."
curl -sL "$DOWNLOAD_URL" -o "$TMP_DIR/xray.zip"
unzip -q "$TMP_DIR/xray.zip" -d "$TMP_DIR"

if [[ ! -f "$TMP_DIR/xray" ]]; then
    echo "ERROR: Downloaded archive is corrupt. Aborting." >&2
    rm -rf "$TMP_DIR"
    exit 1
fi

# 3. Create Backup of Current Binary
TIMESTAMP=$(date '+%Y%m%d-%H%M%S')
CURRENT_BACKUP="$BACKUP_DIR/xray-$TIMESTAMP"
log "Backing up current binary to $CURRENT_BACKUP..."
cp "$INSTALL_DIR/xray" "$CURRENT_BACKUP"

rollback() {
    log "CRITICAL: Upgrade failed healthcheck! Rolling back to previous binary..."
    cp "$CURRENT_BACKUP" "$INSTALL_DIR/xray"
    systemctl restart xray
    if systemctl is-active --quiet xray; then
        log "Rollback SUCCESSFUL. Previous version is running."
    else
        log "CRITICAL: Rollback failed to restore service. Immediate operator check needed!"
    fi
}

# 4. Apply New Binary & Validate Configuration
log "Installing new binary..."
install -m 755 "$TMP_DIR/xray" "$INSTALL_DIR/xray"

log "Validating configuration with new binary..."
if ! "$INSTALL_DIR/xray" -test -config "$CONFIG_FILE"; then
    log "ERROR: New binary failed configuration test!"
    rollback
    rm -rf "$TMP_DIR"
    exit 1
fi

# 5. Restart Service & Health Check
log "Restarting service..."
systemctl restart xray
sleep 3

if systemctl is-active --quiet xray; then
    log "Health check PASSED: Service is active."
    rm -rf "$TMP_DIR"
    
    # Prune older backups (keep last 3)
    ls -t "$BACKUP_DIR"/xray-* 2>/dev/null | tail -n +4 | xargs -r rm -f
    log "Update to $LATEST_TAG completed successfully!"
else
    log "ERROR: Service crashed or failed to activate after update."
    rollback
    rm -rf "$TMP_DIR"
    exit 1
fi
