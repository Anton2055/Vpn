# Troubleshooting & Diagnostics Matrix

## Overview
This matrix provides a symptom-cause-investigation-remedy framework covering the 3-layer architecture: Profile A (Direct Reality), Profile B (Cloudflare Tunnel WS/XHTTP), and Profile C (ZeroTier Mesh).

---

## 1. Profile A (Direct VPS - VLESS Reality)

### Symptom A1: Handshake Timeout / Endless Connecting
* **Possible Causes**:
  1. Port 443 blocked by cloud provider security group (AWS SG, Hetzner firewall, DigitalOcean VPC).
  2. Carrier active probing or SNI RST injection by regional censorship.
  3. Xray service stopped on VPS.
* **Diagnostic Commands**:
  ```bash
  # Check if port 443 is listening on VPS
  sudo ss -tulpn | grep :443
  
  # Test TCP handshake from external machine
  nc -zv -w 5 <VPS_IP> 443
  
  # Check Xray error log for TLS handshake errors
  sudo journalctl -u xray -n 50 | grep -i "handshake"
  ```
* **Resolution**:
  1. Open Inbound TCP/UDP Port 443 in cloud security groups.
  2. Verify Reality `serverNames` in `config.json` uses a legitimate TLS 1.3 destination with H2 support (e.g. `www.microsoft.com`).
  3. Ensure system time on VPS is synchronized via NTP (`timedatectl status`). Clock skew > 90 seconds breaks TLS handshakes.

---

### Symptom A2: Reality Certificate Mismatch / Vision Flow Error
* **Possible Causes**:
  1. Client public key (`pbk`) does not match server `privateKey`.
  2. ShortId mismatch or corrupted in HAPP configuration.
* **Diagnostic Commands**:
  ```bash
  # Re-verify Reality keypair on VPS
  /usr/local/bin/xray x25519
  ```
* **Resolution**:
  1. Re-export the client URI from `/etc/xray/client-profiles.txt`.
  2. Verify `flow: "xtls-rprx-vision"` is supported on the client. If client does not support Vision, remove `flow` parameter.

---

## 2. Profile B (Cloudflare Tunnel - WebSocket & XHTTP)

### Symptom B1: Cloudflare HTTP 524 (A Timeout Occurred)
* **Underlying Mechanism**:
  Cloudflare edge successfully received the client request, but the origin server (`cloudflared` -> Xray) failed to send HTTP response headers within 100 seconds.
* **Possible Causes**:
  1. `xray.exe` is not running on port 8080/8081.
  2. `cloudflared` is pointing to the wrong local port in its ingress rules.
  3. Windows host went to sleep or hibernated.
* **Diagnostic Commands (Windows)**:
  ```powershell
  # Verify local port 8080 is answering
  Test-NetConnection -ComputerName 127.0.0.1 -Port 8080
  
  # Inspect cloudflared service logs
  Get-EventLog -LogName Application -Source "cloudflared" -Newest 20
  ```
* **Resolution**:
  1. Start Xray service using `./server/windows/start.ps1`.
  2. Disable sleep / hibernate in Windows Power Settings (`powercfg /change standby-timeout-ac 0`).
  3. Verify `ingress` path in `C:\Program Files\cloudflared\config.yml` matches Xray's `streamSettings.wsSettings.path`.

---

### Symptom B2: Cloudflare HTTP 522 (Connection Timed Out) / HTTP 520 (Unknown Error)
* **Underlying Mechanism**:
  Cloudflare's edge cannot reach `cloudflared`.
* **Possible Causes**:
  1. Home router lost Internet connection.
  2. `cloudflared` process crashed or tunnel token was revoked.
* **Diagnostic Commands**:
  ```powershell
  Get-Process -Name "cloudflared"
  Get-Service -Name "cloudflared"
  ```
* **Resolution**:
  1. Restart tunnel daemon: `Restart-Service cloudflared`.
  2. Re-authenticate: `cloudflared tunnel login`.

---

### Symptom B3: WebSocket Handshake 400 / 403 / Upgrade Failed
* **Possible Causes**:
  1. WebSockets disabled in Cloudflare Dashboard.
  2. Mismatch between client WebSocket `path` and server `wsSettings.path`.
  3. Host header mismatch (`Host` header in HAPP does not match Cloudflare domain).
* **Diagnostic Commands**:
  ```bash
  # Test WebSocket upgrade manually via curl
  curl -i -N -H "Connection: Upgrade" -H "Upgrade: websocket" \
       -H "Host: tunnel.yourdomain.com" \
       -H "Origin: https://tunnel.yourdomain.com" \
       https://tunnel.yourdomain.com/YOUR_SECRET_WS_PATH
  ```
* **Resolution**:
  1. Go to Cloudflare Dashboard -> Network -> Toggle **WebSockets: ON**.
  2. In HAPP, check that `Host` and `SNI` match the exact domain (`tunnel.yourdomain.com`).

---

### Symptom B4: 100-Second Idle Disconnect
* **Underlying Mechanism**:
  Cloudflare terminates WebSocket connections that have no packet activity for 100 consecutive seconds.
* **Resolution**:
  1. Enable heartbeat/keep-alive in Xray client configuration (e.g., `client/android/HAPP.md`).
  2. For XHTTP (Profile B2), ensure `mode: "packet-up"` is configured.

---

### Symptom B5: Cloudflare Domain or CDN IP Blocked by Mobile Carrier
* **Underlying Mechanism**:
  Carrier firewall has placed the Cloudflare anycast IP range or the domain name into an allowlist-only or throttled routing table.
* **Resolution**:
  1. Switch to **Profile C (ZeroTier Emergency Out-of-Band)** in HAPP.
  2. Alternatively, switch HAPP to **Profile A (Direct VPS Reality)**.
  3. Use Cloudflare Workers / Custom Clean IP (CDN Anycast IP rotation).

---

## 3. Profile C (ZeroTier Private Mesh)

### Symptom C1: Node Not Authorized / Access Denied
* **Possible Causes**:
  Device joined the network, but administrator has not clicked "Auth" in the web dashboard.
* **Diagnostic Commands**:
  ```powershell
  zerotier-cli listnetworks
  # Check status column: 'ACCESS_DENIED' vs 'OK'
  ```
* **Resolution**:
  Log in to `https://my.zerotier.com`, open your Network ID, find the pending node address, and check the **Auth?** box.

---

### Symptom C2: High Latency (>200ms) / RELAY Mode Active
* **Underlying Mechanism**:
  Both mobile device (on LTE/5G carrier NAT) and home server (behind router NAT) are behind Symmetric NAT, preventing STUN UDP hole-punching. Traffic falls back to ZeroTier root relay servers (Planets).
* **Diagnostic Commands**:
  ```powershell
  zerotier-cli peers
  # Inspect the line for your Android peer:
  # <peer_id> <ip:port> DIRECT ...  (Good)
  # <peer_id> <ip:port> RELAY ...   (High latency)
  ```
* **Resolution**:
  1. Enable UPnP on your home router if available.
  2. If using VPS, ZeroTier will almost always achieve `DIRECT` status because VPS has a public IP.
  3. Set up a private ZeroTier Moon server on the VPS to shorten relay hops.

---

### Symptom C3: UDP Blocked or Throttled by Provider
* **Underlying Mechanism**:
  Some public Wi-Fi networks (hotels, trains, airports) aggressively block all outbound UDP traffic except port 53.
* **Resolution**:
  ZeroTier relies on UDP port 9993. If UDP is completely blocked, ZeroTier cannot establish a data plane. Switch back to **Profile B1 (WebSocket over HTTPS port 443 TCP)**, which passes transparently through strict firewalls.
