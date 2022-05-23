const { ethers, upgrades } = require("hardhat");

async function main() {
  const proxyAddress = "0x7616bFb03e250470386ab4888c447936d065816B";
  const marketplace = await ethers.getContractFactory("OVRMarketplace");

  const upgraded = await upgrades.upgradeProxy(proxyAddress, marketplace);

  console.log("Proxy Upgraded: ", upgraded.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
