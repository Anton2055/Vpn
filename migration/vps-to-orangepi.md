# Migration Guide: VPS / Windows to Orange Pi PC Plus

## 1. Executive Summary

This guide describes migrating the Xray node to an **Orange Pi PC Plus** (Allwinner H3, 1GB DDR3 RAM, 8GB eMMC). 

### Operational Goals:
* **Zero Power Overhead**: 2.5W–4W typical power consumption (compared to 60W–150W for a desktop PC).
* **Silent 24/7 Operation**: Fanless, quiet residential operation.
* **Cost Efficiency**: Eliminates monthly VPS hosting costs while maintaining high residential IP trust scores.

---

## 2. Hardware Preparation Checklist

- [ ] Orange Pi PC Plus running **Armbian (Debian/Ubuntu for Sun8i/H3)**.
- [ ] Stable 5V / 2A or 5V / 3A DC barrel jack power supply (do not power via micro-USB OTG due to voltage drops).
- [ ] Adhesive copper/aluminum heatsink affixed to Allwinner H3 SoC.
- [ ] Wired Ethernet connected (1000M / GbE supported on PC Plus).

---

## 3. Step-by-Step Migration Process

### Step 1: Install Armbian on eMMC
1. Flash Armbian image to MicroSD card.
2. Boot Orange Pi and complete initial setup.
3. Run `armbian-install` to transfer system from SD card to the internal 8GB eMMC flash for maximum I/O speed.
4. Reboot and remove MicroSD card.

### Step 2: Architecture Verification
Ensure the system is operating in 32-bit ARM mode:
```bash
uname -m
# Expected output: armv7l
```

### Step 3: Run Orange Pi Installer & Tuner
Clone repository and execute:
```bash
git clone https://github.com/your-username/mobile-resilience-xray.git /opt/mobile-resilience
cd /opt/mobile-resilience

# Run hardware & kernel tuning (ZRAM, swappiness, dirty ratios)
sudo ./server/orangepi/tuning.sh

# Run ARMv7 installer (tmpfs logging, GOMEMLIMIT=256MiB, armv7 binary)
sudo ./server/orangepi/install.sh
```

### Step 4: Transfer Cloudflare Tunnel to Orange Pi
You can either run `cloudflared` directly on the Orange Pi, or leave `cloudflared` on another local machine pointing to Orange Pi's LAN IP:

1. Install `cloudflared` ARM32 binary on Orange Pi:
   ```bash
   curl -sL https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm -o /usr/local/bin/cloudflared
   chmod +x /usr/local/bin/cloudflared
   ```
2. Copy your tunnel credentials JSON file from Windows/VPS to `/etc/cloudflared/credentials.json`.
3. Update `config.yml` ingress rules to point to `http://127.0.0.1:8080` (WebSocket) and `http://127.0.0.1:8081` (XHTTP).
4. Start `cloudflared` service:
   ```bash
   cloudflared service install
   systemctl start cloudflared
   ```

### Step 5: Enable Orange Pi Memory Guard
Add `memory-guard.sh` to root crontab to run every 5 minutes:
```bash
(crontab -l 2>/dev/null; echo "*/5 * * * * /opt/mobile-resilience/server/orangepi/memory-guard.sh >/dev/null 2>&1") | crontab -
```

---

## 4. Operational Monitoring
* **Monitor RAM**: `free -h` (ZRAM swap should show 512M).
* **Monitor Thermals**:
  ```bash
  watch -n 2 'cat /sys/devices/virtual/thermal/thermal_zone0/temp'
  ```
* **Verify HAPP**: In HAPP, tap the latency indicator for Profile B1. Latency should be within 5–10ms of the previous Windows host.
