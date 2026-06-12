const hre = require("hardhat");

async function main() {
  console.log("Deploying FlashArb contract...");
  
  const FlashArb = await hre.ethers.getContractFactory("FlashArb");
  const flashArb = await FlashArb.deploy();
  
  await flashArb.waitForDeployment();
  
  const address = await flashArb.getAddress();
  console.log("FlashArb deployed to:", address);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
