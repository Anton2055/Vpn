import React, { useState } from 'react';
import { DIAGNOSTICS } from '../data';
import { AlertCircle, Terminal, CheckCircle, Search, Filter } from 'lucide-react';

export const DiagnosticsTroubleshooter: React.FC = () => {
  const [selectedCategory, setSelectedCategory] = useState<string>('All');
  const [searchQuery, setSearchQuery] = useState<string>('');

  const categories = ['All', 'Cloudflare', 'Mobile / Cellular', 'Orange Pi / Hardware', 'Xray Core'];

  const filteredItems = DIAGNOSTICS.filter((item) => {
    const matchesCategory = selectedCategory === 'All' || item.category === selectedCategory;
    const matchesSearch =
      item.symptom.toLowerCase().includes(searchQuery.toLowerCase()) ||
      item.remedy.toLowerCase().includes(searchQuery.toLowerCase());
    return matchesCategory && matchesSearch;
  });

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-xl font-semibold text-slate-900 tracking-tight">
          Diagnostics & Network Troubleshooting Matrix
        </h2>
        <p className="text-sm text-slate-600 mt-1">
          Detailed symptom-cause-investigation-remedy matrix for resolving mobile drops, idle timeouts, Cloudflare error codes, and hardware limits.
        </p>
      </div>

      {/* Filter and Search Bar */}
      <div className="flex flex-col sm:flex-row gap-3 items-center justify-between">
        <div className="flex items-center space-x-1 overflow-x-auto w-full sm:w-auto pb-1 sm:pb-0 scrollbar-none">
          {categories.map((cat) => (
            <button
              key={cat}
              id={`filter-cat-${cat.replace(/[\s/]/g, '')}`}
              onClick={() => setSelectedCategory(cat)}
              className={`px-3 py-1.5 rounded-lg text-xs font-medium whitespace-nowrap transition-colors cursor-pointer ${
                selectedCategory === cat
                  ? 'bg-slate-900 text-white'
                  : 'bg-white text-slate-600 border border-slate-200 hover:bg-slate-50'
              }`}
            >
              {cat}
            </button>
          ))}
        </div>

        <div className="relative w-full sm:w-64">
          <Search className="w-4 h-4 absolute left-3 top-2.5 text-slate-400" />
          <input
            id="search-diagnostics"
            type="text"
            placeholder="Search symptoms or remedies..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            className="w-full pl-9 pr-3 py-1.5 text-xs rounded-lg border border-slate-200 bg-white text-slate-800 focus:outline-hidden focus:ring-1 focus:ring-slate-900"
          />
        </div>
      </div>

      {/* Diagnostics List */}
      <div className="space-y-4">
        {filteredItems.map((item) => (
          <div
            key={item.id}
            id={`diag-${item.id}`}
            className="bg-white rounded-xl border border-slate-200 p-5 shadow-xs space-y-3"
          >
            <div className="flex items-start justify-between">
              <div className="flex items-start space-x-3">
                <AlertCircle className="w-5 h-5 text-amber-500 shrink-0 mt-0.5" />
                <div>
                  <h3 className="text-sm font-semibold text-slate-900">{item.symptom}</h3>
                  <span className="inline-block mt-1 text-xs font-medium px-2 py-0.5 rounded-full bg-slate-100 text-slate-600 border border-slate-200">
                    {item.category}
                  </span>
                </div>
              </div>
            </div>

            <div className="pl-8 space-y-2 text-xs">
              <div>
                <span className="font-semibold text-slate-700 block mb-1">Underlying Causes:</span>
                <ul className="list-disc list-inside text-slate-600 space-y-0.5">
                  {item.possibleCauses.map((cause, i) => (
                    <li key={i}>{cause}</li>
                  ))}
                </ul>
              </div>

              <div>
                <span className="font-semibold text-slate-700 block mb-1">
                  Investigation Command:
                </span>
                <pre className="font-mono bg-slate-900 text-emerald-400 p-2 rounded-md overflow-x-auto">
                  {item.verificationCommand}
                </pre>
              </div>

              <div className="p-3 bg-emerald-50 rounded-lg border border-emerald-200 text-emerald-900">
                <span className="font-semibold block mb-0.5 flex items-center">
                  <CheckCircle className="w-3.5 h-3.5 mr-1 text-emerald-700" />
                  Remedy & Fix Action:
                </span>
                <p className="text-emerald-800">{item.remedy}</p>
              </div>
            </div>
          </div>
        ))}

        {filteredItems.length === 0 && (
          <div className="p-8 text-center bg-white rounded-xl border border-slate-200 text-slate-500 text-sm">
            No diagnostic issues match your filter criteria.
          </div>
        )}
      </div>
    </div>
  );
};
