#!/usr/bin/env bash
# ==============================================================================
# Mobile Network Resilience - Orange Pi Memory & Thermal Guard
# Purpose: Guard against OOM (Out-of-Memory) killer and thermal throttling on 1GB RAM
# ==============================================================================

set -uo pipefail

MAX_XRAY_RSS_KB=320000     # 320 MB RSS threshold
MIN_AVAIL_MEM_KB=100000    # 100 MB available system RAM safety margin
LOG_FILE="/var/log/xray/memory-guard.log"

log() {
    local msg="$1"
    local ts
    ts=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$ts] $msg"
    if [[ -d "$(dirname "$LOG_FILE")" ]]; then
        echo "[$ts] $msg" >> "$LOG_FILE"
    fi
}

# 1. Inspect System Available Memory
AVAIL_MEM_KB=$(awk '/MemAvailable/ {print $2}' /proc/meminfo || echo 999999)

# 2. Inspect Xray Process RSS
XRAY_PID=$(pgrep -f "xray run" | head -n1 || echo "")

if [[ -z "$XRAY_PID" ]]; then
    exit 0
fi

XRAY_RSS_KB=$(awk '/VmRSS/ {print $2}' "/proc/$XRAY_PID/status" 2>/dev/null || echo 0)

# 3. Read Thermal Zone
THERM_TEMP="unknown"
if [[ -f /sys/devices/virtual/thermal/thermal_zone0/temp ]]; then
    RAW_T=$(cat /sys/devices/virtual/thermal/thermal_zone0/temp)
    if [[ "$RAW_T" -gt 1000 ]]; then
        THERM_TEMP="$((RAW_T / 1000))°C"
    else
        THERM_TEMP="${RAW_T}°C"
    fi
fi

# 4. Evaluate Thresholds
SHOULD_RESTART=0

if [[ "$XRAY_RSS_KB" -gt "$MAX_XRAY_RSS_KB" ]]; then
    log "WARN: Xray RSS ($((XRAY_RSS_KB / 1024)) MB) exceeded threshold ($((MAX_XRAY_RSS_KB / 1024)) MB). Thermal: $THERM_TEMP."
    SHOULD_RESTART=1
fi

if [[ "$AVAIL_MEM_KB" -lt "$MIN_AVAIL_MEM_KB" ]]; then
    log "WARN: Low system available memory ($((AVAIL_MEM_KB / 1024)) MB remaining). Thermal: $THERM_TEMP."
    SHOULD_RESTART=1
fi

if [[ "$SHOULD_RESTART" -eq 1 ]]; then
    log "ACTION: Performing proactive graceful restart of xray.service to prevent OOM crash..."
    systemctl restart xray
    log "ACTION: Restart command issued."
fi
