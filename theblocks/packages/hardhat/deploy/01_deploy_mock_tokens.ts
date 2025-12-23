import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";

/**
 * Deploy Mock Tokens for Testing PayFlow Protocol
 * 
 * Deploys:
 * - MockUSDC - USD Coin mock (6 decimals)
 * - MockUSDT - Tether mock (6 decimals)
 * - MockEURC - Euro Coin mock (6 decimals)
 */
const deployMockTokens: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployer } = await hre.getNamedAccounts();
  const { deploy } = hre.deployments;

  console.log("\n💎 Deploying Mock Tokens for PayFlow Protocol Testing...\n");

  // Deploy MockUSDC
  console.log("1️⃣  Deploying MockUSDC...");
  const mockUSDC = await deploy("MockUSDC", {
    from: deployer,
    contract: "MockERC20",
    args: ["USD Coin", "USDC", 6],
    log: true,
    autoMine: true,
  });
  console.log(`   ✅ MockUSDC: ${mockUSDC.address}\n`);

  // Deploy MockUSDT
  console.log("2️⃣  Deploying MockUSDT...");
  const mockUSDT = await deploy("MockUSDT", {
    from: deployer,
    contract: "MockERC20",
    args: ["Tether USD", "USDT", 6],
    log: true,
    autoMine: true,
  });
  console.log(`   ✅ MockUSDT: ${mockUSDT.address}\n`);

  // Deploy MockEURC
  console.log("3️⃣  Deploying MockEURC...");
  const mockEURC = await deploy("MockEURC", {
    from: deployer,
    contract: "MockERC20",
    args: ["Euro Coin", "EURC", 6],
    log: true,
    autoMine: true,
  });
  console.log(`   ✅ MockEURC: ${mockEURC.address}\n`);

  // Mint initial supply to deployer for testing
  const INITIAL_SUPPLY = 100_000_000n * 10n ** 6n; // 100M tokens

  const MockUSDC = await hre.ethers.getContractAt("MockERC20", mockUSDC.address);
  const MockUSDT = await hre.ethers.getContractAt("MockERC20", mockUSDT.address);
  const MockEURC = await hre.ethers.getContractAt("MockERC20", mockEURC.address);

  console.log("🪙 Minting initial supply to deployer...");
  const tx1 = await MockUSDC.mint(deployer, INITIAL_SUPPLY);
  await tx1.wait(1);
  const tx2 = await MockUSDT.mint(deployer, INITIAL_SUPPLY);
  await tx2.wait(1);
  const tx3 = await MockEURC.mint(deployer, INITIAL_SUPPLY);
  await tx3.wait(1);
  console.log(`   ✅ Minted 100M of each token to ${deployer}\n`);

  console.log("📋 Mock Token Addresses:");
  console.log("─────────────────────────────────────────────────────────────────");
  console.log(`   MockUSDC: ${mockUSDC.address}`);
  console.log(`   MockUSDT: ${mockUSDT.address}`);
  console.log(`   MockEURC: ${mockEURC.address}`);
  console.log("─────────────────────────────────────────────────────────────────\n");
};

export default deployMockTokens;
deployMockTokens.tags = ["MockTokens"];
