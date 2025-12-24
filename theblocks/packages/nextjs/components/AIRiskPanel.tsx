import React from 'react';
import { analyzePaymentRisk } from '../services/aiAgentService';
import { TokenPrice } from '../services/priceService';

interface AIRiskPanelProps {
  amount: number;
  tokenPrice: TokenPrice;
  complianceTier: number;
  isCrossBorder: boolean;
}

export const AIRiskPanel = ({ amount, tokenPrice, complianceTier, isCrossBorder }: AIRiskPanelProps) => {
  const analysis = analyzePaymentRisk(amount, tokenPrice, complianceTier, isCrossBorder);

  const getStatusColor = () => {
    if (analysis.verdict === 'BLOCK') return 'border-red-500 text-red-400 bg-red-900/20';
    if (analysis.verdict === 'FLAG') return 'border-yellow-500 text-yellow-400 bg-yellow-900/20';
    return 'border-green-500 text-green-400 bg-green-900/20';
  };

  return (
    <div className={`p-4 rounded-xl border-2 ${getStatusColor()} transition-all duration-500`}>
      <div className="flex items-center justify-between mb-3">
        <h3 className="font-bold flex items-center gap-2">
          <span className="animate-pulse">🤖</span> PayFlow AI Agent
        </h3>
        <span className="text-xs font-mono px-2 py-1 rounded bg-black/40">
          Risk Score: {analysis.score}/100
        </span>
      </div>

      <div className="space-y-2 text-sm">
        <p className="font-semibold uppercase tracking-wider text-[10px] opacity-70">Analysis Verdict</p>
        <p className="text-lg font-bold">{analysis.verdict} SETTLEMENT</p>
        
        <div className="bg-black/20 p-2 rounded italic text-xs">
          "{analysis.reason}"
        </div>

        <div className="mt-4 pt-3 border-t border-white/10">
          <p className="text-[10px] uppercase opacity-60">Agent Suggestion</p>
          <p className="font-medium text-white">{analysis.suggestedAction}</p>
        </div>
      </div>
    </div>
  );
};
