import React, { useState } from 'react';
import { Terminal, Copy, Check, ShieldAlert, Cpu, Laptop, Server } from 'lucide-react';

export const DeploymentGuides: React.FC = () => {
  const [activePlatform, setActivePlatform] = useState<'windows' | 'vps' | 'orangepi'>('windows');
  const [copiedIndex, setCopiedIndex] = useState<number | null>(null);

  const copyToClipboard = (text: string, index: number) => {
    navigator.clipboard.writeText(text);
    setCopiedIndex(index);
    setTimeout(() => setCopiedIndex(null), 2000);
  };

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-xl font-semibold text-slate-900 tracking-tight">
          Platform Deployment & Automation Scripts
        </h2>
        <p className="text-sm text-slate-600 mt-1">
          Production scripts engineered for idempotent installation, zero downtime updates, atomic rollbacks, and memory-constrained environments.
        </p>
      </div>

      {/* Platform Tabs */}
      <div className="flex space-x-2 border-b border-slate-200 pb-3">
        <button
          id="tab-platform-windows"
          onClick={() => setActivePlatform('windows')}
          className={`flex items-center space-x-2 px-4 py-2 rounded-lg text-xs sm:text-sm font-medium transition-colors cursor-pointer ${
            activePlatform === 'windows'
              ? 'bg-slate-900 text-white shadow-xs'
              : 'bg-white text-slate-600 border border-slate-200 hover:bg-slate-50'
          }`}
        >
          <Laptop className="w-4 h-4" />
          <span>Windows 11 (Home NAT)</span>
        </button>

        <button
          id="tab-platform-vps"
          onClick={() => setActivePlatform('vps')}
          className={`flex items-center space-x-2 px-4 py-2 rounded-lg text-xs sm:text-sm font-medium transition-colors cursor-pointer ${
            activePlatform === 'vps'
              ? 'bg-slate-900 text-white shadow-xs'
              : 'bg-white text-slate-600 border border-slate-200 hover:bg-slate-50'
          }`}
        >
          <Server className="w-4 h-4" />
          <span>Linux VPS (Public IP)</span>
        </button>

        <button
          id="tab-platform-orangepi"
          onClick={() => setActivePlatform('orangepi')}
          className={`flex items-center space-x-2 px-4 py-2 rounded-lg text-xs sm:text-sm font-medium transition-colors cursor-pointer ${
            activePlatform === 'orangepi'
              ? 'bg-slate-900 text-white shadow-xs'
              : 'bg-white text-slate-600 border border-slate-200 hover:bg-slate-50'
          }`}
        >
          <Cpu className="w-4 h-4" />
          <span>Orange Pi PC Plus (ARMv7)</span>
        </button>
      </div>

      {/* Windows 11 Guide */}
      {activePlatform === 'windows' && (
        <div className="space-y-4">
          <div className="bg-white rounded-xl border border-slate-200 p-5 shadow-xs space-y-4">
            <h3 className="text-base font-semibold text-slate-900">
              Windows 11 Residential Deployment (PowerShell 5.1 / 7)
            </h3>
            <p className="text-xs text-slate-600">
              Designed to run behind ISP Carrier-Grade NAT (CGNAT) using Cloudflare Tunnel. Outbound QUIC/TLS tunnels eliminate the need for port forwarding or static IP.
            </p>

            <div className="space-y-3">
              {[
                {
                  title: '1. Run Automated Idempotent Installer (Run as Administrator)',
                  cmd: 'cd server\\windows\n.\\install.ps1',
                  desc: 'Downloads official Xray release, generates UUID & paths, sets up Windows Scheduled Task or Service, and performs instant port binding checks.',
                },
                {
                  title: '2. Generate HAPP Client URIs & Server Config',
                  cmd: '.\\generate-config.ps1 -Domain "tunnel.yourdomain.com"',
                  desc: 'Creates a production config.json and outputs ready-to-import vless:// URIs for Android HAPP.',
                },
                {
                  title: '3. Multi-tier Health Check & Watchdog',
                  cmd: '.\\check.ps1\n.\\watchdog.ps1',
                  desc: 'Inspects binary integrity, process, local listening ports (10808/10809), and Cloudflare Tunnel egress.',
                },
                {
                  title: '4. Safe Binary Update with Automatic Rollback',
                  cmd: '.\\update.ps1',
                  desc: 'Backs up current binary and config. If the new release fails verification, it automatically rolls back seamlessly.',
                },
              ].map((step, idx) => (
                <div key={idx} className="p-3.5 bg-slate-50 rounded-lg border border-slate-100">
                  <div className="flex items-center justify-between mb-1.5">
                    <span className="text-xs font-semibold text-slate-900">{step.title}</span>
                    <button
                      id={`btn-copy-win-${idx}`}
                      onClick={() => copyToClipboard(step.cmd, idx)}
                      className="text-xs text-slate-500 hover:text-slate-900 flex items-center space-x-1 cursor-pointer"
                    >
                      {copiedIndex === idx ? (
                        <>
                          <Check className="w-3 h-3 text-emerald-600" />
                          <span className="text-emerald-600">Copied</span>
                        </>
                      ) : (
                        <>
                          <Copy className="w-3 h-3" />
                          <span>Copy</span>
                        </>
                      )}
                    </button>
                  </div>
                  <pre className="text-xs font-mono bg-slate-900 text-emerald-400 p-2.5 rounded-md overflow-x-auto whitespace-pre">
                    {step.cmd}
                  </pre>
                  <p className="text-xs text-slate-500 mt-1.5">{step.desc}</p>
                </div>
              ))}
            </div>
          </div>
        </div>
      )}

      {/* Linux VPS Guide */}
      {activePlatform === 'vps' && (
        <div className="space-y-4">
          <div className="bg-white rounded-xl border border-slate-200 p-5 shadow-xs space-y-4">
            <h3 className="text-base font-semibold text-slate-900">
              Linux VPS Deployment (x86_64 XTLS-Reality Port 443)
            </h3>
            <p className="text-xs text-slate-600">
              Direct connection on port 443 with X25519 Reality authentication and fallbacks to authentic web servers.
            </p>

            <div className="space-y-3">
              {[
                {
                  title: '1. One-Click Linux VPS Installation',
                  cmd: 'git clone https://github.com/your-username/mobile-resilience-xray.git /opt/mobile-resilience\ncd /opt/mobile-resilience\nsudo ./server/linux/install.sh',
                  desc: 'Installs Xray core to /usr/local/bin, generates Reality X25519 keypair and shortId, sets up systemd with CAP_NET_BIND_SERVICE.',
                },
                {
                  title: '2. Healthcheck & Diagnostics',
                  cmd: 'sudo ./server/linux/healthcheck.sh',
                  desc: 'Tests syntax with xray -test, checks listening socket on 0.0.0.0:443, and verifies fallback web server reachability.',
                },
                {
                  title: '3. Exponential Backoff Watchdog Daemon',
                  cmd: 'sudo ./server/linux/watchdog.sh',
                  desc: 'Runs crash loop protection with exponential backoff (2s, 4s, 8s, up to 60s) to prevent systemd thrashing.',
                },
              ].map((step, idx) => (
                <div key={idx} className="p-3.5 bg-slate-50 rounded-lg border border-slate-100">
                  <div className="flex items-center justify-between mb-1.5">
                    <span className="text-xs font-semibold text-slate-900">{step.title}</span>
                    <button
                      id={`btn-copy-vps-${idx}`}
                      onClick={() => copyToClipboard(step.cmd, 10 + idx)}
                      className="text-xs text-slate-500 hover:text-slate-900 flex items-center space-x-1 cursor-pointer"
                    >
                      {copiedIndex === 10 + idx ? (
                        <>
                          <Check className="w-3 h-3 text-emerald-600" />
                          <span className="text-emerald-600">Copied</span>
                        </>
                      ) : (
                        <>
                          <Copy className="w-3 h-3" />
                          <span>Copy</span>
                        </>
                      )}
                    </button>
                  </div>
                  <pre className="text-xs font-mono bg-slate-900 text-emerald-400 p-2.5 rounded-md overflow-x-auto whitespace-pre">
                    {step.cmd}
                  </pre>
                  <p className="text-xs text-slate-500 mt-1.5">{step.desc}</p>
                </div>
              ))}
            </div>
          </div>
        </div>
      )}

      {/* Orange Pi Guide */}
      {activePlatform === 'orangepi' && (
        <div className="space-y-4">
          <div className="bg-white rounded-xl border border-slate-200 p-5 shadow-xs space-y-4">
            <div className="flex items-start justify-between">
              <div>
                <h3 className="text-base font-semibold text-slate-900">
                  Orange Pi PC Plus (Allwinner H3, ARMv7 32-bit, 1GB RAM)
                </h3>
                <p className="text-xs text-slate-600 mt-1">
                  Engineered with strict hardware safeguards: RAM-backed tmpfs logging to prevent eMMC flash burnout and ZRAM swap to prevent Out-Of-Memory (OOM) kernel kills.
                </p>
              </div>
              <span className="px-2 py-0.5 text-xs font-medium rounded-full bg-amber-50 text-amber-800 border border-amber-200">
                ARMv7 Architecture Filter
              </span>
            </div>

            <div className="space-y-3">
              {[
                {
                  title: '1. Hardware Optimization & Flash Protection (Run First)',
                  cmd: 'sudo ./server/orangepi/tuning.sh',
                  desc: 'Enables ZRAM swap with LZ4 compression, mounts /var/log/xray into tmpfs RAM, sets sysctl swappiness=60, and CPU governor to ondemand.',
                },
                {
                  title: '2. Low-Memory ARMv7 Installer',
                  cmd: 'sudo ./server/orangepi/install.sh',
                  desc: 'Downloads Xray-linux-arm32-v7a.zip, configures GOMEMLIMIT=256MiB in systemd, and removes memory-heavy stats modules.',
                },
                {
                  title: '3. Memory Guard & Thermal Monitor Daemon',
                  cmd: 'sudo ./server/orangepi/memory-guard.sh',
                  desc: 'Monitors memory threshold (restarts gracefully before OOM killer activates) and alerts if SoC temperature exceeds 78°C.',
                },
              ].map((step, idx) => (
                <div key={idx} className="p-3.5 bg-slate-50 rounded-lg border border-slate-100">
                  <div className="flex items-center justify-between mb-1.5">
                    <span className="text-xs font-semibold text-slate-900">{step.title}</span>
                    <button
                      id={`btn-copy-opi-${idx}`}
                      onClick={() => copyToClipboard(step.cmd, 20 + idx)}
                      className="text-xs text-slate-500 hover:text-slate-900 flex items-center space-x-1 cursor-pointer"
                    >
                      {copiedIndex === 20 + idx ? (
                        <>
                          <Check className="w-3 h-3 text-emerald-600" />
                          <span className="text-emerald-600">Copied</span>
                        </>
                      ) : (
                        <>
                          <Copy className="w-3 h-3" />
                          <span>Copy</span>
                        </>
                      )}
                    </button>
                  </div>
                  <pre className="text-xs font-mono bg-slate-900 text-emerald-400 p-2.5 rounded-md overflow-x-auto whitespace-pre">
                    {step.cmd}
                  </pre>
                  <p className="text-xs text-slate-500 mt-1.5">{step.desc}</p>
                </div>
              ))}
            </div>

            <div className="p-3 bg-amber-50 rounded-lg border border-amber-200 text-xs text-amber-900">
              <strong>Cryptographic Hardware Note:</strong> The ARM Cortex-A7 in Allwinner H3 lacks ARMv8 Crypto Extensions. Software AES-GCM causes heavy CPU consumption and heat. In Profile B1/B2, decryption is handled on Cloudflare Edge (<code className="font-mono">decryption: none</code>), and client uses ChaCha20-Poly1305 where supported.
            </div>
          </div>
        </div>
      )}
    </div>
  );
};
