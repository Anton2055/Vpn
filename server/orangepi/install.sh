#!/usr/bin/env bash
# ==============================================================================
# Mobile Network Resilience - Orange Pi PC Plus Production Installer
# SoC: Allwinner H3 (4x Cortex-A7 @ 1.2GHz, ARMv7 32-bit)
# RAM: 1GB DDR3 | Storage: 8GB eMMC
# ==============================================================================

set -euo pipefail

LOG_PREFIX="[OPI-INSTALLER]"
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $LOG_PREFIX $1"
}

# 1. Root Check
if [[ $EUID -ne 0 ]]; then
   echo "CRITICAL: This script must be run as root (use sudo)." >&2
   exit 1
fi

# 2. Strict ARMv7 Architecture Check
ARCH=$(uname -m)
if [[ "$ARCH" != "armv7l" && "$ARCH" != "armv7" ]]; then
    echo "CRITICAL: Architecture mismatch! Detected '$ARCH'." >&2
    echo "Orange Pi PC Plus Allwinner H3 requires ARMv7 32-bit (armv7l)." >&2
    echo "DO NOT attempt to install arm64 binaries on 32-bit ARMv7." >&2
    exit 1
fi
log "Verified 32-bit ARMv7 architecture ($ARCH)."

# 3. Prerequisites
log "Installing minimal dependencies..."
if command -v apt-get &>/dev/null; then
    apt-get update -y
    apt-get install -y curl unzip openssl
fi

# 4. Storage Wear Mitigation (eMMC Protection)
# Mount /var/log/xray into tmpfs (RAM) to eliminate flash cell wear
LOG_DIR="/var/log/xray"
CONFIG_DIR="/etc/xray"
INSTALL_DIR="/usr/local/bin"
SHARE_DIR="/usr/local/share/xray"
TMP_DIR="/tmp/xray-opi-$$"

mkdir -p "$LOG_DIR" "$CONFIG_DIR" "$INSTALL_DIR" "$SHARE_DIR" "$TMP_DIR"
chmod 700 "$CONFIG_DIR"

if ! grep -q "$LOG_DIR tmpfs" /etc/fstab; then
    log "Configuring tmpfs for $LOG_DIR in /etc/fstab to protect eMMC flash life..."
    echo "tmpfs $LOG_DIR tmpfs defaults,noatime,nosuid,nodev,noexec,mode=0755,size=16M 0 0" >> /etc/fstab
    mount "$LOG_DIR" || true
    log "Mounted $LOG_DIR as RAM-based tmpfs."
fi

# 5. Resolve Official ARMv7 32-bit Binary
log "Resolving latest official Xray-linux-arm32-v7a release..."
LATEST_TAG=""
DOWNLOAD_URL=""
if LATEST_TAG=$(curl -sL https://api.github.com/repos/XTLS/Xray-core/releases/latest | grep '"tag_name":' | head -n1 | cut -d '"' -f 4); then
    if [[ -n "$LATEST_TAG" ]]; then
        DOWNLOAD_URL="https://github.com/XTLS/Xray-core/releases/download/${LATEST_TAG}/Xray-linux-arm32-v7a.zip"
        log "Found latest ARMv7 release: $LATEST_TAG"
    fi
fi

if [[ -z "$DOWNLOAD_URL" ]]; then
    LATEST_TAG="v26.3.27"
    DOWNLOAD_URL="https://github.com/XTLS/Xray-core/releases/download/v26.3.27/Xray-linux-arm32-v7a.zip"
    log "Using pinned release fallback: $LATEST_TAG"
fi

log "Downloading $DOWNLOAD_URL..."
curl -sL "$DOWNLOAD_URL" -o "$TMP_DIR/xray-arm32.zip"

log "Extracting ARMv7 binary..."
unzip -q -o "$TMP_DIR/xray-arm32.zip" -d "$TMP_DIR"
install -m 755 "$TMP_DIR/xray" "$INSTALL_DIR/xray"
if [[ -f "$TMP_DIR/geoip.dat" ]]; then
    install -m 644 "$TMP_DIR/geoip.dat" "$SHARE_DIR/geoip.dat"
fi
if [[ -f "$TMP_DIR/geosite.dat" ]]; then
    install -m 644 "$TMP_DIR/geosite.dat" "$SHARE_DIR/geosite.dat"
fi
rm -rf "$TMP_DIR"

# 6. Deploy Low-Memory Configuration
CONFIG_FILE="$CONFIG_DIR/config.json"
if [[ ! -f "$CONFIG_FILE" ]]; then
    log "Deploying memory-tuned configuration template for Orange Pi..."
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    TEMPLATE_PATH="$SCRIPT_DIR/../../config/xray/config.orangepi.template.json"
    
    UUID=$("$INSTALL_DIR/xray" uuid)
    WS_PATH="/ws-$(openssl rand -hex 6)"
    XH_PATH="/xh-$(openssl rand -hex 6)"

    sed -e "s/00000000-0000-0000-0000-000000000000/$UUID/g" \
        -e "s|/stream-ws-change-me|$WS_PATH|g" \
        -e "s|/stream-xh-change-me|$XH_PATH|g" \
        "$TEMPLATE_PATH" > "$CONFIG_FILE"
    chmod 600 "$CONFIG_FILE"
    log "Generated low-overhead config at $CONFIG_FILE"
fi

# 7. Validate Syntax
log "Validating configuration syntax with ARMv7 binary..."
"$INSTALL_DIR/xray" -test -config "$CONFIG_FILE"

# 8. Install Systemd Service with Strict Memory Limits
# GOMEMLIMIT=256MiB prevents Go runtime from expanding heap beyond 256MB.
# GOGC=60 triggers GC more frequently to keep RSS compact on 1GB total RAM.
log "Installing memory-constrained systemd unit..."
cat <<EOF > /etc/systemd/system/xray.service
[Unit]
Description=Xray Anti-Censorship Service (Orange Pi ARMv7 Tuned)
Documentation=https://github.com/XTLS/Xray-core
After=network.target nss-lookup.target

[Service]
Type=simple
User=root
Environment="GOMEMLIMIT=256MiB"
Environment="GOGC=60"
Environment="XRAY_LOCATION_ASSET=$SHARE_DIR"
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true
ExecStart=$INSTALL_DIR/xray run -config $CONFIG_FILE
Restart=on-failure
RestartPreventExitStatus=23
MemoryHigh=300M
MemoryMax=384M
LimitNOFILE=16384

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable xray
systemctl restart xray
sleep 2

# 9. Verify
if systemctl is-active --quiet xray; then
    log "SUCCESS: Xray is active on Orange Pi PC Plus!"
    log "Memory controls: GOMEMLIMIT=256MiB, MemoryMax=384M"
    log "Logs isolated in tmpfs: $LOG_DIR"
else
    echo "ERROR: Service failed to start. Run: journalctl -u xray -n 30" >&2
    exit 1
fi
