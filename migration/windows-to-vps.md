# Migration Guide: Windows 11 to Linux VPS

## 1. Executive Summary

This guide details the technical procedure for migrating the Xray server from a residential Windows 11 host (behind NAT via Cloudflare Tunnel) to a dedicated Linux VPS (with a static public IPv4 address and direct port 443 access).

### Migration Benefits:
* **Latency Reduction**: Profile A (Direct VLESS-Reality on port 443) eliminates Cloudflare Edge reverse-proxy overhead (saving 30–80 ms round-trip).
* **Uncapped Throughput**: Eliminates Cloudflare's WebSocket framing limits and 100-second idle timeouts.
* **Autonomous Uptime**: VPS runs 24/7 without Windows Update auto-reboots or sleep mode interruptions.

---

## 2. Pre-Migration Checklist

- [ ] Linux VPS provisioned (Debian 11/12 or Ubuntu 22.04/24.04 recommended).
- [ ] Root SSH access established.
- [ ] Static Public IPv4 address confirmed (`curl -4 icanhazip.com`).
- [ ] Port 443 TCP/UDP open in cloud firewall / security groups (AWS, Hetzner, DigitalOcean).
- [ ] Client UUID from Windows host retrieved (`$env:ProgramData\Xray\config\config.json`).

---

## 3. Step-by-Step Migration Process

### Step 1: Export Credentials from Windows 11
On Windows 11 (PowerShell):
```powershell
$config = Get-Content "$env:ProgramData\Xray\config\config.json" | ConvertFrom-Json
$clientUuid = $config.inbounds[0].settings.clients[0].id
Write-Host "Current Client UUID: $clientUuid"
```
*Tip: Reusing the same UUID allows you to keep the same client identities across profiles in HAPP.*

### Step 2: Install Xray on Linux VPS
SSH into your VPS and run:
```bash
git clone https://github.com/your-username/mobile-resilience-xray.git /opt/mobile-resilience
cd /opt/mobile-resilience
sudo ./server/linux/install.sh
```
The installer automatically:
1. Installs the official 64-bit Linux binary.
2. Generates X25519 Reality keypairs and shortIds.
3. Sets up systemd service with security hardening.

### Step 3: Align Client UUID (Optional)
If you wish to preserve the exact same UUID as Windows:
```bash
sudo sed -i 's/"id": "[^"]*"/"id": "YOUR-WINDOWS-UUID"/g' /etc/xray/config.json
sudo systemctl restart xray
```

### Step 4: Verify Direct Reality Inbound
Run the multi-tier healthcheck:
```bash
sudo /opt/mobile-resilience/server/linux/healthcheck.sh
```
Confirm that `xray` is listening on `0.0.0.0:443`.

### Step 5: Update HAPP Android Client
1. Retrieve the newly generated Profile A URI from `/etc/xray/client-profiles.txt`.
2. In HAPP, add the new server configuration as **Profile A (Reality VPS)**.
3. Perform latency test (⚡).
4. Keep the Windows 11 Cloudflare profile as a secondary fallback in your server list.

---

## 4. Zero-Downtime Rollback Plan
If the VPS public IP experiences routing issues or regional carrier blocking:
1. Do not delete the Windows 11 installation immediately. Keep Windows active for 7 days during validation.
2. In HAPP on Android, simply switch active server toggle back to **Profile B1 (Cloudflare WS)** or **Profile C (ZeroTier)**.
