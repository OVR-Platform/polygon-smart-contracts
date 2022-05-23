const { ethers, upgrades } = require("hardhat");

async function main() {
  // Hardhat always runs the compile task when running scripts with its command
  // line interface.
  //
  // If this script is run directly using `node` you may want to call compile
  // manually to make sure everything is compiled
  // await hre.run('compile');

  // POLYGON MAINNET
  const marketplace = await ethers.getContractFactory("OVRMarketplace");
  const OVRToken = "0x1631244689EC1fEcbDD22fb5916E920dFC9b8D30";
  const OVRLand = "0x93C46aA4DdfD0413d95D0eF3c478982997cE9861";
  const OVRLandContainer = "0x0000000000000000000000000000000000000000";
  const fee = 500;
  const feeReceiver = "0x0171a49e97e6f55f344408f6e6faea52e0158f10";

  console.log("Deploying implementation(first) and ERC1967Proxy(second)...");
  const OVRMarketplace = await upgrades.deployProxy(
    marketplace,
    [OVRToken, OVRLand, OVRLandContainer, fee, feeReceiver],
    {
      initializer: "initialize",
      kind: "uups",
    }
  );
  await OVRMarketplace.deployed();
  console.log("Proxy deployed to: ", OVRMarketplace.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
