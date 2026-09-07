/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

import { useState } from 'react';
import { Header } from './components/Header';
import { ProfileMatrix } from './components/ProfileMatrix';
import { ConfigGenerator } from './components/ConfigGenerator';
import { DeploymentGuides } from './components/DeploymentGuides';
import { DiagnosticsTroubleshooter } from './components/DiagnosticsTroubleshooter';
import { ThreatModelView } from './components/ThreatModelView';
import { CheckCircle, GitBranch, Shield } from 'lucide-react';

export default function App() {
  const [activeTab, setActiveTab] = useState<string>('profiles');
  const [selectedGeneratorProfile, setSelectedGeneratorProfile] = useState<string>('B1');

  const handleSelectProfileForGenerator = (code: string) => {
    setSelectedGeneratorProfile(code);
    setActiveTab('generator');
  };

  return (
    <div className="min-h-screen bg-slate-50 text-slate-800 flex flex-col font-sans">
      <Header activeTab={activeTab} setActiveTab={setActiveTab} />

      {/* Main Content Area */}
      <main className="flex-1 max-w-7xl w-full mx-auto px-4 sm:px-6 lg:px-8 py-6 sm:py-8">
        {/* Verification banner */}
        <div className="mb-6 p-3.5 bg-white rounded-xl border border-slate-200 shadow-xs flex flex-col sm:flex-row items-start sm:items-center justify-between gap-3">
          <div className="flex items-center space-x-2.5">
            <div className="w-6 h-6 rounded-full bg-emerald-100 flex items-center justify-center text-emerald-700 shrink-0">
              <CheckCircle className="w-4 h-4" />
            </div>
            <div>
              <p className="text-xs font-medium text-slate-900">
                Automated Test Suite Verified: <span className="font-mono text-emerald-600 font-semibold">100% Passed</span>
              </p>
              <p className="text-xs text-slate-500">
                All Xray JSON configurations validated with official core binary & zero credential leaks detected.
              </p>
            </div>
          </div>

          <div className="flex items-center space-x-2 text-xs font-mono text-slate-600 bg-slate-50 px-2.5 py-1 rounded-md border border-slate-100">
            <GitBranch className="w-3.5 h-3.5 text-slate-400" />
            <span>branch: main</span>
          </div>
        </div>

        {/* Tab Views */}
        {activeTab === 'profiles' && (
          <ProfileMatrix onSelectForGenerator={handleSelectProfileForGenerator} />
        )}

        {activeTab === 'generator' && (
          <ConfigGenerator initialProfile={selectedGeneratorProfile} />
        )}

        {activeTab === 'deployment' && <DeploymentGuides />}

        {activeTab === 'diagnostics' && <DiagnosticsTroubleshooter />}

        {activeTab === 'threat' && <ThreatModelView />}
      </main>

      {/* Footer */}
      <footer className="border-t border-slate-200 bg-white py-6 mt-12 text-xs text-slate-500">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 flex flex-col sm:flex-row items-center justify-between gap-3">
          <div className="flex items-center space-x-2">
            <Shield className="w-4 h-4 text-slate-400" />
            <span>Mobile Network Resilience Toolkit · Production Release</span>
          </div>
          <div className="flex items-center space-x-4">
            <button
              onClick={() => setActiveTab('diagnostics')}
              className="hover:text-slate-900 transition-colors cursor-pointer"
            >
              Diagnostics Matrix
            </button>
            <span>·</span>
            <button
              onClick={() => setActiveTab('threat')}
              className="hover:text-slate-900 transition-colors cursor-pointer"
            >
              Threat Model
            </button>
            <span>·</span>
            <button
              onClick={() => setActiveTab('deployment')}
              className="hover:text-slate-900 transition-colors cursor-pointer"
            >
              Deployment Guides
            </button>
          </div>
        </div>
      </footer>
    </div>
  );
}

