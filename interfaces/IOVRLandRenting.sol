// SPDX-License-Identifier: Unlicensed

pragma solidity ^0.8.4;

interface IOVRLandRenting {
  function activateNoRentFromHosting(uint256 _nftId, uint256 _period) external;
}
