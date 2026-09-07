#!/usr/bin/env bash
# ==============================================================================
# Mobile Network Resilience - Orange Pi PC Plus Kernel & Hardware Tuning
# Target: Allwinner H3 SoC, 1GB RAM, eMMC Life Extension, ZRAM, Thermals
# ==============================================================================

set -euo pipefail

if [[ $EUID -ne 0 ]]; then
   echo "CRITICAL: This script must be run as root (use sudo)." >&2
   exit 1
fi

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [OPI-TUNING] $1"
}

log "Starting hardware and OS optimization for Orange Pi PC Plus..."

# 1. ZRAM Swap Configuration with LZ4
# On a 1GB device, 512MB of compressed ZRAM provides effective memory expansion without eMMC wear.
if command -v apt-get &>/dev/null; then
    log "Ensuring zram-tools / zram-config is installed..."
    apt-get install -y zram-tools || true
fi

if [[ -f /etc/default/zramswap ]]; then
    log "Configuring zramswap with LZ4 compression algorithm..."
    sed -i 's/^#*ALGO=.*/ALGO=lz4/' /etc/default/zramswap
    sed -i 's/^#*PERCENT=.*/PERCENT=50/' /etc/default/zramswap
    systemctl restart zramswap || true
fi

# 2. Virtual Memory & Storage Wear Mitigation (Sysctl)
SYSCTL_CONF="/etc/sysctl.d/99-orangepi-resilience.conf"
log "Applying kernel memory and disk sync tuning to $SYSCTL_CONF..."

cat <<EOF > "$SYSCTL_CONF"
# Prefer zram swap over dropping filesystem cached pages
vm.swappiness = 60
vm.vfs_cache_pressure = 50

# Delay dirty page flushes to aggregate flash writes (eMMC life extension)
vm.dirty_background_ratio = 5
vm.dirty_ratio = 15

# Network buffer limits appropriate for 1GB RAM
net.core.rmem_default = 262144
net.core.wmem_default = 262144
net.core.rmem_max = 2097152
net.core.wmem_max = 2097152
net.ipv4.tcp_rmem = 4096 87380 2097152
net.ipv4.tcp_wmem = 4096 65536 2097152

# Fast socket recycling
net.ipv4.tcp_fin_timeout = 20
net.ipv4.tcp_keepalive_time = 300
net.ipv4.tcp_keepalive_probes = 5
net.ipv4.tcp_keepalive_intvl = 15
EOF

sysctl -p "$SYSCTL_CONF" || true

# 3. CPU Governor & Thermal Check
# Allwinner H3 runs hot under heavy cryptographic load.
# Ensure 'ondemand' governor is set so CPU throttles back when idle.
if [[ -d /sys/devices/system/cpu/cpu0/cpufreq ]]; then
    for gov in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
        if [[ -f "$gov" ]]; then
            echo "ondemand" > "$gov" || true
        fi
    done
    log "Configured CPU scaling governor to 'ondemand'."
fi

# 4. Read Current Thermal Zone
TEMP_FILE="/sys/devices/virtual/thermal/thermal_zone0/temp"
if [[ -f "$TEMP_FILE" ]]; then
    RAW_TEMP=$(cat "$TEMP_FILE")
    # Temperature on Allwinner H3 is in millidegrees C or degrees C depending on kernel
    if [[ "$RAW_TEMP" -gt 1000 ]]; then
        CELSIUS=$((RAW_TEMP / 1000))
    else
        CELSIUS="$RAW_TEMP"
    fi
    log "Current SoC Temperature: ${CELSIUS}°C"
    if [[ "$CELSIUS" -gt 75 ]]; then
        log "WARNING: H3 temperature is high (${CELSIUS}°C). Ensure heatsink is attached!"
    fi
fi

log "Orange Pi PC Plus tuning completed successfully."
