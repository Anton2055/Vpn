import React from 'react';
import { ShieldCheck, Network, Cpu, Terminal, AlertTriangle, Key } from 'lucide-react';

interface HeaderProps {
  activeTab: string;
  setActiveTab: (tab: string) => void;
}

export const Header: React.FC<HeaderProps> = ({ activeTab, setActiveTab }) => {
  const tabs = [
    { id: 'profiles', label: 'Resilience Profiles', icon: Network },
    { id: 'generator', label: 'HAPP URI Generator', icon: Key },
    { id: 'deployment', label: 'Deploy & Scripts', icon: Terminal },
    { id: 'diagnostics', label: 'Diagnostics Matrix', icon: AlertTriangle },
    { id: 'threat', label: 'Threat & DPI Model', icon: ShieldCheck },
  ];

  return (
    <header className="border-b border-slate-200 bg-white sticky top-0 z-30 shadow-xs">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="flex items-center justify-between h-16">
          <div className="flex items-center space-x-3">
            <div className="w-10 h-10 rounded-xl bg-slate-900 flex items-center justify-center text-white shadow-xs">
              <Network className="w-5 h-5 text-emerald-400" />
            </div>
            <div>
              <div className="flex items-center space-x-2">
                <span className="font-semibold text-slate-900 tracking-tight text-base sm:text-lg">
                  Mobile Network Resilience
                </span>
                <span className="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium bg-emerald-50 text-emerald-700 border border-emerald-200">
                  <ShieldCheck className="w-3 h-3 mr-1" />
                  Tests 100% Passed
                </span>
              </div>
              <p className="text-xs text-slate-500 hidden sm:block">
                Xray + Cloudflare Tunnel + ZeroTier Multi-Profile Mesh
              </p>
            </div>
          </div>

          <div className="flex items-center space-x-2">
            <span className="hidden md:inline-flex items-center px-2.5 py-1 rounded-md text-xs font-mono bg-slate-100 text-slate-700 border border-slate-200">
              <Cpu className="w-3.5 h-3.5 mr-1.5 text-slate-500" />
              Windows · Linux VPS · Orange Pi
            </span>
          </div>
        </div>

        {/* Navigation Tabs */}
        <nav className="flex space-x-1 sm:space-x-4 overflow-x-auto py-2 border-t border-slate-100 scrollbar-none">
          {tabs.map((tab) => {
            const Icon = tab.icon;
            const isActive = activeTab === tab.id;
            return (
              <button
                key={tab.id}
                id={`tab-${tab.id}`}
                onClick={() => setActiveTab(tab.id)}
                className={`flex items-center space-x-1.5 px-3 py-1.5 rounded-lg text-xs sm:text-sm font-medium transition-colors whitespace-nowrap cursor-pointer ${
                  isActive
                    ? 'bg-slate-900 text-white shadow-xs'
                    : 'text-slate-600 hover:text-slate-900 hover:bg-slate-100'
                }`}
              >
                <Icon className={`w-4 h-4 ${isActive ? 'text-emerald-400' : 'text-slate-500'}`} />
                <span>{tab.label}</span>
              </button>
            );
          })}
        </nav>
      </div>
    </header>
  );
};
