const hre = require("hardhat");

async function main() {
  const _OVRLandAddress = "0xBA7AC2b0C2d4b020137c662F36F84F049e980394";
  const _OVRLandRenting = "0x4a6949461041d3964e6837d40ac8E54e27D0072f";

  const Experience = await hre.ethers.getContractFactory("OVRLandExperience");
  const experience = await Experience.deploy(_OVRLandAddress, _OVRLandRenting);

  await experience.deployed();

  console.log("experience deployed to:", experience.address);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
