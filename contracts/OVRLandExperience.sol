//SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "hardhat/console.sol";
import "@openzeppelin/contracts/access/AccessControl.sol"; // Includes Intialize, Context
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import "../interfaces/IOVRLandRenting.sol";

contract OVRLandExperience is AccessControl {
  using Address for address;
  using SafeMath for uint256;

  IERC721 public OVRLand;
  IOVRLandRenting public OVRLandRenting;

  // Owner Experience
  mapping(uint256 => string) public experiences;

  // Renter Experience
  mapping(uint256 => string) public rentingExperiences;
  mapping(uint256 => uint256) public rentingDates;
  mapping(uint256 => uint256) public months;
  mapping(uint256 => address) public renter;

  // bytes32 public constant BLACK_LIST = keccak256("BLACK_LIST");

  constructor(address _ovrLandAddress, address _ovrLandRentingAddress) {
    OVRLand = IERC721(_ovrLandAddress);
    OVRLandRenting = IOVRLandRenting(_ovrLandRentingAddress);

    _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
  }

  event ExperienceUpdated(
    uint256 indexed nftId,
    address indexed sender,
    uint256 timestamp,
    bool renting
  );

  /* ========== ROLES ========== */

  function addAdmin(address _admin) public onlyRole(DEFAULT_ADMIN_ROLE) {
    grantRole(DEFAULT_ADMIN_ROLE, _admin);
  }

  function removeAdmin(address _admin) public onlyRole(DEFAULT_ADMIN_ROLE) {
    revokeRole(DEFAULT_ADMIN_ROLE, _admin);
  }

  // function addAccountToBlacklist(address _account)
  //     public
  //     onlyRole(DEFAULT_ADMIN_ROLE)
  // {
  //     grantRole(BLACK_LIST, _account);
  // }

  // function removeAccountFromBlacklist(address _account)
  //     public
  //     onlyRole(DEFAULT_ADMIN_ROLE)
  // {
  //     revokeRole(BLACK_LIST, _account);
  // }

  /* ========== EXPERIENCES ========== */

  /**
   * @notice Check if OVRLand is rented, rentingDates == 0 not rented
   * @param _nftId OVRLand NFT ID
   * @return bool Rented
   */
  function isOVRLandRented(uint256 _nftId) public view returns (bool) {
    if (rentingDates[_nftId] == 0) {
      return false;
    } else {
      if (
        _now() >= rentingDates[_nftId] &&
        _now() <= rentingDates[_nftId].add(months[_nftId].mul(30 days))
      ) {
        return true;
      } else {
        return false;
      }
    }
  }

  /**
   * @notice Get current OVRLand Experience URI
   * @param _nftId OVRLand NFT ID
   * @return string URI
   */
  function experienceURI(uint256 _nftId) public view returns (string memory) {
    if (isOVRLandRented(_nftId)) {
      return rentingExperiences[_nftId];
    } else {
      return experiences[_nftId];
    }
  }

  /**
   * @notice Get current OVRLand Renting Expiration
   * @param _nftId OVRLand NFT ID
   * @return expiration timestamp
   */
  function rentingExpiration(uint256 _nftId) public view returns (uint256) {
    uint256 expiration;
    if (isOVRLandRented(_nftId)) {
      return expiration = rentingDates[_nftId].add(months[_nftId].mul(30 days));
    } else return expiration;
  }

  /**
   * @notice Update current OVRLand Experience URI
   * @param _nftId OVRLand NFT ID
   * @param _uri OVRLand Experience URI
   */
  function updateExperience(uint256 _nftId, string memory _uri) public {
    // require(!hasRole(BLACK_LIST, _msgSender()), "Blacklisted address");

    if (isOVRLandRented(_nftId)) {
      require(_msgSender() == renter[_nftId], "Not the renter");
      rentingExperiences[_nftId] = _uri;
      emit ExperienceUpdated(_nftId, _msgSender(), _now(), true);
    } else {
      require(_msgSender() == OVRLand.ownerOf(_nftId), "Not the owner");
      experiences[_nftId] = _uri;
      emit ExperienceUpdated(_nftId, _msgSender(), _now(), false);
    }
  }

  /**
   * @notice Update current OVRLand Experience URI only from Admin
   * @param _nftId OVRLand NFT ID
   * @param _uri OVRLand Experience URI
   */
  function adminUpdateExperience(uint256 _nftId, string memory _uri)
    public
    onlyRole(DEFAULT_ADMIN_ROLE)
  {
    experiences[_nftId] = _uri;
  }

  /**
   * @notice Callable by OVRLandRenting
   * @param _nftId OVRLand NFT ID
   * @param _renter renter
   * @param _startDate renting start date
   * @param _months renting duration
   * @param _uri experience uri
   * @return bool is started
   */
  function startOVRLandRenting(
    uint256 _nftId,
    address _renter,
    uint256 _startDate,
    uint256 _months,
    string memory _uri
  ) public returns (bool) {
    require(_msgSender() == address(OVRLandRenting), "Non valid execution");
    require(!isOVRLandRented(_nftId), "OVRLand rented");

    rentingDates[_nftId] = _startDate;
    months[_nftId] = _months;
    renter[_nftId] = _renter;
    rentingExperiences[_nftId] = _uri;

    return true;
  }

  function _now() internal view returns (uint256) {
    return block.timestamp;
  }
}
