const hre = require("hardhat");

async function main() {
  // Hardhat always runs the compile task when running scripts with its command
  // line interface.
  //
  // If this script is run directly using `node` you may want to call compile
  // manually to make sure everything is compiled
  // await hre.run('compile');

  const OVRLandContractMAINNET = "0x93C46aA4DdfD0413d95D0eF3c478982997cE9861";

  const OVRLandContractTESTNET = "0x624A4029dCc396B2d31a20eAFffd8fd118859aA0";

  // We get the contract to deploy
  const OVRLandMapping = await hre.ethers.getContractFactory("OVRLandMapping");
  const ovrLandMapping = await OVRLandMapping.deploy(OVRLandContractMAINNET);

  await ovrLandMapping.deployed();

  console.log("OVRLandMapping deployed to:", ovrLandMapping.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
