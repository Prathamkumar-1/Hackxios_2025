# 🏆 Hackxios 2K25 - PayFlow Protocol

<div align="center">

![PayFlow Protocol](https://img.shields.io/badge/PayFlow-Protocol-6366f1?style=for-the-badge&logo=ethereum&logoColor=white)
![Hackathon](https://img.shields.io/badge/Hackxios-2K25-ff6b6b?style=for-the-badge)
![Status](https://img.shields.io/badge/Status-Live%20on%20Sepolia-00d26a?style=for-the-badge)
![License](https://img.shields.io/badge/License-MIT-blue?style=for-the-badge)

### **The Missing Intelligence Layer for Institutional Stablecoin Payments**

*Where Visa's settlement meets Stripe's programmability — built for the $320 trillion cross-border era*

**🌐 [Live Demo](https://nextjs-1kd24o3my-sandys-projects-65d29ae3.vercel.app) | 📄 [Documentation](./theblocks/docs/) | 🔗 [Smart Contracts](./theblocks/packages/hardhat/contracts/)**

</div>

---

## 📋 Table of Contents

- [🎯 Problem Statement](#-problem-statement)
- [💡 Our Solution](#-our-solution)
- [🏗️ Architecture](#️-architecture)
- [✨ Key Features](#-key-features)
- [🔮 Oracle System](#-oracle-system)
- [📦 Tech Stack](#-tech-stack)
- [🚀 Getting Started](#-getting-started)
- [📁 Project Structure](#-project-structure)
- [🔒 Smart Contracts](#-smart-contracts)
- [🌐 Deployment](#-deployment)
- [👥 Team](#-team)

---

## 🎯 Problem Statement

### The $320 Trillion Cross-Border Crisis

The global cross-border payments market is exploding — from **$194.6 trillion in 2024 to a projected $320 trillion by 2032** (JPMorgan, 2025). Yet the infrastructure powering it was designed in the 1970s.

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    THE MARKET REALITY (2025)                             │
├─────────────────────────────────────────────────────────────────────────┤
│  📊 Cross-Border Market:     $194.6T → $320T by 2032 (JPMorgan)         │
│  💸 Stablecoin Volume:       $15.6T in 2024 — matching Visa (a16z)      │
│  🏦 B2B Transactions:        3.4 trillion annually, $1.8 quadrillion    │
│  ⚠️  B2B Payment Failures:   14% failure rate (programmable: 0%)        │
│  🌍 Travel Rule Countries:   85 jurisdictions enforcing in 2025         │
│  ⏱️  Settlement Time:        3-5 days (legacy) vs 12 seconds (PayFlow)  │
└─────────────────────────────────────────────────────────────────────────┘
```

### Current Problems with Traditional Systems

| Problem | Traditional Finance | PayFlow Solution |
|---------|---------------------|------------------|
| **Settlement Time** | 3-5 business days | 12 seconds |
| **Compliance Cost** | $25-50 per transaction | Near-zero (on-chain) |
| **FX Slippage Risk** | 2-5% during settlement | Oracle-locked rates |
| **Payment Failures** | 14% B2B failure rate | 0% with programmable rules |
| **Audit Trail** | Scattered, manual | Immutable, on-chain |

---

## 💡 Our Solution

### PayFlow Protocol: Programmable Cross-Border Payments

PayFlow is a **complete cross-border payment infrastructure** that combines:

1. **🛡️ Smart Compliance Engine** - 5-tier KYC verification on-chain
2. **🔮 Dual-Oracle System** - Real-time FX rates from Chainlink + Pyth
3. **🔐 Programmable Escrow** - Conditional payment release (time, approval, oracle)
4. **📝 Immutable Audit Registry** - Every transaction travel-rule compliant

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         PayFlow Protocol Stack                           │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│   🌐 Frontend (Next.js 15 + React 19)                                   │
│   ├── Interactive Dashboard                                             │
│   ├── Real-time Oracle Monitoring                                       │
│   └── Settlement Management Interface                                   │
│                                                                          │
│   📡 Oracle Layer (Chainlink 60% + Pyth 40%)                            │
│   ├── Weighted Consensus Aggregation                                    │
│   ├── Circuit Breakers & Staleness Detection                           │
│   └── Flash Loan Attack Protection                                      │
│                                                                          │
│   ⛓️ Smart Contract Layer (Solidity 0.8.x)                              │
│   ├── PayFlowCore.sol - Payment processing engine                       │
│   ├── ComplianceEngine.sol - 5-tier KYC verification                   │
│   ├── SmartEscrow.sol - Programmable conditional escrow                │
│   ├── OracleAggregator.sol - Multi-oracle price feeds                  │
│   └── AuditRegistry.sol - Immutable audit logging                      │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 🏗️ Architecture

### System Flow

```
User Request → Compliance Check → Oracle Price Lock → Escrow Creation → Settlement
     │              │                    │                  │              │
     ▼              ▼                    ▼                  ▼              ▼
┌─────────┐  ┌──────────────┐  ┌─────────────────┐  ┌───────────┐  ┌──────────┐
│ Web3    │  │ Compliance   │  │ Chainlink (60%) │  │  Smart    │  │  Audit   │
│ Wallet  │→ │ Engine       │→ │ Pyth (40%)      │→ │  Escrow   │→ │ Registry │
│         │  │ (5 Tiers)    │  │ Aggregation     │  │           │  │          │
└─────────┘  └──────────────┘  └─────────────────┘  └───────────┘  └──────────┘
```

### Contract Deployment (Sepolia Testnet)

| Contract | Address | Purpose |
|----------|---------|---------|
| PayFlowCore | `0x...` | Main payment processing |
| ComplianceEngine | `0x...` | KYC tier management |
| SmartEscrow | `0x...` | Conditional payments |
| OracleAggregator | `0x...` | Price feed aggregation |
| AuditRegistry | `0x...` | Immutable logging |

---

## ✨ Key Features

### 1. 🛡️ 5-Tier Compliance System

```solidity
enum ComplianceTier {
    NONE,           // Tier 0: No verification
    BASIC,          // Tier 1: Email verification
    STANDARD,       // Tier 2: KYC documents
    ENHANCED,       // Tier 3: Enhanced due diligence
    INSTITUTIONAL   // Tier 4: Full institutional compliance
}
```

Each tier unlocks higher transaction limits and enables cross-border institutional payments.

### 2. 🔮 Dual-Oracle Price Aggregation

Our production-ready oracle system uses **weighted consensus**:

- **Chainlink (60% weight)**: Industry-standard, high reliability
- **Pyth Network (40% weight)**: Sub-second updates, real-time pricing

```typescript
// Real-time price aggregation
const aggregatedPrice = chainlinkPrice * 0.6 + pythPrice * 0.4;
const confidence = calculateConfidence(chainlinkAge, pythAge, deviation);
```

**Protection Features:**
- ⏱️ Staleness detection (1 hour for Chainlink, 1 minute for Pyth)
- 📊 5% deviation circuit breakers
- 🔒 Flash loan attack prevention
- 🔄 Automatic fallback to backup oracles

### 3. 🔐 Programmable Escrow

Four release mechanisms for enterprise use cases:

| Type | Use Case | Example |
|------|----------|---------|
| `TIME_BASED` | Supply chain payments | Release after delivery window |
| `APPROVAL` | Service contracts | Beneficiary signs off |
| `ORACLE` | IoT/GPS verification | External data triggers |
| `MULTI_SIG` | Corporate treasury | M-of-N approval required |

### 4. 📝 Immutable Audit Trail

Every transaction logged with:
- Sender/receiver compliance tiers
- Oracle prices at execution time
- Compliance check results
- Travel Rule data hashes

---

## 🔮 Oracle System

### Supported Price Feeds

**Chainlink Sepolia Feeds:**
- ETH/USD, BTC/USD, LINK/USD
- EUR/USD, GBP/USD, JPY/USD
- DAI/USD, USDC/USD

**Pyth Network Feeds:**
- ETH/USD, BTC/USD, SOL/USD, AVAX/USD
- MATIC/USD, DOT/USD, ATOM/USD
- USDC/USD, USDT/USD, DAI/USD

### Oracle Aggregation Service

```typescript
// packages/nextjs/services/oracleAggregatorService.ts
export async function getAggregatedPrice(symbol: string): Promise<AggregatedPrice> {
  const [chainlinkData, pythData] = await Promise.all([
    fetchChainlinkPrice(symbol),
    fetchPythPrice(symbol)
  ]);
  
  // Weighted average: 60% Chainlink, 40% Pyth
  const aggregatedPrice = chainlinkData.price * 0.6 + pythData.price * 0.4;
  
  return {
    price: aggregatedPrice,
    confidence: calculateConfidence(chainlinkData, pythData),
    sources: { chainlink: chainlinkData, pyth: pythData }
  };
}
```

---

## 📦 Tech Stack

### Frontend
- **Framework**: Next.js 15.2.6 + React 19
- **Styling**: Tailwind CSS + DaisyUI 5.0
- **Web3**: wagmi + viem + RainbowKit
- **Animations**: Framer Motion

### Smart Contracts
- **Language**: Solidity 0.8.x
- **Framework**: Hardhat
- **Libraries**: OpenZeppelin Contracts
- **Testing**: Chai + Mocha

### Blockchain
- **Testnet**: Sepolia (Ethereum)
- **Oracles**: Chainlink + Pyth Network
- **Wallet Support**: MetaMask, WalletConnect, Coinbase Wallet

### Deployment
- **Frontend**: Vercel
- **Contracts**: Hardhat Deploy

---

## 🚀 Getting Started

### Prerequisites

- Node.js 18+
- Yarn (v1 or v4)
- Git

### Installation

```bash
# Clone the repository
git clone https://github.com/shubro18202758/Hackxios_2025.git
cd Hackxios_2025/theblocks

# Install dependencies
yarn install

# Start local blockchain (Terminal 1)
yarn chain

# Deploy contracts (Terminal 2)
yarn deploy

# Start frontend (Terminal 3)
yarn start
```

### Environment Variables

Create `.env.local` in `packages/nextjs/`:

```env
NEXT_PUBLIC_ALCHEMY_API_KEY=your_alchemy_key
NEXT_PUBLIC_WALLET_CONNECT_PROJECT_ID=your_wc_project_id
```

---

## 📁 Project Structure

```
Hackxios/
└── theblocks/
    ├── packages/
    │   ├── hardhat/           # Smart contracts
    │   │   ├── contracts/     # Solidity contracts
    │   │   ├── deploy/        # Deployment scripts
    │   │   ├── scripts/       # Utility scripts
    │   │   └── test/          # Contract tests
    │   │
    │   └── nextjs/            # Frontend application
    │       ├── app/           # Next.js app router
    │       ├── components/    # React components
    │       ├── config/        # Configuration files
    │       ├── hooks/         # Custom React hooks
    │       └── services/      # API services
    │
    ├── docs/                  # Documentation
    │   ├── ARCHITECTURE.md
    │   ├── SECURITY_ANALYSIS.md
    │   ├── GAS_OPTIMIZATION.md
    │   └── DEPLOYMENT_GUIDE.md
    │
    └── README.md              # Project documentation
```

---

## 🔒 Smart Contracts

### Core Contracts

| Contract | Description | Key Functions |
|----------|-------------|---------------|
| **PayFlowCore.sol** | Main payment engine | `createPayment()`, `executePayment()` |
| **ComplianceEngine.sol** | KYC tier management | `verifyTier()`, `updateComplianceStatus()` |
| **SmartEscrow.sol** | Conditional payments | `createEscrow()`, `releaseEscrow()` |
| **OracleAggregator.sol** | Price feed aggregation | `getLatestPrice()`, `getAggregatedPrice()` |
| **AuditRegistry.sol** | Immutable logging | `logEvent()`, `getAuditTrail()` |

### Security Features

- ✅ ReentrancyGuard on all state-changing functions
- ✅ Access control with OpenZeppelin roles
- ✅ Pausable emergency stops
- ✅ Oracle staleness checks
- ✅ Slippage protection

---

## 🌐 Deployment

### Live Deployments

| Network | Frontend URL |
|---------|--------------|
| **Sepolia** | [https://nextjs-1kd24o3my-sandys-projects-65d29ae3.vercel.app](https://nextjs-1kd24o3my-sandys-projects-65d29ae3.vercel.app) |

### Deploy Your Own

```bash
# Deploy to Sepolia
cd packages/hardhat
npx hardhat deploy --network sepolia

# Deploy frontend to Vercel
cd packages/nextjs
vercel --prod
```

---

## 📊 Hackathon Tracks

This project addresses multiple hackathon themes:

- **🏦 DeFi**: Programmable cross-border payments
- **🔗 Infrastructure**: Multi-oracle aggregation layer
- **🛡️ Security**: On-chain compliance and audit trails
- **🌍 Real World Assets**: Institutional stablecoin settlements

---

## 🎥 Demo

### Key Pages

1. **Dashboard** (`/dashboard`) - Main payment interface with real-time data
2. **Oracle Dashboard** (`/oracle-dashboard`) - Live oracle feeds and consensus
3. **Settlement Monitor** - Track payment lifecycle
4. **Debug Contracts** (`/debug`) - Interact with deployed contracts

---

## 📄 Documentation

Detailed documentation available in `/theblocks/docs/`:

- [Architecture Overview](./theblocks/docs/ARCHITECTURE.md)
- [Security Analysis](./theblocks/docs/SECURITY_ANALYSIS.md)
- [Gas Optimization](./theblocks/docs/GAS_OPTIMIZATION.md)
- [Deployment Guide](./theblocks/docs/DEPLOYMENT_GUIDE.md)
- [Threat Model](./theblocks/docs/THREAT_MODEL.md)

---

## 👥 Team

**Team: The Blocks**

Built with ❤️ for Hackxios 2K25

---

## 📜 License

This project is licensed under the MIT License - see the [LICENSE](./theblocks/LICENSE) file for details.

---

<div align="center">

### 🚀 Ready to revolutionize cross-border payments?

**[Try the Live Demo →](https://nextjs-1kd24o3my-sandys-projects-65d29ae3.vercel.app)**

</div>
