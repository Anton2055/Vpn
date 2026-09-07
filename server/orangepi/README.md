# Orange Pi PC Plus Deployment & Hardware Optimization Guide

## 1. Hardware Architecture & Constraints

* **SoC**: Allwinner H3 (Quad-core ARM Cortex-A7 @ 1.2 GHz)
* **Instruction Set**: **ARMv7-A (32-bit only)**
* **RAM**: 1 GB DDR3 (Shared with video/GPU)
* **Storage**: 8 GB eMMC 4.5 + MicroSD slot
* **Ethernet**: 10/100/1000M Realtek RTL8211E

### Critical Architectural Rules:
1. **Never attempt to install `arm64` packages**: The Allwinner H3 is strictly 32-bit (`armv7l`). Installing 64-bit binaries will fail with `Exec format error`.
2. **Official Binary**: Always deploy `Xray-linux-arm32-v7a.zip`.

---

## 2. Cryptographic Performance: ChaCha20 vs. AES on Cortex-A7

Cortex-A7 cores **lack ARM Cryptography Extensions** (hardware AES instructions were introduced only in ARMv8-A). 

* **Software AES-128-GCM**: Calculates AES substitution boxes and Galois field multiplication purely via generic ALU and NEON routines. Under high throughput (50+ Mbps), CPU load spikes to 90–100% on core 0, causing latency and thermal throttling.
* **ChaCha20-Poly1305**: Built on simple ARX operations (Add-Rotate-XOR) which execute with single-cycle latency on ARMv7 pipelines. ChaCha20 is approximately **2.8x to 3.5x faster** than software AES on Allwinner H3.
* **VLESS Decryption Strategy**: In our architecture, the VLESS layer sets `decryption: none`. Wire encryption is handled either by TLS 1.3 (where ChaCha20-Poly1305 is prioritized in cipher suites) or Cloudflare's edge termination. This frees the Cortex-A7 CPU from double-encryption bottlenecks.

---

## 3. Flash Storage (eMMC) Wear Protection

Continuous logging on an 8 GB eMMC will rapidly exhaust flash write cycles, leading to corrupt file systems or dead blocks within 12–24 months.

**Our Mitigation Strategy**:
1. **RAM-backed tmpfs for Logs**: `/var/log/xray` is mounted as a 16MB `tmpfs` in RAM. Log writes never hit physical NAND flash.
2. **Access Log Disabled**: Only high-priority `warning` and `error` events are emitted.
3. **Delayed Flush Interval**: `sysctl` configures `vm.dirty_ratio` and `dirty_background_ratio` to buffer filesystem metadata in RAM before committing to disk.

---

## 4. Memory Limits & ZRAM Configuration

With only 1 GB total system memory:
* Linux Kernel + Systemd: ~150 MB
* ZeroTier Daemon: ~25 MB
* Network buffers & filesystem cache: ~200 MB
* Headroom left for applications: ~600 MB

**Xray Go Runtime Controls**:
* `Environment="GOMEMLIMIT=256MiB"`: Instructs the Go garbage collector to aggressively reclaim heap before reaching 256MB.
* `Environment="GOGC=60"`: Triggers GC sweeps at 60% allocation growth instead of default 100%.
* Systemd Cgroup: `MemoryHigh=300M`, `MemoryMax=384M`.
* **ZRAM Swap**: Configured with LZ4 compression providing an extra 512MB virtual memory pool with near-zero latency and zero disk writes.

---

## 5. Thermals & Cooling

Allwinner H3 is known for high operating temperatures (often idling at 55–65°C and hitting 80°C without heatsinks).
* An adhesive aluminum or copper heatsink (14x14mm) on the H3 SoC is **mandatory**.
* The CPU governor is locked to `ondemand` to allow idle downclocking to 240 MHz.
* Monitor thermal readings via:
  ```bash
  cat /sys/devices/virtual/thermal/thermal_zone0/temp
  ```
