const { ethers, upgrades } = require("hardhat");

async function main() {
  const OVRLandRenting = await ethers.getContractFactory("OVRLandRenting");

  const _tokenAddress = "0xC9A4fAafA5Ec137C97947dF0335E8784440F90B5";
  const _OVRLandAddress = "0xBA7AC2b0C2d4b020137c662F36F84F049e980394";
  const _OVRLandExperience = "0x0000000000000000000000000000000000000000";
  const _OVRLandHosting = "0x0000000000000000000000000000000000000000";
  const _feeReceiver = "0x00000000000B186EbeF1AC9a27C7eB16687ac2A9";
  const _noRentPrice = "1000000000000000000";

  console.log("Deploying implementation(first) and ERC1967Proxy(second)...");
  const renting = await upgrades.deployProxy(
    OVRLandRenting,
    [
      _tokenAddress,
      _OVRLandAddress,
      _OVRLandExperience,
      _OVRLandHosting,
      _feeReceiver,
      _noRentPrice,
    ],
    {
      initializer: "initialize",
      kind: "uups",
    }
  );
  await renting.deployed();
  console.log("Proxy deployed to: ", renting.address);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
