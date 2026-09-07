# Architecture Audit & Design Rationale

## 1. Executive Architectural Audit

### The Initial Hypothesis
The initial hypothesis proposed connecting Android (HAPP) to a home Windows 11 host via:
```
Android (HAPP)
      ↓ (TLS)
Cloudflare Edge
      ↓ (Cloudflare Tunnel)
cloudflared (Windows 11)
      ↓ (Localhost HTTP/XHTTP)
Xray-core (Windows 11)
      ↓
Internet
```
With the suggested transport: `VLESS + XHTTP + TLS + Cloudflare Tunnel`.

### Technical Feasibility Verdict: **PARTIALLY VIABLE (WITH CRITICAL CAVEATS) — FIX REQUIRED**

Can the chosen Xray transport work reliably through Cloudflare Reverse Proxy and Cloudflare Tunnel?
**Answer: YES for WebSocket; ONLY CONDITIONALLY for XHTTP; and direct VLESS-Reality CANNOT pass through Cloudflare CDN at all.**

Here is the deep engineering analysis:

---

## 2. In-Depth Analysis of Cloudflare Reverse Proxy & Tunnel Mechanics

### 2.1. Request Body Buffering & Streaming Behavior
* **HTTP Reverse Proxy Semantics**: Cloudflare Edge is designed as an HTTP caching reverse proxy, not a generic TCP tunnel. By default, incoming HTTP POST requests are buffered at the edge until the request body completes or reaches chunk thresholds.
* **XHTTP Modes Behind Cloudflare**:
  1. `packet-up`: The client breaks upload traffic into discrete chunked POST requests while maintaining a single long-lived download stream (SSE or raw). This avoids upload stalls because individual POST requests terminate cleanly. However, under heavy bidirectional traffic (e.g. YouTube 720p or video calls), generating dozens of POST requests per second triggers Cloudflare edge rate limiting, anti-DDoS heuristics, and elevated CPU usage.
  2. `stream-up`: Uses two persistent concurrent HTTP/2 streams (one uplink, one downlink). Cloudflare's edge proxy buffers chunked uplink streams unless explicitly negotiated. If an uplink is buffered, interactive traffic (SSH, DNS, TCP handshakes) stalls.
  3. `stream-one`: Operates bidirectional full-duplex traffic over a single HTTP connection. **Crucial fact**: Cloudflare Edge **BLOCKS or corrupts** `stream-one` unless the **gRPC** feature is explicitly turned ON in the Cloudflare Dashboard (Network -> gRPC). When gRPC is enabled, Cloudflare treats the stream as an unbuffered HTTP/2 bidirectional stream. If gRPC is disabled or not supported on the origin path, `stream-one` fails completely.

### 2.2. The 100-Second Idle Timeout (HTTP 524)
* Cloudflare enforces a strict **100-second idle read timeout** on all edge connections (Enterprise plans allow higher, but standard/free tiers are hard-capped at 100s).
* If no application data flows for 100 seconds (e.g. user is reading a static web article, or the client is idle), Cloudflare forcefully closes the connection with `HTTP 524 A timeout occurred`.
* In XHTTP `packet-up`, while the client can pause uploads, the single server-to-client download stream remains idle and will be severed by Cloudflare unless the Xray server injects periodic keep-alive padding frames (every 20–50 seconds).

### 2.3. WebSocket (`type=ws`) vs XHTTP (`type=xhttp`) over Cloudflare
* **WebSocket**: Cloudflare has native, official RFC 6455 WebSocket support across all tiers. WebSocket initiates via `HTTP 101 Switching Protocols` and transitions into a raw bidirectional frame stream. It does not suffer from HTTP POST body buffering. Built-in TCP/WebSocket keep-alive pings keep the tunnel open indefinitely. In all major mobile clients (including HAPP), VLESS+WS+TLS over Cloudflare is stable, thoroughly tested, and resilient.
* **XHTTP**: XHTTP's primary design strength is disguising proxy traffic as standard HTTP requests when communicating with custom front-end servers or CDNs that block WebSocket. However, when paired with Cloudflare Tunnel, WebSocket is objectively more stable for bulk data transfer.
* **Decision**: We retain **VLESS + WebSocket** as the primary CDN profile through Cloudflare Tunnel (Profile B1), and provide **VLESS + XHTTP (`packet-up`)** as an auxiliary profile (Profile B2) for environments where the `Upgrade: websocket` header is explicitly filtered by local ISP DPI.

### 2.4. Censorship and Allowlist/Whitelist Vulnerability of Cloudflare
* In restricted network environments (such as Russia during TSPU degradation events or China during GFW events), Cloudflare edge IP blocks (`104.16.0.0/12`, `172.64.0.0/13`, etc.) are frequently throttled, packet-dropped, or blocked.
* Relying exclusively on Cloudflare violates the core tenet: **STABILITY > RESILIENCE > COMPATIBILITY > STEALTH > SPEED**.
* Cloudflare Tunnel and ZeroTier must be decoupled into **Layer A (Reachability/Management)**, while **Layer B (Data Transport)** utilizes diverse pathways.

---

## 3. The Correct Multi-Tier Architecture

To achieve absolute resilience, the project implements a 3-layer architecture with 3 fallback profiles:

```
┌────────────────────────────────────────────────────────────────────────┐
│                        ANDROID CLIENT (HAPP)                           │
└────┬─────────────────────────────┬───────────────────────────────┬────┘
     │ Profile A: Primary          │ Profile B: Fallback (NAT)     │ Profile C: Emergency
     │ (When on VPS/Public IP)     │ (Via Cloudflare Tunnel)       │ (Out-of-band P2P)
     ▼                             ▼                               ▼
┌──────────────────────┐  ┌───────────────────────────────┐ ┌──────────────────────┐
│ Direct TLS 1.3       │  │ Cloudflare Edge               │ │ ZeroTier Virtual     │
│ VLESS + Reality      │  │ (TLS 1.3 / HTTP/2 or QUIC)    │ │ Encrypted Mesh L3    │
│ (Vision Flow)        │  └──────────────┬────────────────┘ └──────────┬───────────┘
│ Port 443             │                 │ Cloudflare Tunnel           │ ZeroTier UDP
└──────────┬───────────┘                 │ (cloudflared daemon)        │ Hole Punch / Relay
           │                             ▼                             │
           │              ┌───────────────────────────────┐            │
           │              │ Inbound: WS (port 8080)       │            │
           │              │ Inbound: XHTTP (port 8081)    │            │
           │              └──────────────┬────────────────┘            │
           │                             │                             ▼
           │                             │                  ┌──────────────────────┐
           │                             │                  │ Inbound: ZeroTier    │
           │                             │                  │ VLESS-TCP (pt 10808) │
           │                             │                  └──────────┬───────────┘
           ▼                             ▼                             ▼
┌─────────────────────────────────────────────────────────────────────────────────┐
│                           XRAY-CORE SERVICE ENGINE                              │
│       (Windows 11 Service  |  Linux VPS systemd  |  Orange Pi ARMv7 systemd)     │
└────────────────────────────────────────┬────────────────────────────────────────┘
                                         │ Direct Outbound
                                         ▼
                                   [ INTERNET ]
```

### Layer Separation
* **Layer A: Reachability & Management**
  * **Cloudflare Tunnel (`cloudflared`)**: Traverses residential NAT on Windows 11 without port forwarding. Provides remote web healthcheck endpoints and acts as ingress for Profile B.
  * **ZeroTier Mesh**: Encrypted out-of-band network. Direct P2P tunnel when NAT punch succeeds, relay when symmetric NAT. Enables SSH/RDP and emergency proxy access.
* **Layer B: Data Transport**
  * **Profile A (Primary for VPS / Public IP)**: `VLESS + TCP + XTLS-Reality (Vision)`. Mimics legitimate TLS handshakes to whitelisted domains (`www.microsoft.com`). Unmatched speed, lowest latency, zero CDN dependence.
  * **Profile B1 (Primary for Windows NAT)**: `VLESS + WebSocket + TLS` through Cloudflare Tunnel.
  * **Profile B2 (Stealth Fallback for Windows NAT)**: `VLESS + XHTTP (mode=packet-up)` through Cloudflare Tunnel with tuned keepalive.
  * **Profile C (Emergency / Out-of-band)**: `VLESS + TCP` directly over ZeroTier private IP (`10.147.17.x:10808`). Zero dependence on Cloudflare or public DNS.

---

## 4. Hardware Constraints & Platform Matrix

| Platform | Arch | RAM | Storage / eMMC | Recommended Role | Inbound Transports Active |
|---|---|---|---|---|---|
| **Windows 11** | x86_64 | ≥ 8 GB | NVMe / SSD | Dev / Home Server behind NAT | WS (8080), XHTTP (8081), ZeroTier (10808) |
| **Linux VPS** | x86_64 | ≥ 1 GB | Cloud SSD | Production Node with Public IP | Reality (443), WS (8080), ZeroTier (10808) |
| **Orange Pi PC Plus** | ARMv7 (32-bit Allwinner H3) | 1 GB DDR3 | 8 GB eMMC | Dedicated Low-Power Edge Node | WS (8080), ZeroTier (10808), tuned GC & zram |

### Specific Optimizations for Orange Pi PC Plus (ARMv7 1GB RAM)
1. **Binary Asset**: `Xray-linux-arm32-v7a.zip` (verified official release artifact).
2. **Memory Guard**: Xray Go garbage collector tuned with `GOMEMLIMIT=180MiB` to prevent OOM kills.
3. **Storage Protection**: Logs directed to `tmpfs` (RAM) to prevent wearing out the 8GB eMMC flash memory.
4. **systemd Unit**: Configured with `MemoryMax=256M` and automatic restart with exponential backoff.
