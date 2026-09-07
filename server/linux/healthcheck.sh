#!/usr/bin/env bash
# ==============================================================================
# Mobile Network Resilience - Linux Multi-Tier Healthcheck
# Levels: Binary -> Config -> Process -> Local Ports -> ZeroTier/Tunnel
# ==============================================================================

set -uo pipefail

FAILED=0

report() {
    local tier="$1"
    local name="$2"
    local status="$3"
    local details="$4"
    if [[ "$status" -eq 0 ]]; then
        printf "\033[0;32m[PASS]\033[0m [%-16s] %-30s: %s\n" "$tier" "$name" "$details"
    else
        printf "\033[0;31m[FAIL]\033[0m [%-16s] %-30s: %s\n" "$tier" "$name" "$details"
        FAILED=1
    fi
}

echo "============================================================"
echo " Running Linux Multi-Tier Healthcheck"
echo "============================================================"

# Level 1: Binary Check
if [[ -x "/usr/local/bin/xray" ]]; then
    VER=$(/usr/local/bin/xray version 2>&1 | head -n1)
    report "LEVEL 1: BINARY" "xray binary" 0 "$VER"
else
    report "LEVEL 1: BINARY" "xray binary" 1 "Missing or not executable at /usr/local/bin/xray"
fi

# Level 2: Configuration Syntax
if [[ -f "/etc/xray/config.json" ]]; then
    if /usr/local/bin/xray -test -config /etc/xray/config.json &>/dev/null; then
        report "LEVEL 2: CONFIG" "config.json" 0 "Syntax valid"
    else
        report "LEVEL 2: CONFIG" "config.json" 1 "Configuration validation failed"
    fi
else
    report "LEVEL 2: CONFIG" "config.json" 1 "/etc/xray/config.json missing"
fi

# Level 3: Process Execution (systemd)
if command -v systemctl &>/dev/null && systemctl is-active --quiet xray; then
    PID=$(pgrep -f "xray run" | head -n1 || echo "unknown")
    report "LEVEL 3: PROCESS" "xray systemd" 0 "Active (PID: $PID)"
elif pgrep -x "xray" &>/dev/null; then
    report "LEVEL 3: PROCESS" "xray daemon" 0 "Running outside systemd"
else
    report "LEVEL 3: PROCESS" "xray process" 1 "Process NOT running"
fi

# Level 4: Port Bindings
check_port() {
    local port="$1"
    local desc="$2"
    if command -v ss &>/dev/null; then
        if ss -tulpn | grep -q ":$port "; then
            report "LEVEL 4: PORT" "$desc" 0 "Port $port listening"
        else
            report "LEVEL 4: PORT" "$desc" 1 "Port $port NOT listening"
        fi
    elif command -v netstat &>/dev/null; then
        if netstat -tulpn | grep -q ":$port "; then
            report "LEVEL 4: PORT" "$desc" 0 "Port $port listening"
        else
            report "LEVEL 4: PORT" "$desc" 1 "Port $port NOT listening"
        fi
    else
        # Fallback to /dev/tcp test
        if (echo > /dev/tcp/127.0.0.1/"$port") &>/dev/null; then
            report "LEVEL 4: PORT" "$desc" 0 "Port $port reachable"
        else
            report "LEVEL 4: PORT" "$desc" 1 "Port $port unreachable"
        fi
    fi
}

check_port 443 "Reality Inbound (443)"
check_port 8080 "WebSocket Inbound (8080)"
check_port 8081 "XHTTP Inbound (8081)"
check_port 10808 "ZeroTier Inbound (10808)"

# Level 5: Out-of-band Mesh (ZeroTier)
if command -v zerotier-cli &>/dev/null; then
    if zerotier-cli info &>/dev/null; then
        ZT_STATUS=$(zerotier-cli info | awk '{print $5}')
        report "LEVEL 5: MESH" "ZeroTier Node" 0 "Status: $ZT_STATUS"
    else
        report "LEVEL 5: MESH" "ZeroTier Node" 1 "Daemon not responding"
    fi
else
    report "LEVEL 5: MESH" "ZeroTier Node" 0 "Not installed on this host (optional)"
fi

echo "============================================================"
if [[ $FAILED -eq 0 ]]; then
    echo "HEALTHCHECK RESULT: ALL TIERS OPERATIONAL"
    exit 0
else
    echo "HEALTHCHECK RESULT: ONE OR MORE TIERS DEGRADED"
    exit 1
fi
