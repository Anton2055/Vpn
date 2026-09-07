import React from 'react';
import { PROFILES } from '../data';
import { Shield, Zap, Globe, Radio, CheckCircle2 } from 'lucide-react';

interface ProfileMatrixProps {
  onSelectForGenerator?: (code: string) => void;
}

export const ProfileMatrix: React.FC<ProfileMatrixProps> = ({ onSelectForGenerator }) => {
  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-xl font-semibold text-slate-900 tracking-tight">
          3-Layer Resilience Transport Architecture
        </h2>
        <p className="text-sm text-slate-600 mt-1">
          Each profile targets a distinct failure domain, ensuring uninterrupted connectivity across cellular LTE/5G handoffs, carrier deep packet inspection, and CGNAT residential networks.
        </p>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 gap-5">
        {PROFILES.map((profile) => {
          const isDirect = profile.code === 'A';
          const isZeroTier = profile.code === 'C';

          return (
            <div
              key={profile.id}
              id={`card-${profile.id}`}
              className="bg-white rounded-xl border border-slate-200 p-5 shadow-xs hover:border-slate-300 transition-all flex flex-col justify-between"
            >
              <div>
                <div className="flex items-start justify-between">
                  <div className="flex items-center space-x-2.5">
                    <span className="w-8 h-8 rounded-lg bg-slate-100 border border-slate-200 flex items-center justify-center font-mono font-bold text-slate-900 text-sm">
                      {profile.code}
                    </span>
                    <div>
                      <h3 className="font-semibold text-slate-900 text-base leading-snug">
                        {profile.name}
                      </h3>
                      <p className="text-xs text-slate-500 font-mono">
                        Port {profile.port} · {profile.transport}
                      </p>
                    </div>
                  </div>

                  <span
                    className={`text-xs px-2 py-0.5 rounded-full font-medium border ${
                      profile.stealthRating === 'Extreme'
                        ? 'bg-purple-50 text-purple-700 border-purple-200'
                        : profile.stealthRating === 'Very High'
                        ? 'bg-emerald-50 text-emerald-700 border-emerald-200'
                        : profile.stealthRating === 'High'
                        ? 'bg-blue-50 text-blue-700 border-blue-200'
                        : 'bg-amber-50 text-amber-700 border-amber-200'
                    }`}
                  >
                    {profile.stealthRating} Stealth
                  </span>
                </div>

                <div className="mt-4 space-y-2 text-xs text-slate-600">
                  <div className="flex items-center space-x-2">
                    <Globe className="w-3.5 h-3.5 text-slate-400 shrink-0" />
                    <span>
                      <strong className="text-slate-800">Target Host:</strong> {profile.targetHost}
                    </span>
                  </div>
                  <div className="flex items-center space-x-2">
                    <Shield className="w-3.5 h-3.5 text-slate-400 shrink-0" />
                    <span>
                      <strong className="text-slate-800">Security Layer:</strong> {profile.security}
                    </span>
                  </div>
                  <div className="flex items-center space-x-2">
                    <Radio className="w-3.5 h-3.5 text-slate-400 shrink-0" />
                    <span>
                      <strong className="text-slate-800">Traversal:</strong> {profile.natTraversal}
                    </span>
                  </div>
                  <div className="flex items-center space-x-2">
                    <Zap className="w-3.5 h-3.5 text-slate-400 shrink-0" />
                    <span>
                      <strong className="text-slate-800">Latency:</strong> {profile.latencyExpectation}
                    </span>
                  </div>
                </div>

                <div className="mt-4 p-3 bg-slate-50 rounded-lg border border-slate-100 text-xs text-slate-700">
                  <span className="font-medium text-slate-900 block mb-0.5">Operational Purpose:</span>
                  {profile.bestFor}
                </div>
              </div>

              <div className="mt-5 pt-3 border-t border-slate-100 flex items-center justify-between">
                <span className="text-xs text-slate-500">
                  {isDirect
                    ? 'Official Reality Protocol'
                    : isZeroTier
                    ? 'Independent L3 Mesh'
                    : 'Anycast CDN Obfuscation'}
                </span>
                {onSelectForGenerator && (
                  <button
                    id={`btn-use-${profile.id}`}
                    onClick={() => onSelectForGenerator(profile.code)}
                    className="text-xs font-medium text-blue-600 hover:text-blue-800 flex items-center space-x-1 cursor-pointer"
                  >
                    <span>Configure in Generator</span>
                    <span>&rarr;</span>
                  </button>
                )}
              </div>
            </div>
          );
        })}
      </div>

      <div className="bg-slate-900 text-white rounded-xl p-5 border border-slate-800">
        <h3 className="text-sm font-semibold tracking-wide uppercase text-slate-400 mb-2">
          Automated Failover Logic (Client Side in HAPP)
        </h3>
        <p className="text-xs sm:text-sm text-slate-300 leading-relaxed">
          The HAPP Android client should import all 4 profiles into a fallback group. Priority order:
          <span className="text-emerald-400 font-mono font-medium ml-1">Profile A (Direct VPS)</span> &rarr;
          <span className="text-blue-400 font-mono font-medium ml-1">Profile B1 (Cloudflare WS)</span> &rarr;
          <span className="text-purple-400 font-mono font-medium ml-1">Profile B2 (Cloudflare XHTTP)</span> &rarr;
          <span className="text-amber-400 font-mono font-medium ml-1">Profile C (ZeroTier Emergency)</span>.
          When cell tower switches cause socket drops, the client automatically re-routes traffic through the next available healthy channel.
        </p>
      </div>
    </div>
  );
};
