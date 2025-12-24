"use client";

import { TokenPrice } from "./priceService";

export interface RiskAnalysis {
  score: number; // 0 to 100
  verdict: "APPROVE" | "FLAG" | "BLOCK";
  reason: string;
  suggestedAction: string;
}

/**
 * @title AI Settlement Agent
 * @notice Simulates an AI agent that monitors compliance & oracle health
 */
export const analyzePaymentRisk = (
  amount: number,
  tokenPrice: TokenPrice,
  complianceTier: number,
  isCrossBorder: boolean
): RiskAnalysis => {
  let riskScore = 0;
  let reasons: string[] = [];

  // 1. Check Oracle Health (The "Visa" Security logic)
  if (tokenPrice.isDepegged) {
    riskScore += 60;
    reasons.push("Stablecoin de-peg detected via Dual-Oracle consensus.");
  }

  // 2. Check Compliance Match (The "Institutional" logic)
  if (amount > 10000 && complianceTier < 3) {
    riskScore += 40;
    reasons.push("High-value transaction exceeds Tier 2 limits.");
  }

  // 3. Logic for Cross-Border
  if (isCrossBorder && complianceTier < 2) {
    riskScore += 30;
    reasons.push("International payment requires standard KYC (Tier 2).");
  }

  // Determine Verdict
  let verdict: "APPROVE" | "FLAG" | "BLOCK" = "APPROVE";
  if (riskScore >= 70) verdict = "BLOCK";
  else if (riskScore >= 30) verdict = "FLAG";

  return {
    score: riskScore,
    verdict,
    reason: reasons.join(" "),
    suggestedAction: verdict === "BLOCK" ? "Upgrade KYC or wait for price stability." : "Proceed with caution."
  };
};
