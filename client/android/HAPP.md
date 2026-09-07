# HAPP Client Setup & Integration Guide (Android)

## 1. About HAPP Client

**Happ** (`happ-android`) is a modern, privacy-focused proxy utility built on the **Xray-core** engine. It supports modern proxy protocols, including:
* VLESS (XTLS-Reality, WebSocket, XHTTP / SplitHTTP)
* Trojan, VMess, Shadowsocks, Hysteria2
* Routing rules, DNS-over-HTTPS (DoH), and per-app proxying.

Official Sources:
* GitHub: `https://github.com/Happ-proxy/happ-android`
* Web: `https://happ.su`

---

## 2. Profile Definitions & URI Formats

### Profile A: Primary High-Speed Transport (Direct VPS with Public IP)
* **Transport**: VLESS + TCP + XTLS-Reality (Vision Flow)
* **Port**: 443
* **Stealth**: Mimics TLS 1.3 ClientHello to genuine destination (`www.microsoft.com`).
* **HAPP URI Format**:
```text
vless://<UUID>@<VPS_IP_OR_DIRECT_DOMAIN>:443?security=reality&encryption=none&pbk=<REALITY_PUBLIC_KEY>&headerType=none&fp=chrome&type=tcp&flow=xtls-rprx-vision&sni=www.microsoft.com&sid=<SHORT_ID>#Profile-A-Reality-Direct
```

### Profile B1: Residential NAT Transport (Cloudflare Tunnel - WebSocket)
* **Transport**: VLESS + WebSocket + TLS
* **Port**: 443
* **Origin**: Residential Windows 11 / Orange Pi behind NAT via `cloudflared`
* **HAPP URI Format**:
```text
vless://<UUID>@<CF_TUNNEL_DOMAIN>:443?security=tls&encryption=none&type=ws&path=%2Fstream-ws-change-me&host=<CF_TUNNEL_DOMAIN>&fp=chrome&sni=<CF_TUNNEL_DOMAIN>#Profile-B1-Cloudflare-WS
```

### Profile B2: Stealth CDN Transport (Cloudflare Tunnel - XHTTP)
* **Transport**: VLESS + XHTTP (SplitHTTP) + TLS
* **Port**: 443
* **Mode**: `packet-up` (Required for unbuffered streaming through Cloudflare reverse proxy)
* **HAPP URI Format**:
```text
vless://<UUID>@<CF_TUNNEL_DOMAIN>:443?security=tls&encryption=none&type=xhttp&path=%2Fstream-xh-change-me&mode=packet-up&host=<CF_TUNNEL_DOMAIN>&fp=chrome&sni=<CF_TUNNEL_DOMAIN>#Profile-B2-Cloudflare-XHTTP
```
*Note on XHTTP in HAPP*: XHTTP (`type=xhttp`) requires HAPP versions powered by Xray-core v24.11 or newer. If your client version does not recognize `type=xhttp`, use Profile B1 (WebSocket).

### Profile C: Out-of-Band Emergency Transport (ZeroTier Private Mesh)
* **Transport**: VLESS + TCP (Unencrypted over L3 Salsa20/Poly1305 ZeroTier Mesh)
* **Port**: 10808
* **Pre-requisite**: ZeroTier Android client connected to the same Network ID.
* **HAPP URI Format**:
```text
vless://<UUID>@10.147.17.1:10808?security=none&encryption=none&type=tcp#Profile-C-ZeroTier-Emergency
```

---

## 3. Installation & Configuration Steps

### Step 1: Install HAPP on Android
1. Download the latest APK from the official repository (`https://github.com/Happ-proxy/happ-android/releases`).
2. Allow installation from trusted sources.
3. Launch HAPP and grant VPN service permissions when prompted.

### Step 2: Import Server Configurations
You can import your generated profiles using two methods:
1. **Clipboard Import**:
   - Run the configuration generator (`./scripts/generate-config.sh` or `server/windows/generate-config.ps1`).
   - Copy the generated `vless://` URI strings to your Android clipboard (via messaging, email, or local file).
   - In HAPP, tap the **`+`** icon in the top right corner and select **"Import from Clipboard"**.
2. **QR Code Import**:
   - Generate a QR code from the URI using any terminal or offline generator (`qrencode -t ANSI <uri>`).
   - In HAPP, tap **`+`** -> **"Scan QR Code"**.

### Step 3: Configure DNS in HAPP
To eliminate DNS poisoning and local ISP interception:
1. Open HAPP **Settings** -> **DNS**.
2. Set **Remote DNS** to `https://1.1.1.1/dns-query` (Cloudflare DoH) or `https://dns.google/dns-query`.
3. Enable **"Enable FakeDNS"** or **"Route Only"** according to your preferred network split.

### Step 4: Routing & Per-App Proxying
1. Set Routing Mode to **"Bypass LAN and Mainland"** or use custom rules to bypass local residential/domestic services.
2. Under **Per-App Proxy**, select only applications requiring proxying (e.g., Telegram, YouTube, Browsers) to conserve bandwidth on mobile connections.

---

## 4. Diagnostics & Failover Verification

1. **Ping & Handshake Test**:
   - In the HAPP servers list, tap the latency icon (⚡ or lightning bolt).
   - Expected latency:
     - Profile A (Reality): 40–90 ms (Direct round-trip).
     - Profile B1/B2 (Cloudflare): 60–140 ms (Includes Cloudflare Edge traversal).
     - Profile C (ZeroTier): 50–120 ms (Depends on direct UDP hole punching vs relay).
2. **Troubleshooting Failures**:
   - If Profile B1 returns `HTTP 524`: Connection timed out. Verify that `cloudflared` on Windows 11 is running and Xray is listening on port 8080.
   - If Profile B2 fails: Cloudflare may be dropping chunked uploads. Switch to Profile B1 (WebSocket).
   - If Cloudflare domain is blocked: Turn on ZeroTier on Android and switch HAPP to Profile C.
