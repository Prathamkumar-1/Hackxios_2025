import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";

/**
 * PayFlow Protocol Deployment
 * 
 * Deploys the complete PayFlow Protocol stack:
 * 1. AuditRegistry - Immutable audit logging
 * 2. OracleAggregator - FX rate aggregation
 * 3. ComplianceEngine - KYC/AML/Sanctions
 * 4. SmartEscrow - Programmable escrow
 * 5. PayFlowCore - Central routing engine
 */
const deployPayFlowProtocol: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployer } = await hre.getNamedAccounts();
  const { deploy } = hre.deployments;

  console.log("\n╔══════════════════════════════════════════════════════════════╗");
  console.log("║           PAYFLOW PROTOCOL DEPLOYMENT                        ║");
  console.log("║     Programmable Money Rails for Institutional Payments      ║");
  console.log("╚══════════════════════════════════════════════════════════════╝\n");

  console.log(`📍 Deployer: ${deployer}`);
  console.log(`🌐 Network: ${hre.network.name}\n`);

  // 1. Deploy AuditRegistry
  console.log("1️⃣  Deploying AuditRegistry...");
  const auditRegistry = await deploy("AuditRegistry", {
    from: deployer,
    args: [],
    log: true,
    autoMine: true,
  });
  console.log(`   ✅ AuditRegistry: ${auditRegistry.address}\n`);

  // 2. Deploy OracleAggregator
  console.log("2️⃣  Deploying OracleAggregator...");
  const oracleAggregator = await deploy("OracleAggregator", {
    from: deployer,
    args: [],
    log: true,
    autoMine: true,
  });
  console.log(`   ✅ OracleAggregator: ${oracleAggregator.address}\n`);

  // 3. Deploy ComplianceEngine
  console.log("3️⃣  Deploying ComplianceEngine...");
  const complianceEngine = await deploy("ComplianceEngine", {
    from: deployer,
    args: [],
    log: true,
    autoMine: true,
  });
  console.log(`   ✅ ComplianceEngine: ${complianceEngine.address}\n`);

  // 4. Deploy SmartEscrow
  console.log("4️⃣  Deploying SmartEscrow...");
  const smartEscrow = await deploy("SmartEscrow", {
    from: deployer,
    args: [],
    log: true,
    autoMine: true,
  });
  console.log(`   ✅ SmartEscrow: ${smartEscrow.address}\n`);

  // 5. Deploy PayFlowCore
  console.log("5️⃣  Deploying PayFlowCore...");
  const payFlowCore = await deploy("PayFlowCore", {
    from: deployer,
    args: [],
    log: true,
    autoMine: true,
  });
  console.log(`   ✅ PayFlowCore: ${payFlowCore.address}\n`);

  // Configuration
  console.log("⚙️  Configuring protocol connections...\n");

  // Get contract instances for configuration
  const PayFlowCore = await hre.ethers.getContractAt("PayFlowCore", payFlowCore.address);
  const SmartEscrow = await hre.ethers.getContractAt("SmartEscrow", smartEscrow.address);
  const AuditRegistry = await hre.ethers.getContractAt("AuditRegistry", auditRegistry.address);

  // Configure PayFlowCore with all modules at once
  console.log("   📎 Connecting PayFlowCore to modules...");
  const tx1 = await PayFlowCore.setModules(
    complianceEngine.address,
    oracleAggregator.address,
    smartEscrow.address,
    auditRegistry.address
  );
  await tx1.wait(2); // Wait for 2 confirmations
  console.log("   ✅ PayFlowCore configured\n");

  // Configure SmartEscrow
  console.log("   📎 Connecting SmartEscrow to PayFlowCore...");
  const tx2 = await SmartEscrow.setPayFlowCore(payFlowCore.address);
  await tx2.wait(2);
  console.log("   ✅ SmartEscrow configured\n");

  // Authorize PayFlowCore as logger in AuditRegistry
  console.log("   📎 Authorizing PayFlowCore as audit logger...");
  const tx3 = await AuditRegistry.authorizeLogger(payFlowCore.address);
  await tx3.wait(2);
  console.log("   ✅ AuditRegistry configured\n");

  // Deployment Summary
  console.log("\n╔══════════════════════════════════════════════════════════════╗");
  console.log("║           DEPLOYMENT COMPLETE                                 ║");
  console.log("╚══════════════════════════════════════════════════════════════╝\n");

  console.log("📋 Contract Addresses:");
  console.log("─────────────────────────────────────────────────────────────────");
  console.log(`   PayFlowCore:      ${payFlowCore.address}`);
  console.log(`   ComplianceEngine: ${complianceEngine.address}`);
  console.log(`   SmartEscrow:      ${smartEscrow.address}`);
  console.log(`   OracleAggregator: ${oracleAggregator.address}`);
  console.log(`   AuditRegistry:    ${auditRegistry.address}`);
  console.log("─────────────────────────────────────────────────────────────────\n");

  console.log("🚀 PayFlow Protocol is ready for institutional payments!");
  console.log("   💰 Process $10M in 12 seconds with full compliance\n");
};

export default deployPayFlowProtocol;
deployPayFlowProtocol.tags = ["PayFlowProtocol"];
