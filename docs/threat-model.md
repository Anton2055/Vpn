# Comprehensive Threat Model & Censorship Evasion Matrix

## 1. Threat Modeling Methodology

This document evaluates the resilience and cryptographic posture of the Mobile Network Resilience architecture against modern deep packet inspection (DPI), state censorship firewalls, and carrier network interference.

Evaluated Transports:
* **Profile A**: VLESS + TCP + XTLS-Reality (Vision Flow)
* **Profile B1**: VLESS + WebSocket + TLS (Cloudflare CDN Anycast)
* **Profile B2**: VLESS + XHTTP / SplitHTTP (Cloudflare CDN Anycast)
* **Profile C**: VLESS + ZeroTier (Private L3 Mesh Encrypted via Salsa20/Poly1305)

---

## 2. Threat Analysis Matrix

| Threat | Mitigated? | Mitigation Mechanism | Real-World Operational Limitations |
| :--- | :--- | :--- | :--- |
| **1. SNI Inspection & Filtering** | **YES** | **Profile A (Reality)**: Directly spoofs SNI to popular white-listed domains (`www.microsoft.com`). Server terminates TLS handshake with genuine certificate matching the fake SNI.<br>**Profile B1/B2 (Cloudflare)**: SNI matches genuine registered Cloudflare customer domain (`tunnel.yourdomain.com`). Handshake is genuine Cloudflare edge TLS. | If the entire target SNI or Cloudflare customer domain is explicitly blacklisted by name in DNS or SNI filters, connections to that domain are dropped. |
| **2. Active Probing (Replay / Scanner Attacks)** | **YES** | **Profile A**: If a scanner connects to port 443 without valid X25519 authentication, Xray transparently forwards (fallbacks) the connection to the authentic destination web server (`www.microsoft.com:443`). Scanner receives 100% genuine Microsoft TLS certificates and HTTP responses.<br>**Profile B1/B2**: Probers connect to Cloudflare edge IPs; unauthorized requests without correct secret WS/XHTTP path receive standard HTTP 404. Origin IP is completely hidden. | In Profile A, destination server must support TLS 1.3 and H2 to ensure fingerprint fidelity. |
| **3. Traffic Pattern & Timing Analysis (Flow / Packet Sizing)** | **PARTIAL** | **Profile A (XTLS-Reality Vision)**: Dynamically injects padding into initial TLS records to disguise proxy handshakes as normal HTTPS browsing.<br>**Profile B2 (XHTTP)**: Splits request/response streams across separate HTTP/2 channels. | Heavy sustained bulk downloads (e.g. 50GB continuous multi-gigabit streams) exhibit throughput signatures distinct from normal web browsing. DPI utilizing long-term statistical volume analysis may flag continuous high-bandwidth channels. |
| **4. Cloudflare IP Range Blacklisting / Throttling** | **NO** (Within Profile B) / **YES** (Via Multi-Profile Failover) | Profile B traverses Cloudflare edge. If a state censor blocks all Cloudflare Anycast IP subnets (e.g., 104.16.0.0/12, 172.64.0.0/13), Profile B fails.<br>**Defense**: Automated failover to **Profile A (Direct VPS IP)** or **Profile C (ZeroTier)**. | When Cloudflare Anycast is blocked in a specific region, client must switch profiles away from Cloudflare. |
| **5. TLS Fingerprinting (JA3 / JA4 / uTLS)** | **YES** | Client-side HAPP implements **uTLS** (configured with `fp=chrome`). The TLS ClientHello packet, including cipher suites, extensions, elliptic curves, and ALPN order, precisely mimics Google Chrome on Android. | If client OS or VPN app disables uTLS, standard Go/Java TLS signatures may be detected by strict JA3 inspect engines. |
| **6. Mobile Network Reconnect Drops (LTE <-> 5G <-> Wi-Fi)** | **YES** | 1. Xray Multiplexing (`mux.cool`) and short TCP connection timeouts.<br>2. Cloudflare Anycast edge maintains regional session affinity.<br>3. ZeroTier mesh dynamically re-evaluates physical paths via STUN when local IP changes. | Android OS may take 1–3 seconds to hand off default gateway during cellular-to-Wi-Fi transition; active in-flight TCP sockets will reset. |
| **7. ZeroTier Handshake Detection (UDP 9993)** | **PARTIAL** | ZeroTier payload is encrypted using 256-bit Salsa20 and authenticated via Poly1305. Packets appear as high-entropy UDP datagrams without cleartext headers. | Strict enterprise/carrier firewalls that enforce default-deny outbound UDP policies or whitelist only UDP port 53 (DNS) will drop ZeroTier packets, forcing reliance on Profile B1 (TCP 443). |
| **8. DPI Heuristics Against Standard WebSockets** | **HIGH** | In Profile B1, WebSocket frames travel inside genuine TLS 1.3 tunnels terminated by Cloudflare. Censors see only standard Cloudflare HTTPS. In Profile B2, XHTTP eliminates WebSocket framing altogether, using HTTP POST streams. | Certain regional DPI devices terminate TLS via sovereign root CA or throttle all long-lived HTTP sessions exceeding 15 minutes. |

---

## 3. Summary Threat Assessment

The multi-profile architecture successfully defeats single-point censorship failures:
* If direct VPS IP is blocked: **Cloudflare Tunnel (Profile B1/B2)** remains reachable.
* If Cloudflare CDN is throttled or SNI is blocked: **Direct Reality (Profile A)** or **ZeroTier (Profile C)** provides alternate transit.
* If all outbound UDP is blocked: **TCP-based HTTPS (Profile A & B1)** functions seamlessly.
