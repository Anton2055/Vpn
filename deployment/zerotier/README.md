# ZeroTier Deployment Guide (Emergency Out-of-Band Channel)

## 1. Overview & Architecture

ZeroTier provides an encrypted, decentralized Layer 2/3 virtual mesh network. In this architecture, ZeroTier serves as:
* **Layer A (Emergency Out-of-Band Reachability)**: An alternative management and traffic path that does not touch Cloudflare, public DNS, or standard web reverse proxies.
* **Direct P2P Capability**: ZeroTier automatically attempts direct UDP hole punching between client (Android) and server (Windows / VPS / Orange Pi). If successful, traffic travels directly end-to-end without relay latency.

---

## 2. Direct vs. Relay Connection Modes

ZeroTier connections exhibit two possible states:
1. **DIRECT (P2P)**: Both the Android phone and the server successfully punch through NAT using STUN. Round-trip latency equals the physical Internet path. Ideal performance.
2. **RELAYED (PLANET/MOON)**: If both endpoints reside behind symmetric NAT (common on carrier-grade CGNAT mobile connections) and hole punching fails, traffic is routed through encrypted ZeroTier root servers (Planets) or self-hosted relay servers (Moons). Relay adds 40–150ms of latency, but connectivity is guaranteed even under strict firewalls.

---

## 3. Setup Instructions

### Step 1: Create ZeroTier Network
1. Register at `https://my.zerotier.com` (Free tier supports up to 25 devices).
2. Create a Network and note the 16-character **Network ID** (e.g., `12ac34de56fa78bc`).
3. Under IPv4 Auto-Assign, choose a private subnet (e.g., `10.147.17.*`).

### Step 2: Join Server (Windows 11)
Run in PowerShell:
```powershell
winget install ZeroTier.ZeroTierOne -e
zerotier-one_x64.exe -q join <NETWORK_ID>
```
Go to the ZeroTier dashboard and click the **Auth?** checkbox for the newly joined device. Assign it a static IP, e.g., `10.147.17.1`.

### Step 3: Join Android Client
1. Install **ZeroTier One** on Android (Google Play or F-Droid).
2. Tap **`+`**, enter the same 16-character Network ID, and save.
3. Authorize the Android device in the ZeroTier web dashboard.
4. Verify assigned IP (e.g., `10.147.17.2`).

### Step 4: Verify Peer Connectivity
On Windows:
```powershell
zerotier-cli peers
```
Inspect the Android peer entry to check whether the link is `DIRECT` or `RELAY`.

### Step 5: Route HAPP via ZeroTier
In HAPP, select **Profile C (ZeroTier Emergency)**:
* Server Address: `10.147.17.1`
* Port: `10808`
* Transport: `tcp`
* Security: `none` (Because ZeroTier already provides 256-bit Salsa20/ChaCha20-Poly1305 link encryption).
