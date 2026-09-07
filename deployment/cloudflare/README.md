# Cloudflare Tunnel Deployment Guide

## 1. Overview (Layer A - Reachability)

Cloudflare Tunnel (`cloudflared`) connects your home Windows 11 machine or Orange Pi to the Cloudflare global edge network over an encrypted outbound QUIC connection (with automatic HTTP/2 fallback). 

**Key Benefits for Residential Hosts**:
* No public IPv4 address or static IP required.
* No port forwarding on your home router needed.
* Hides your home residential IP address from direct client connections.

**Role in Architecture**:
Cloudflare Tunnel is **Layer A (Reachability)**. It brings client connections to your home computer through `tunnel.yourdomain.com`. The actual proxy protocol passing through it is **Layer B (Data Transport)**.

---

## 2. Cloudflare Dashboard Prerequisites

1. **Domain on Cloudflare**: You must have a domain whose nameservers point to Cloudflare.
2. **Enable WebSockets**:
   - Go to **Cloudflare Dashboard** -> **Network**.
   - Ensure **WebSockets** is toggled **ON** (Enabled by default, required for Profile B1).
3. **Enable gRPC (Optional for XHTTP)**:
   - In **Network**, toggle **gRPC** to **ON** if you plan to test XHTTP `stream-one` mode.
4. **SSL/TLS Encryption Mode**:
   - Set to **Full** (or **Strict** if custom certificates are placed on the origin). Because traffic between Cloudflare edge and your home computer is encapsulated in the Cloudflare Tunnel QUIC session, client-to-edge traffic is fully encrypted with Cloudflare's SSL certificate.

---

## 3. Windows 11 Setup

### Step 1: Install cloudflared
On Windows 11, run in an elevated PowerShell prompt:
```powershell
winget install --id Cloudflare.cloudflared -e
```
Or download `cloudflared-windows-amd64.exe` from official Cloudflare releases and place in `C:\Program Files\cloudflared\cloudflared.exe`.

### Step 2: Authenticate cloudflared
```powershell
cloudflared tunnel login
```
This opens a browser window. Select your domain to authorize.

### Step 3: Create Tunnel
```powershell
cloudflared tunnel create mobile-resilience-tunnel
```
Note the generated Tunnel ID (UUID) and the credentials file path (e.g., `C:\Users\<user>\.cloudflared\<TUNNEL-ID>.json`).

### Step 4: Route DNS
```powershell
cloudflared tunnel route dns mobile-resilience-tunnel tunnel.yourdomain.com
```

### Step 5: Install as Windows Service
Create `config.yml` (from `config/cloudflare/config.template.yml`) in `C:\Program Files\cloudflared\config.yml` and run:
```powershell
cloudflared service install
Start-Service cloudflared
```

---

## 4. Operational Limitations & Edge Behavior

1. **100-Second Idle Timeout (HTTP 524)**:
   - If an idle connection is maintained without traffic, Cloudflare drops it after 100 seconds.
   - For WebSocket (Profile B1), Xray sends internal keep-alive frames to keep the tunnel open.
   - For XHTTP (Profile B2), keep-alive padding must be active.
2. **Bandwidth & Terms of Service Notice**:
   - Cloudflare CDN is designed primarily for web content. Extremely high continuous bulk video streaming (tens of gigabytes daily) may trigger automated Cloudflare abuse reviews. For heavy continuous traffic, use Profile A (Direct VPS) or Profile C (ZeroTier).
