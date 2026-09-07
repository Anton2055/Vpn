#!/usr/bin/env bash
# ==============================================================================
# Mobile Network Resilience - Linux VPS Production Installer
# Architecture: x86_64 / AMD64 | Systemd | VLESS-Reality + WS + ZeroTier
# ==============================================================================

set -euo pipefail

LOG_PREFIX="[XRAY-INSTALLER]"
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $LOG_PREFIX $1"
}

# 1. Root Check
if [[ $EUID -ne 0 ]]; then
   echo "CRITICAL: This script must be run as root (use sudo)." >&2
   exit 1
fi

# 2. Architecture Check
ARCH=$(uname -m)
if [[ "$ARCH" != "x86_64" && "$ARCH" != "amd64" ]]; then
    echo "CRITICAL: Unsupported architecture ($ARCH). server/linux/install.sh is for x86_64." >&2
    echo "For Orange Pi PC Plus (ARMv7 32-bit), use server/orangepi/install.sh." >&2
    exit 1
fi

# 3. Prerequisites Installation
log "Checking and installing required utilities..."
if command -v apt-get &>/dev/null; then
    apt-get update -y
    apt-get install -y curl unzip openssl systemd
elif command -v yum &>/dev/null; then
    yum install -y curl unzip openssl systemd
elif command -v apk &>/dev/null; then
    apk add --no-cache curl unzip openssl
fi

# 4. Resolve Version & Download
INSTALL_DIR="/usr/local/bin"
SHARE_DIR="/usr/local/share/xray"
CONFIG_DIR="/etc/xray"
LOG_DIR="/var/log/xray"
TMP_DIR="/tmp/xray-install-$$"

mkdir -p "$INSTALL_DIR" "$SHARE_DIR" "$CONFIG_DIR" "$LOG_DIR" "$TMP_DIR"
chmod 700 "$CONFIG_DIR"
chmod 750 "$LOG_DIR"

log "Resolving latest official Xray release..."
LATEST_TAG=""
DOWNLOAD_URL=""
if LATEST_TAG=$(curl -sL https://api.github.com/repos/XTLS/Xray-core/releases/latest | grep '"tag_name":' | head -n1 | cut -d '"' -f 4); then
    if [[ -n "$LATEST_TAG" ]]; then
        DOWNLOAD_URL="https://github.com/XTLS/Xray-core/releases/download/${LATEST_TAG}/Xray-linux-64.zip"
        log "Found latest release: $LATEST_TAG"
    fi
fi

if [[ -z "$DOWNLOAD_URL" ]]; then
    LATEST_TAG="v26.3.27"
    DOWNLOAD_URL="https://github.com/XTLS/Xray-core/releases/download/v26.3.27/Xray-linux-64.zip"
    log "Using pinned release fallback: $LATEST_TAG"
fi

log "Downloading $DOWNLOAD_URL..."
curl -sL "$DOWNLOAD_URL" -o "$TMP_DIR/xray.zip"

log "Extracting binaries..."
unzip -q -o "$TMP_DIR/xray.zip" -d "$TMP_DIR"
install -m 755 "$TMP_DIR/xray" "$INSTALL_DIR/xray"
if [[ -f "$TMP_DIR/geoip.dat" ]]; then
    install -m 644 "$TMP_DIR/geoip.dat" "$SHARE_DIR/geoip.dat"
fi
if [[ -f "$TMP_DIR/geosite.dat" ]]; then
    install -m 644 "$TMP_DIR/geosite.dat" "$SHARE_DIR/geosite.dat"
fi
rm -rf "$TMP_DIR"

# 5. Configuration Generation
CONFIG_FILE="$CONFIG_DIR/config.json"
if [[ ! -f "$CONFIG_FILE" ]]; then
    log "Generating new runtime configuration with XTLS-Reality keys..."
    
    # Generate UUID
    UUID=$("$INSTALL_DIR/xray" uuid)
    
    # Generate Reality Keypair
    KEY_PAIR=$("$INSTALL_DIR/xray" x25519)
    PRIVATE_KEY=$(echo "$KEY_PAIR" | grep "PrivateKey:" | awk '{print $2}')
    PUBLIC_KEY=$(echo "$KEY_PAIR" | grep "Password (PublicKey):" | awk '{print $3}')
    SHORT_ID=$(openssl rand -hex 8)
    
    WS_PATH="/ws-$(openssl rand -hex 6)"
    XH_PATH="/xh-$(openssl rand -hex 6)"

    # Detect public IP
    SERVER_IP=$(curl -s4 https://api.ipify.org || curl -s4 https://icanhazip.com || echo "YOUR_VPS_IP")

    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    TEMPLATE_PATH="$SCRIPT_DIR/../../config/xray/config.vps.template.json"

    if [[ -f "$TEMPLATE_PATH" ]]; then
        sed -e "s/00000000-0000-0000-0000-000000000000/$UUID/g" \
            -e "s|KAmeXXb2EJylPb883GEFxn6JNizVpYQ-P6mlF8zIn2I|$PRIVATE_KEY|g" \
            -e "s/0123456789abcdef/$SHORT_ID/g" \
            -e "s|/stream-ws-change-me|$WS_PATH|g" \
            -e "s|/stream-xh-change-me|$XH_PATH|g" \
            "$TEMPLATE_PATH" > "$CONFIG_FILE"
        chmod 600 "$CONFIG_FILE"
        log "Configuration generated at $CONFIG_FILE"
    else
        echo "CRITICAL: Template file not found at $TEMPLATE_PATH" >&2
        exit 1
    fi

    # Save credentials for operator
    CLIENT_PROFILE_FILE="$CONFIG_DIR/client-profiles.txt"
    cat <<EOF > "$CLIENT_PROFILE_FILE"
# ==============================================================================
# HAPP ANDROID CLIENT PROFILES (KEEP SECURE)
# Generated: $(date)
# ==============================================================================

# Profile A: Primary High-Speed Transport (Direct VLESS-Reality on port 443)
vless://${UUID}@${SERVER_IP}:443?security=reality&encryption=none&pbk=${PUBLIC_KEY}&headerType=none&fp=chrome&type=tcp&flow=xtls-rprx-vision&sni=www.microsoft.com&sid=${SHORT_ID}#Profile-A-Reality-VPS

# Profile C: ZeroTier Out-of-Band (Connect to same ZeroTier Network first)
vless://${UUID}@10.147.17.1:10808?security=none&encryption=none&type=tcp#Profile-C-ZeroTier-Emergency
EOF
    chmod 600 "$CLIENT_PROFILE_FILE"
else
    log "Existing configuration preserved at $CONFIG_FILE"
fi

# 6. Validate Configuration
log "Testing configuration syntax..."
"$INSTALL_DIR/xray" -test -config "$CONFIG_FILE"

# 7. Install Systemd Service
log "Configuring systemd service..."
cat <<EOF > /etc/systemd/system/xray.service
[Unit]
Description=Xray Anti-Censorship Service
Documentation=https://github.com/XTLS/Xray-core
After=network.target nss-lookup.target

[Service]
Type=simple
User=root
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true
ExecStart=$INSTALL_DIR/xray run -config $CONFIG_FILE
Restart=on-failure
RestartPreventExitStatus=23
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable xray
systemctl restart xray
sleep 2

# 8. Verification
if systemctl is-active --quiet xray; then
    log "SUCCESS: Xray service is active and running!"
    if [[ -f "$CONFIG_DIR/client-profiles.txt" ]]; then
        echo ""
        echo "============================================================"
        echo "HAPP CLIENT IMPORT URI (Profile A - Primary Reality):"
        grep "^vless://" "$CONFIG_DIR/client-profiles.txt" | head -n1
        echo "============================================================"
        echo "Full profiles stored in: $CONFIG_DIR/client-profiles.txt"
    fi
else
    echo "ERROR: Service failed to start. Inspect logs: journalctl -u xray -n 30" >&2
    exit 1
fi
