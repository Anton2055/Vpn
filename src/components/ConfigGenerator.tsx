import React, { useState } from 'react';
import { Copy, Check, QrCode, Sliders, RefreshCw, Key, ExternalLink } from 'lucide-react';

interface ConfigGeneratorProps {
  initialProfile?: string;
}

export const ConfigGenerator: React.FC<ConfigGeneratorProps> = ({ initialProfile = 'B1' }) => {
  const [profileType, setProfileType] = useState<string>(initialProfile);
  const [uuid, setUuid] = useState<string>('a1b2c3d4-e5f6-7a8b-9c0d-1e2f3a4b5c6d');
  const [domain, setDomain] = useState<string>('tunnel.yourdomain.com');
  const [vpsIp, setVpsIp] = useState<string>('198.51.100.42');
  const [wsPath, setWsPath] = useState<string>('/vless-ws-secure');
  const [xhttpPath, setXhttpPath] = useState<string>('/vless-xhttp');
  const [publicKey, setPublicKey] = useState<string>('P48X6v7Qk1Z9A3Y8wF0eL2R5T7uI4oP1sD3fG5hJ7kL');
  const [shortId, setShortId] = useState<string>('0123456789abcdef');
  const [copied, setCopied] = useState<boolean>(false);

  const generateRandomUuid = () => {
    // Generate RFC4122 v4 UUID
    const u = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function (c) {
      const r = (Math.random() * 16) | 0;
      const v = c === 'x' ? r : (r & 0x3) | 0x8;
      return v.toString(16);
    });
    setUuid(u);
  };

  // Generate the VLESS link based on chosen profile
  const buildVlessUri = () => {
    switch (profileType) {
      case 'A':
        return `vless://${uuid}@${vpsIp}:443?encryption=none&flow=xtls-rprx-vision&security=reality&sni=www.microsoft.com&fp=chrome&pbk=${publicKey}&sid=${shortId}&type=tcp#VPS-Reality-Direct`;
      case 'B1':
        return `vless://${uuid}@${domain}:443?encryption=none&security=tls&sni=${domain}&fp=chrome&type=ws&host=${domain}&path=${encodeURIComponent(
          wsPath
        )}#Cloudflare-WS-Resilience`;
      case 'B2':
        return `vless://${uuid}@${domain}:443?encryption=none&security=tls&sni=${domain}&fp=chrome&type=xhttp&host=${domain}&path=${encodeURIComponent(
          xhttpPath
        )}&mode=packet-up#Cloudflare-XHTTP-Stealth`;
      case 'C':
        return `vless://${uuid}@10.147.17.1:10808?encryption=none&security=none&type=tcp#ZeroTier-Emergency-Mesh`;
      default:
        return '';
    }
  };

  const vlessUri = buildVlessUri();

  const handleCopy = () => {
    navigator.clipboard.writeText(vlessUri);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-xl font-semibold text-slate-900 tracking-tight">
          HAPP Client URI & Configuration Generator
        </h2>
        <p className="text-sm text-slate-600 mt-1">
          Generate ready-to-import <code className="font-mono text-xs bg-slate-100 px-1.5 py-0.5 rounded">vless://</code> URLs for HAPP on Android with pre-configured uTLS Chrome fingerprinting and transport parameters.
        </p>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Left column: Controls */}
        <div className="bg-white rounded-xl border border-slate-200 p-5 shadow-xs space-y-4 lg:col-span-1">
          <div className="flex items-center justify-between pb-3 border-b border-slate-100">
            <span className="text-xs font-semibold uppercase tracking-wider text-slate-500">
              Profile Parameters
            </span>
            <Sliders className="w-4 h-4 text-slate-400" />
          </div>

          <div>
            <label className="block text-xs font-medium text-slate-700 mb-1">
              Select Transport Profile
            </label>
            <div className="grid grid-cols-2 gap-2">
              {[
                { id: 'A', label: 'A: Reality' },
                { id: 'B1', label: 'B1: CF WS' },
                { id: 'B2', label: 'B2: CF XHTTP' },
                { id: 'C', label: 'C: ZeroTier' },
              ].map((p) => (
                <button
                  key={p.id}
                  id={`btn-select-profile-${p.id}`}
                  onClick={() => setProfileType(p.id)}
                  className={`px-3 py-2 rounded-lg text-xs font-medium border text-left transition-colors cursor-pointer ${
                    profileType === p.id
                      ? 'bg-slate-900 text-white border-slate-900 shadow-xs'
                      : 'bg-white text-slate-700 border-slate-200 hover:bg-slate-50'
                  }`}
                >
                  {p.label}
                </button>
              ))}
            </div>
          </div>

          <div>
            <div className="flex items-center justify-between mb-1">
              <label className="block text-xs font-medium text-slate-700">Client UUID</label>
              <button
                id="btn-regen-uuid"
                onClick={generateRandomUuid}
                className="text-xs text-blue-600 hover:text-blue-800 flex items-center space-x-1 cursor-pointer"
              >
                <RefreshCw className="w-3 h-3 mr-0.5" />
                <span>New</span>
              </button>
            </div>
            <input
              id="input-uuid"
              type="text"
              value={uuid}
              onChange={(e) => setUuid(e.target.value)}
              className="w-full text-xs font-mono px-3 py-2 rounded-lg border border-slate-200 bg-slate-50 text-slate-800 focus:bg-white focus:outline-hidden focus:ring-1 focus:ring-slate-900"
            />
          </div>

          {(profileType === 'B1' || profileType === 'B2') && (
            <>
              <div>
                <label className="block text-xs font-medium text-slate-700 mb-1">
                  Cloudflare Tunnel Domain
                </label>
                <input
                  id="input-domain"
                  type="text"
                  value={domain}
                  onChange={(e) => setDomain(e.target.value)}
                  placeholder="tunnel.yourdomain.com"
                  className="w-full text-xs font-mono px-3 py-2 rounded-lg border border-slate-200 bg-slate-50 text-slate-800 focus:bg-white focus:outline-hidden focus:ring-1 focus:ring-slate-900"
                />
              </div>

              {profileType === 'B1' && (
                <div>
                  <label className="block text-xs font-medium text-slate-700 mb-1">
                    WebSocket Path
                  </label>
                  <input
                    id="input-wspath"
                    type="text"
                    value={wsPath}
                    onChange={(e) => setWsPath(e.target.value)}
                    className="w-full text-xs font-mono px-3 py-2 rounded-lg border border-slate-200 bg-slate-50 text-slate-800 focus:bg-white focus:outline-hidden focus:ring-1 focus:ring-slate-900"
                  />
                </div>
              )}

              {profileType === 'B2' && (
                <div>
                  <label className="block text-xs font-medium text-slate-700 mb-1">
                    XHTTP Path
                  </label>
                  <input
                    id="input-xhttppath"
                    type="text"
                    value={xhttpPath}
                    onChange={(e) => setXhttpPath(e.target.value)}
                    className="w-full text-xs font-mono px-3 py-2 rounded-lg border border-slate-200 bg-slate-50 text-slate-800 focus:bg-white focus:outline-hidden focus:ring-1 focus:ring-slate-900"
                  />
                </div>
              )}
            </>
          )}

          {profileType === 'A' && (
            <>
              <div>
                <label className="block text-xs font-medium text-slate-700 mb-1">
                  VPS Public IPv4
                </label>
                <input
                  id="input-vps-ip"
                  type="text"
                  value={vpsIp}
                  onChange={(e) => setVpsIp(e.target.value)}
                  placeholder="198.51.100.42"
                  className="w-full text-xs font-mono px-3 py-2 rounded-lg border border-slate-200 bg-slate-50 text-slate-800 focus:bg-white focus:outline-hidden focus:ring-1 focus:ring-slate-900"
                />
              </div>

              <div>
                <label className="block text-xs font-medium text-slate-700 mb-1">
                  Server Public Key (X25519)
                </label>
                <input
                  id="input-pubkey"
                  type="text"
                  value={publicKey}
                  onChange={(e) => setPublicKey(e.target.value)}
                  className="w-full text-xs font-mono px-3 py-2 rounded-lg border border-slate-200 bg-slate-50 text-slate-800 focus:bg-white focus:outline-hidden focus:ring-1 focus:ring-slate-900"
                />
              </div>

              <div>
                <label className="block text-xs font-medium text-slate-700 mb-1">
                  Reality Short ID
                </label>
                <input
                  id="input-shortid"
                  type="text"
                  value={shortId}
                  onChange={(e) => setShortId(e.target.value)}
                  className="w-full text-xs font-mono px-3 py-2 rounded-lg border border-slate-200 bg-slate-50 text-slate-800 focus:bg-white focus:outline-hidden focus:ring-1 focus:ring-slate-900"
                />
              </div>
            </>
          )}

          {profileType === 'C' && (
            <div className="p-3 bg-amber-50 rounded-lg border border-amber-200 text-xs text-amber-800">
              ZeroTier operates over an encrypted virtual L3 overlay. The target address is your server&apos;s assigned ZeroTier IP (e.g. 10.147.17.1).
            </div>
          )}
        </div>

        {/* Right column: Generated Output */}
        <div className="bg-white rounded-xl border border-slate-200 p-5 shadow-xs space-y-4 lg:col-span-2 flex flex-col justify-between">
          <div>
            <div className="flex items-center justify-between pb-3 border-b border-slate-100">
              <span className="text-xs font-semibold uppercase tracking-wider text-slate-500">
                Generated HAPP URI
              </span>
              <div className="flex items-center space-x-2">
                <span className="text-xs px-2 py-0.5 rounded-full bg-emerald-50 text-emerald-700 border border-emerald-200">
                  uTLS=Chrome Verified
                </span>
              </div>
            </div>

            <div className="mt-4">
              <label className="block text-xs font-medium text-slate-700 mb-2">
                VLESS URI (Import directly into HAPP via Clipboard)
              </label>
              <div className="relative">
                <textarea
                  id="textarea-vless-uri"
                  readOnly
                  rows={4}
                  value={vlessUri}
                  className="w-full p-3 text-xs font-mono bg-slate-950 text-emerald-400 rounded-lg border border-slate-800 focus:outline-hidden break-all resize-none"
                />
                <button
                  id="btn-copy-uri"
                  onClick={handleCopy}
                  className="absolute top-2.5 right-2.5 px-2.5 py-1.5 rounded-md bg-slate-800 hover:bg-slate-700 text-white text-xs font-medium flex items-center space-x-1.5 transition-colors cursor-pointer"
                >
                  {copied ? (
                    <>
                      <Check className="w-3.5 h-3.5 text-emerald-400" />
                      <span>Copied!</span>
                    </>
                  ) : (
                    <>
                      <Copy className="w-3.5 h-3.5 text-slate-300" />
                      <span>Copy</span>
                    </>
                  )}
                </button>
              </div>
            </div>

            <div className="mt-5 space-y-3">
              <h4 className="text-xs font-semibold uppercase tracking-wider text-slate-500">
                HAPP Android Import Checklist
              </h4>
              <ol className="text-xs text-slate-600 space-y-2 list-decimal list-inside bg-slate-50 p-3 rounded-lg border border-slate-100">
                <li>
                  Open <strong>HAPP</strong> on Android, tap the <strong>+</strong> icon in the top right corner.
                </li>
                <li>
                  Select <strong>&quot;Import from Clipboard&quot;</strong> (the URI copied above will automatically configure).
                </li>
                <li>
                  In HAPP Settings &rarr; <strong>DNS</strong>, verify <strong>DNS-over-HTTPS (DoH)</strong> is set to{' '}
                  <code className="bg-white px-1 py-0.5 rounded border border-slate-200 font-mono">
                    https://1.1.1.1/dns-query
                  </code>
                  .
                </li>
                <li>
                  Enable <strong>&quot;Allow Insecure&quot;</strong> = <strong>OFF</strong> (Strict certificate verification).
                </li>
                <li>
                  Tap the circular toggle button to connect and verify latency.
                </li>
              </ol>
            </div>
          </div>

          <div className="p-4 bg-slate-900 text-white rounded-lg flex items-center justify-between mt-4">
            <div className="flex items-center space-x-3">
              <div className="p-2 bg-slate-800 rounded-md">
                <Key className="w-4 h-4 text-emerald-400" />
              </div>
              <div>
                <p className="text-xs font-medium text-slate-200">
                  Production PowerShell Generator Available
                </p>
                <p className="text-xs text-slate-400">
                  On Windows 11 host: run <code className="font-mono text-emerald-300">.\generate-config.ps1 -Domain &quot;{domain}&quot;</code>
                </p>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};
