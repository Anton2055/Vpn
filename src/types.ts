export type Platform = 'windows' | 'vps' | 'orangepi';

export interface ProxyProfile {
  id: string;
  name: string;
  code: 'A' | 'B1' | 'B2' | 'C';
  protocol: string;
  transport: string;
  security: string;
  port: number | string;
  targetHost: string;
  stealthRating: 'Very High' | 'High' | 'Medium' | 'Extreme';
  natTraversal: 'Direct (Requires Public IP)' | 'Cloudflare Tunnel (No Port Forwarding)' | 'ZeroTier L3 Mesh';
  bestFor: string;
  latencyExpectation: string;
  details: string;
}

export interface DiagnosticItem {
  id: string;
  category: 'Cloudflare' | 'Mobile / Cellular' | 'Orange Pi / Hardware' | 'Xray Core';
  symptom: string;
  possibleCauses: string[];
  verificationCommand: string;
  remedy: string;
}

export interface ThreatItem {
  threat: string;
  mitigated: boolean | 'Partial';
  mitigationMechanism: string;
  limitations: string;
}
