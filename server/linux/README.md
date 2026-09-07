# Linux VPS Deployment Guide

## 1. Overview

The Linux VPS deployment acts as the high-speed primary hub in this resilience architecture. Because a VPS features a static public IPv4 address and direct port 443 access, it hosts:
* **Profile A (Primary)**: VLESS + TCP + XTLS-Reality (Vision Flow) on Port 443. This bypasses CDN latency and provides direct line-rate performance.
* **Profile B1 & B2 (Fallback)**: WebSocket / XHTTP endpoints.
* **Profile C (Emergency)**: ZeroTier L3 mesh endpoint on Port 10808.

---

## 2. Quick Automated Install

On Debian 11/12 or Ubuntu 20.04/22.04/24.04:
```bash
sudo ./server/linux/install.sh
```

What the script executes:
1. Verifies 64-bit x86_64 architecture.
2. Downloads official `Xray-linux-64.zip` from official XTLS releases.
3. Generates cryptographically secure UUID, X25519 Reality keypair, and shortId.
4. Populates `/etc/xray/config.json` with direct Reality inbounds and local fallback inbounds.
5. Installs and enables the `xray.service` systemd unit.
6. Outputs the Android HAPP client URI for immediate clipboard import.

---

## 3. Maintenance Commands

* **Healthcheck**:
  ```bash
  sudo ./server/linux/healthcheck.sh
  ```
* **Safe Update with Automatic Rollback**:
  ```bash
  sudo ./server/linux/update.sh
  ```
* **Watchdog Execution (can be scheduled in cron every 2 minutes)**:
  ```bash
  sudo ./server/linux/watchdog.sh
  ```
* **Uninstallation**:
  ```bash
  sudo ./server/linux/uninstall.sh
  ```
