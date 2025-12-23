import { ethers } from "hardhat";

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("=== Minting Tokens to Deployer ===");
  console.log("Deployer:", deployer.address);

  // Token addresses from latest deployment
  const tokens = [
    { name: "USDC", addr: "0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0", decimals: 6, amount: "100000" },
    { name: "USDT", addr: "0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9", decimals: 6, amount: "100000" },
    { name: "DAI", addr: "0xDc64a140Aa3E981100a9becA4E685f962f0cF6C9", decimals: 18, amount: "100000" },
    { name: "WBTC", addr: "0x5FC8d32690cc91D4c39d9d3abcBD16989F875707", decimals: 8, amount: "10" },
    { name: "LINK", addr: "0x0165878A594ca255338adfa4d48449f69242Eb8F", decimals: 18, amount: "10000" },
  ];

  const ERC20_ABI = [
    "function mint(address to, uint256 amount) public",
    "function balanceOf(address) view returns (uint256)",
  ];

  for (const token of tokens) {
    try {
      const contract = await ethers.getContractAt(ERC20_ABI, token.addr);
      const amount = ethers.parseUnits(token.amount, token.decimals);

      // Mint tokens
      const tx = await contract.mint(deployer.address, amount);
      await tx.wait();

      // Check balance
      const bal = await contract.balanceOf(deployer.address);
      console.log(`✅ ${token.name}: ${ethers.formatUnits(bal, token.decimals)}`);
    } catch (e: any) {
      console.log(`❌ ${token.name}: ${e.message}`);
    }
  }

  console.log("\n=== Done! ===");
  console.log("Tokens minted to:", deployer.address);
  console.log("\nImport this account in MetaMask:");
  console.log("Private Key: 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80");
}

main().catch(console.error);
