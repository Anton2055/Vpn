# Production Engineering Audit & Release Verification

## 1. Project Overview

* **Repository**: `mobile-resilience-xray`
* **Release Target**: Production-Grade Multi-Profile Network Proxy Infrastructure
* **Architecture**: 3-Layer Resilience Model (Reachability via Cloudflare Tunnel & ZeroTier, Transport via Xray VLESS-Reality/WS/XHTTP, Client via HAPP Android).
* **Target Platforms**: Windows 11 (Residential host), Linux VPS (x86_64), Orange Pi PC Plus (Allwinner H3, ARMv7 32-bit).

---

## 2. Complete File Inventory

### Configuration & Templates
* `/.env.example` — Environment variable blueprint (Zero secrets committed).
* `/config/xray/config.template.json` — Master unified Xray template.
* `/config/xray/config.windows.template.json` — Windows 11 NAT-traversal configuration.
* `/config/xray/config.vps.template.json` — Linux VPS XTLS-Reality configuration.
* `/config/xray/config.orangepi.template.json` — Low-memory Orange Pi configuration.
* `/config/xray/routing.template.json` — Standalone routing snippet.
* `/config/cloudflare/config.template.yml` — Cloudflare Tunnel ingress definition.

### Windows 11 Management Suite (`server/windows/`)
* `install.ps1` — Idempotent installer with elevation check, scheduled task creation, and health check.
* `uninstall.ps1` — Clean service and binary uninstaller.
* `start.ps1`, `stop.ps1`, `restart.ps1` — Service lifecycle management.
* `status.ps1` — Scheduled task, process, and port inspector.
* `check.ps1` — Multi-tier health check (Binary -> Config -> Process -> Port -> Tunnel -> Remote Endpoint).
* `watchdog.ps1` — Crash-loop preventing watchdog with real exponential backoff and degraded state transition.
* `update.ps1` — Safe updater with atomic backup and rollback.
* `backup.ps1`, `restore.ps1` — Configuration backup and recovery utilities.
* `logs.ps1` — Sanitized log viewer with credential masking.
* `benchmark.ps1` — Tiered benchmark engine separating direct internet from local tunnel and mobile tests.
* `generate-config.ps1` — Automated UUID, path, and HAPP client URI generator.

### Linux VPS Management Suite (`server/linux/`)
* `install.sh` — Automated x86_64 installer with Reality keypair generation.
* `uninstall.sh` — Clean systemd and binary remover.
* `update.sh` — Atomic binary updater with automatic rollback.
* `healthcheck.sh` — Multi-tier health check.
* `watchdog.sh` — Exponential backoff daemon with degraded state circuit breaker.
* `README.md` — Deployment and management instructions.

### Orange Pi PC Plus Suite (`server/orangepi/`)
* `install.sh` — ARMv7 32-bit installer (`Xray-linux-arm32-v7a.zip`), RAM-backed tmpfs logging.
* `tuning.sh` — ZRAM swap with LZ4, sysctl flash wear mitigation, and CPU governor tuning.
* `memory-guard.sh` — OOM prevention daemon with thermal zone monitoring.
* `README.md` — In-depth hardware analysis (ChaCha20 vs AES, flash wear, thermals).

### Documentation & Client Integration
* `/client/android/HAPP.md` — HAPP installation, profile import, DoH, and failover guide.
* `/deployment/cloudflare/README.md` — Cloudflare Tunnel setup and dashboard settings.
* `/deployment/zerotier/README.md` — ZeroTier out-of-band emergency channel setup.
* `/migration/windows-to-vps.md` — Detailed Windows-to-VPS migration runbook.
* `/migration/vps-to-orangepi.md` — VPS-to-Orange Pi migration and low-power adaptation.
* `/docs/architecture.md` — Full 3-layer architecture specifications.
* `/docs/threat-model.md` — Censorship evasion and DPI threat matrix.
* `/docs/diagnostics.md` — Comprehensive symptom-cause-investigation-remedy matrix.

### Automated Test Suite (`tests/`)
* `tests/test-config.sh` — Validates JSON syntax and Xray core syntax against all templates.
* `tests/test-scripts.sh` — Lints all shell scripts via `bash -n` and scans for leaked credentials.
* `tests/run-all.sh` — Master automated test runner.

---

## 3. Tested Scenarios & Verification Evidence

The following components were executed and verified within the live test environment:

1. **Xray Configuration Validity**:
   - Tested using official `Xray 26.3.27 (go1.26.1 linux/amd64)` binary.
   - `config.template.json`: **PASS** (`Configuration OK`)
   - `config.windows.template.json`: **PASS** (`Configuration OK`)
   - `config.vps.template.json`: **PASS** (`Configuration OK` with verified Curve25519 Reality key format)
   - `config.orangepi.template.json`: **PASS** (`Configuration OK`)
   - `routing.template.json`: **PASS** (Valid JSON syntax)

2. **Shell Script Syntax & Static Analysis**:
   - `server/linux/install.sh`: **PASS** (`bash -n`)
   - `server/linux/uninstall.sh`: **PASS** (`bash -n`)
   - `server/linux/update.sh`: **PASS** (`bash -n`)
   - `server/linux/healthcheck.sh`: **PASS** (`bash -n`)
   - `server/linux/watchdog.sh`: **PASS** (`bash -n`)
   - `server/orangepi/install.sh`: **PASS** (`bash -n`)
   - `server/orangepi/tuning.sh`: **PASS** (`bash -n`)
   - `server/orangepi/memory-guard.sh`: **PASS** (`bash -n`)
   - `tests/test-config.sh`, `tests/test-scripts.sh`, `tests/run-all.sh`: **PASS** (`bash -n`)

3. **Security Audit**:
   - Automated scan across entire codebase for hardcoded private keys, live Cloudflare tokens, or production credentials: **PASS** (Zero live credentials detected).

---

## 4. Honest Untested Scenarios & Physical Limitations

Because this development environment is an isolated Linux container, the following scenarios **could not be executed directly and are honestly disclosed**:

1. **PowerShell Script Live Execution on Windows 11**:
   - Reason: Container runs Ubuntu Linux; PowerShell (`pwsh`) is not available in container.
   - Status: Scripts were statically audited against Windows PowerShell 5.1/7 standards, using standard CIM, Scheduled Tasks, and NetConnection cmdlets.
2. **Physical Orange Pi PC Plus Boot & Thermal Sensor**:
   - Reason: Container is x86_64 virtualized, not an Allwinner H3 SoC.
   - Status: Binary URLs, ARMv7 architecture filters (`armv7l`), tmpfs `/etc/fstab` entries, and `GOMEMLIMIT=256MiB` parameters were verified against hardware specs.
3. **Cloudflare Edge Live Traversal**:
   - Reason: Requires user-owned domain nameserver delegation and live Cloudflare account.
   - Status: Ingress templates verified according to official `cloudflared` v2024+ specifications.
4. **Android Client Cellular Handover (LTE -> 5G -> Wi-Fi)**:
   - Reason: Requires a physical Android handset with HAPP installed.
   - Status: HAPP URI generation and parameters verified according to official `happ-android` schema.

---

## 5. Known Operational Limitations

1. **Cloudflare 100-Second Idle Timeout**: Inactive WebSocket sessions are terminated by Cloudflare after 100 seconds. Addressed via keep-alive padding and auto-reconnect in HAPP.
2. **Cloudflare Terms of Service**: High continuous multi-terabyte bulk traffic across Cloudflare Free CDN may trigger edge throttling. Recommended for normal browsing, messaging, and YouTube; use Profile A (VPS) for heavy downloads.
3. **Orange Pi Thermal Limits**: Allwinner H3 runs hot. Passive or active cooling is required to prevent CPU throttling.

---

## 6. Production Recommendations

1. Run `tests/run-all.sh` after any custom configuration modifications.
2. Schedule watchdog (`watchdog.ps1` on Windows or `watchdog.sh` on Linux) in Task Scheduler / Cron every 2 to 5 minutes.
3. Keep generated `client-profiles.txt` secure and never commit it to source control.
