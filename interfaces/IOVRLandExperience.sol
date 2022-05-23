// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.4;

interface IOVRLandExperience {
    function startOVRLandRenting(
        uint256 _nftId,
        address _renter,
        uint256 _startDate,
        uint256 _months,
        string memory _uri
    ) external returns (bool);

    function isOVRLandRented(uint256 _nftId) external returns (bool);
}
