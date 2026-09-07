# Mobile Network Resilience (Xray + Cloudflare Tunnel + ZeroTier)

[![Test Suite](https://img.shields.io/badge/tests-passing-brightgreen.svg)](#testing-and-verification)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Security Policy](https://img.shields.io/badge/Security-Audited-blue.svg)](SECURITY.md)

Production-grade proxy infrastructure engineered for high stability, carrier-grade censorship resistance, and zero-port-forwarding NAT traversal. Designed for **Android HAPP** clients connecting to **Windows 11**, with automated migration runbooks for **Linux VPS** and **Orange Pi PC Plus (ARMv7 32-bit)**.

---

## 1. Core Architecture: The 3-Layer Resilience Model

```text
+-------------------------------------------------------------------------+
|                  LAYER C: CLIENT INTERFACE (Android HAPP)               |
|   uTLS Chrome Fingerprinting | DNS-over-HTTPS | Smart Fallback Toggles  |
+------------------------------------+------------------------------------+
                                     |
                +--------------------+--------------------+
                |                                         |
+---------------+-------------------+     +---------------+---------------+
|  LAYER B: DATA TRANSPORT (Xray)   |     |  LAYER A: REACHABILITY (Mesh) |
|  - Profile A: VLESS-Reality (TCP) |     |  - Cloudflare Tunnel (QUIC)   |
|  - Profile B1: VLESS-WS (HTTPS)   |     |  - ZeroTier L3 Encrypted Mesh |
|  - Profile B2: VLESS-XHTTP (H2)   |     |                               |
+---------------+-------------------+     +---------------+---------------+
                |                                         |
+---------------+-----------------------------------------+---------------+
|                 PHYSICAL SERVER RUNTIMES & PLATFORMS                    |
|   Windows 11 (Home NAT) | Linux VPS (Public IP) | Orange Pi PC Plus     |
+-------------------------------------------------------------------------+
```

### Profile Transport Matrix

| Profile | Protocol & Security | Transport & Port | Primary Target Host | Use Case |
| :--- | :--- | :--- | :--- | :--- |
| **Profile A** | VLESS + XTLS-Reality (Vision) | Direct TCP on Port 443 | Linux VPS (Public IPv4) | **Primary High-Speed**: Zero-overhead direct connection, mimics Microsoft TLS 1.3 |
| **Profile B1** | VLESS (No Decryption) | WebSocket + TLS via Cloudflare | Windows 11 / Orange Pi | **Residential NAT**: Bypasses CGNAT/firewalls without port forwarding |
| **Profile B2** | VLESS (No Decryption) | XHTTP (`packet-up`) via Cloudflare | Windows 11 / Orange Pi | **Stealth CDN**: Bypasses WebSocket DPI filters |
| **Profile C** | VLESS (Unencrypted) | TCP on Port 10808 over ZeroTier | Any host running ZeroTier | **Emergency Out-of-Band**: P2P mesh channel when CDN domains are blocked |

---

## 2. Quick Start Guides

### A. Windows 11 Deployment (Residential Host behind NAT)
1. Open PowerShell **as Administrator**.
2. Clone this repository and run the automated installer:
   ```powershell
   git clone https://github.com/your-username/mobile-resilience-xray.git
   cd mobile-resilience-xray\server\windows
   .\install.ps1
   ```
3. Generate runtime client profiles:
   ```powershell
   .\generate-config.ps1 -Domain "tunnel.yourdomain.com"
   ```
4. Setup Cloudflare Tunnel following [`deployment/cloudflare/README.md`](deployment/cloudflare/README.md).

### B. Linux VPS Deployment (Direct Public IP)
1. SSH into your VPS as `root`.
2. Run the automated installer:
   ```bash
   git clone https://github.com/your-username/mobile-resilience-xray.git /opt/mobile-resilience
   cd /opt/mobile-resilience
   sudo ./server/linux/install.sh
   ```
3. The script automatically installs official binaries, generates X25519 Reality keys, configures systemd, and outputs your HAPP import URI.

### C. Orange Pi PC Plus Deployment (ARMv7 32-bit Allwinner H3)
1. Boot Armbian on your Orange Pi PC Plus.
2. Run hardware tuning and installer:
   ```bash
   cd /opt/mobile-resilience
   sudo ./server/orangepi/tuning.sh
   sudo ./server/orangepi/install.sh
   ```
   *Features: ZRAM swap with LZ4, tmpfs in-RAM logging (saves eMMC flash), and Go runtime memory constraints (`GOMEMLIMIT=256MiB`).*

---

## 3. Android Client Setup (HAPP)

1. Download **HAPP** (`happ-android`) from official releases.
2. Copy the generated `vless://` URI string from your server.
3. In HAPP, tap **`+`** -> **"Import from Clipboard"**.
4. Configure DNS to **Cloudflare DoH** (`https://1.1.1.1/dns-query`) to prevent ISP DNS poisoning.
5. Refer to [`client/android/HAPP.md`](client/android/HAPP.md) for full configuration details.

---

## 4. Repository Structure

```text
├── .env.example                     # Environment blueprint
├── config/
│   ├── xray/
│   │   ├── config.template.json     # Master unified Xray template
│   │   ├── config.windows.template.json # Windows 11 inbounds
│   │   ├── config.vps.template.json # VPS VLESS-Reality inbounds
│   │   ├── config.orangepi.template.json # Low-memory ARMv7 inbounds
│   │   └── routing.template.json    # Standard routing rules
│   └── cloudflare/
│       └── config.template.yml      # cloudflared ingress rules
├── server/
│   ├── windows/                     # Windows 11 PowerShell 5.1/7 Suite
│   │   ├── install.ps1, uninstall.ps1, start.ps1, stop.ps1, restart.ps1
│   │   ├── status.ps1, check.ps1, watchdog.ps1, update.ps1
│   │   ├── backup.ps1, restore.ps1, logs.ps1, benchmark.ps1, generate-config.ps1
│   ├── linux/                       # Linux VPS (x86_64) Suite
│   │   ├── install.sh, uninstall.sh, update.sh, healthcheck.sh, watchdog.sh
│   │   └── README.md
│   └── orangepi/                    # Orange Pi PC Plus (ARMv7 32-bit) Suite
│       ├── install.sh, tuning.sh, memory-guard.sh
│       └── README.md
├── client/android/
│   └── HAPP.md                      # Comprehensive HAPP client guide
├── deployment/
│   ├── cloudflare/README.md         # Cloudflare Tunnel guide
│   └── zerotier/README.md           # ZeroTier mesh guide
├── migration/
│   ├── windows-to-vps.md            # Windows to VPS migration runbook
│   └── vps-to-orangepi.md           # VPS to Orange Pi migration runbook
├── docs/
│   ├── architecture.md              # 3-Layer resilience architecture
│   ├── threat-model.md              # DPI & Censorship threat matrix
│   ├── diagnostics.md               # Symptom-cause-remedy matrix
│   └── final-audit.md               # Production audit and verified tests
└── tests/
    ├── test-config.sh               # Xray core config validation
    ├── test-scripts.sh              # Shell script linting and leak audits
    └── run-all.sh                   # Master test runner
```

---

## 5. Testing & Verification

Run the automated test suite to validate all templates and scripts:
```bash
./tests/run-all.sh
```

All templates are validated against official Xray-core syntax (`xray -test -config`). See [`docs/final-audit.md`](docs/final-audit.md) for full test records.

---

## 6. Security & Disclosure

* Never commit `.env`, `credentials.json`, `config.json`, or live `vless://` strings to public repositories.
* Report security issues following our [Security Policy](SECURITY.md).
* Licensed under the [MIT License](LICENSE).
