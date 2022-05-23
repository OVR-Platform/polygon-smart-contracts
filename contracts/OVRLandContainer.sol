// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.2;

// Contracts
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

// Libraries
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";

// Interfaces
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "../interfaces/IMarketplace.sol";
import "../interfaces/IRenting.sol";

contract OVRLandContainer is
  UUPSUpgradeable,
  ERC721Upgradeable,
  ERC721EnumerableUpgradeable,
  ERC721URIStorageUpgradeable,
  ERC721BurnableUpgradeable,
  AccessControlUpgradeable
{
  using CountersUpgradeable for CountersUpgradeable.Counter;
  using SafeMathUpgradeable for uint256;

  bytes32 public constant URI_EDITOR_ROLE = keccak256("URI_EDITOR_ROLE");
  bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

  CountersUpgradeable.Counter private _tokenIdCounter;

  IERC721Upgradeable public OVRLand;
  IMarketplace public marketplace;
  IRenting public renting;

  /**
   * @dev Called on deployment by deployProxy
   * @param _OVRLand The ERC721 token address
   */
  function initialize(IERC721Upgradeable _OVRLand) external initializer {
    __AccessControl_init();
    __ERC721Enumerable_init();
    __ERC721URIStorage_init();
    __ERC721Burnable_init();
    __ERC721_init("OVRLand Container", "OVRLandContainer");

    _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
    _setupRole(URI_EDITOR_ROLE, _msgSender());
    _setupRole(UPGRADER_ROLE, _msgSender());
    OVRLand = _OVRLand;
  }

  event ContainerCreated(
    uint256 indexed containerId,
    address indexed creator,
    uint256 timestamp
  );
  event ContainerDeleted(
    uint256 indexed containerId,
    address indexed owner,
    uint256 timestamp
  );
  event LandAddedToContainer(
    uint256 indexed landId,
    address indexed owner,
    uint256 indexed containerId,
    uint256 timestamp
  );
  event LandRemovedFromContainer(
    uint256 indexed landId,
    address indexed owner,
    uint256 indexed containerId,
    uint256 timestamp
  );

  //10 => 0,1,2,3,4 => 10,11,12,13,14
  //containerId => indexLands => LandId
  mapping(uint256 => mapping(uint256 => uint256)) public containerToLands;
  //landId => containerId
  mapping(uint256 => uint256) public landToContainer;
  //containerId => numberOfLands + 1 (if nLandsInContainer[256] return 4, max indexLands of container is 3 'cause it starts from 0)
  mapping(uint256 => uint256) public nLandsInContainer;
  //landId => landIndex inside container
  mapping(uint256 => uint256) public landIndex;

  /**
   * @dev Verify that the caller is the owner of the container
   * @param _containerId OVRLandContainer tokenId
   */
  modifier isContainerOwner(uint256 _containerId) {
    require(ownerOf(_containerId) == _msgSender(), "Caller is not the owner");
    _;
  }

  /**
   * @dev Verify that the lands sent aren't on renting or on selling
   * @param _landId OVRLand tokenId
   */
  modifier landsFree(uint256[] memory _landId) {
    uint256 length = _landId.length;
    if (address(marketplace) != address(0) && address(renting) == address(0)) {
      for (uint256 i = 0; i < length; i++) {
        require(
          marketplace.landIsOnSelling(_landId[i]) == false,
          "OVRLandContainer: One or more lands are on selling"
        );
      }
    } else if (
      address(marketplace) == address(0) && address(renting) != address(0)
    ) {
      for (uint256 i = 0; i < length; i++) {
        require(
          renting.landIsOnRenting(_landId[i]) == false,
          "OVRLandContainer: One or more lands are on renting"
        );
      }
    } else if (
      address(marketplace) != address(0) && address(renting) != address(0)
    ) {
      for (uint256 i = 0; i < length; i++) {
        require(
          renting.landIsOnRenting(_landId[i]) == false,
          "OVRLandContainer: One or more lands are on renting"
        );
        require(
          marketplace.landIsOnSelling(_landId[i]) == false,
          "OVRLandContainer: One or more lands are on selling"
        );
      }
    }
    _;
  }

  /**
   * @dev Verify that the land sent isn't on renting or on selling
   * @param _landId OVRLand tokenId
   */
  modifier landFree(uint256 _landId) {
    if (address(marketplace) != address(0) && address(renting) == address(0)) {
      require(
        marketplace.landIsOnSelling(_landId) == false,
        "OVRLandContainer: One or more lands are on selling"
      );
    } else if (
      address(marketplace) == address(0) && address(renting) != address(0)
    ) {
      require(
        renting.landIsOnRenting(_landId) == false,
        "OVRLandContainer: One or more lands are on renting"
      );
    } else if (
      address(marketplace) != address(0) && address(renting) != address(0)
    ) {
      require(
        renting.landIsOnRenting(_landId) == false,
        "OVRLandContainer: One or more lands are on renting"
      );
      require(
        marketplace.landIsOnSelling(_landId) == false,
        "OVRLandContainer: One or more lands are on selling"
      );
    }
    _;
  }

  /**
   * @dev Verify that the container sent isn't on renting or on selling
   * @param _containerId OVRLandContainer tokenId
   */
  modifier containerFree(uint256 _containerId) {
    if (address(marketplace) != address(0) && address(renting) == address(0)) {
      require(
        marketplace.containerIsOnSelling(_containerId) == false,
        "OVRLandContainer: Container is on selling"
      );
    } else if (
      address(marketplace) == address(0) && address(renting) != address(0)
    ) {
      require(
        renting.containerIsOnRenting(_containerId) == false,
        "OVRLandContainer: Container is on selling"
      );
    } else if (
      address(marketplace) != address(0) && address(renting) != address(0)
    ) {
      require(
        renting.containerIsOnRenting(_containerId) == false,
        "OVRLandContainer: Container is on selling"
      );
      require(
        marketplace.containerIsOnSelling(_containerId) == false,
        "OVRLandContainer: Container is on selling"
      );
    }

    _;
  }

  /**
   * @dev Given a landId return the owner
   * @param _landId OVRLand tokenId
   * @return owner Owner
   */
  function ownerOfChild(uint256 _landId) public view returns (address owner) {
    uint256 containerOfChild = landToContainer[_landId];
    address ownerAddressOfChild = ownerOf(containerOfChild);
    require(
      ownerAddressOfChild != address(0),
      "OVRLandContainer: Query for a non existing container"
    );
    return ownerAddressOfChild;
  }

  /**
   * @dev Given a containerId return the lands inside
   * @param _containerId OVRLandContainer tokenId
   * @return lands OVRLands inside specific OVRLandContainer
   */
  function childsOfParent(uint256 _containerId)
    public
    view
    returns (uint256[] memory lands)
  {
    require(_exists(_containerId), "ERC721: query for nonexistent container");
    uint256 numberOfLands = nLandsInContainer[_containerId];
    uint256[] memory childs = new uint256[](numberOfLands);
    for (uint256 i = 0; i < numberOfLands; i++) {
      childs[i] = containerToLands[_containerId][i];
    }
    return childs;
  }

  /**
   * @dev Function to set marketplace address, can be called only by an admin
   * @param _marketplace OVRMarkeplace address
   */
  function setMarketplaceAddress(IMarketplace _marketplace)
    public
    onlyRole(DEFAULT_ADMIN_ROLE)
  {
    require(_marketplace != IMarketplace(address(0)), "Cannot be zero address");
    marketplace = _marketplace;
  }

  /**
   * @dev Function to set renting address, can be called only by an admin
   * @param _renting OVRRenting address
   */
  function setRentingAddress(IRenting _renting)
    public
    onlyRole(DEFAULT_ADMIN_ROLE)
  {
    require(_renting != IRenting(address(0)), "Cannot be zero address");
    renting = _renting;
  }

  /**
   * @dev Function to remove one OVRLand from a OVRLandContainer
   * @param _containerId OVRLandContainer tokenId
   * @param _idLand OVRLand tokenId
   */
  function removeLandFromContainer(uint256 _containerId, uint256 _idLand)
    public
    isContainerOwner(_containerId)
    containerFree(_containerId)
  {
    require(
      landToContainer[_idLand] == _containerId,
      "OVRLand not inside container"
    );
    require(_exists(_containerId), "ERC721: query for nonexistent container");
    // land is not inside the container anymore
    delete landToContainer[_idLand];
    //decrease number of lands in the container
    uint256 currentNumber = nLandsInContainer[_containerId];
    nLandsInContainer[_containerId] = currentNumber.sub(1);
    //delete index of land
    uint256 index = landIndex[_idLand];
    delete landIndex[_idLand];
    // decrease lands index and positions inside the container for lands that were after the land removed
    /**  @dev if currentNumber - 1 ! > index it means that user are trying to remove the last land of the container
     *    so we don't need to decrease indexes and positions for lands after that 'cause there aren't
     */
    if (currentNumber - 1 > index) {
      for (uint256 i = index + 1; i < currentNumber; i++) {
        landIndex[containerToLands[_containerId][i]] = landIndex[
          containerToLands[_containerId][i]
        ].sub(1);
        containerToLands[_containerId][i - 1] = containerToLands[_containerId][
          i
        ];
      }
      delete containerToLands[_containerId][currentNumber - 1];
    }
    OVRLand.transferFrom(address(this), _msgSender(), _idLand);
    //if there is only 1 land inside the container, delete it
    if (currentNumber - 1 == 1) {
      // _burn(_containerId);
      deleteContainer(_containerId);
    }
    emit LandRemovedFromContainer(
      _idLand,
      _msgSender(),
      _containerId,
      block.timestamp
    );
  }

  /**
   * @dev Function to add one land to a container
   * @param _containerId OVRLandContainer tokenId
   * @param _idLand OVRLand tokenId
   */
  function addLandToContainer(uint256 _containerId, uint256 _idLand)
    public
    isContainerOwner(_containerId)
    landFree(_idLand)
  {
    require(_exists(_containerId), "ERC721: query for nonexistent container");
    //transfer land from user to this contract
    OVRLand.transferFrom(_msgSender(), address(this), _idLand);
    //if there isn't any land inside the container, burn the container
    //set container for land
    landToContainer[_idLand] = _containerId;
    //increase number of lands in the container
    uint256 currentNumber = nLandsInContainer[_containerId];
    nLandsInContainer[_containerId] = currentNumber.add(1);
    //add index of land
    landIndex[_idLand] = currentNumber;
    //insert land inside the land
    containerToLands[_containerId][currentNumber] = _idLand;

    emit LandAddedToContainer(
      _idLand,
      _msgSender(),
      _containerId,
      block.timestamp
    );
  }

  /**
   * @dev Function to create a container, it needs an array of OVRLands
   * @param _landId [tokenId, tokenId, ...]
   */
  function createContainer(uint256[] memory _landId) public landsFree(_landId) {
    uint256 length = _landId.length;
    require(length > 1, "Cannot create container with 1 element");
    uint256 tokenId = _tokenIdCounter.current();
    for (uint256 i = 0; i < length; i++) {
      // It checks if token exists and is owner
      OVRLand.transferFrom(_msgSender(), address(this), _landId[i]);
      landToContainer[_landId[i]] = tokenId;
      landIndex[_landId[i]] = i;
      containerToLands[tokenId][i] = _landId[i];
    }
    nLandsInContainer[tokenId] = length;
    _tokenIdCounter.increment();
    _safeMint(_msgSender(), tokenId);
    emit ContainerCreated(tokenId, _msgSender(), block.timestamp);
  }

  /**
   * @dev Function to destroy a OVRLandContainer
   * @param _containerId OVRLandContainer tokenId
   */
  function deleteContainer(uint256 _containerId)
    public
    isContainerOwner(_containerId)
    containerFree(_containerId)
  {
    require(_exists(_containerId), "ERC721: query for nonexistent container");
    uint256 numberOfLands = nLandsInContainer[_containerId];
    //the container doesn't exist anymore
    delete nLandsInContainer[_containerId];
    for (uint256 i = 0; i < numberOfLands; i++) {
      delete landToContainer[containerToLands[_containerId][i]];
      delete landIndex[containerToLands[_containerId][i]];

      OVRLand.transferFrom(
        address(this),
        _msgSender(),
        containerToLands[_containerId][i]
      );
      delete containerToLands[_containerId][i];
    }

    _burn(_containerId);
    emit ContainerDeleted(_containerId, _msgSender(), block.timestamp);
  }

  function addURIEditor(address _editor) public onlyRole(DEFAULT_ADMIN_ROLE) {
    grantRole(URI_EDITOR_ROLE, _editor);
  }

  function removeURIEditor(address _editor)
    public
    onlyRole(DEFAULT_ADMIN_ROLE)
  {
    revokeRole(URI_EDITOR_ROLE, _editor);
  }

  function addUpgrader(address _upgrader) public onlyRole(DEFAULT_ADMIN_ROLE) {
    grantRole(UPGRADER_ROLE, _upgrader);
  }

  function removeUpgrader(address _upgrader)
    public
    onlyRole(DEFAULT_ADMIN_ROLE)
  {
    revokeRole(UPGRADER_ROLE, _upgrader);
  }

  function addAdminRole(address _admin) public onlyRole(DEFAULT_ADMIN_ROLE) {
    grantRole(DEFAULT_ADMIN_ROLE, _admin);
    grantRole(UPGRADER_ROLE, _admin);
    grantRole(URI_EDITOR_ROLE, _admin);
  }

  function removeAdminRole(address _admin) public onlyRole(DEFAULT_ADMIN_ROLE) {
    revokeRole(DEFAULT_ADMIN_ROLE, _admin);
    revokeRole(UPGRADER_ROLE, _admin);
    revokeRole(URI_EDITOR_ROLE, _admin);
  }

  function _authorizeUpgrade(address newImplementation)
    internal
    override
    onlyRole(UPGRADER_ROLE)
  {}

  /**
   * @dev Function to set the OVRLandContainer IPFS uri.
   * @param _tokenId uint256 ID of the OVRLandContainer
   * @param _uri string of the OVRLandContainer IPFS uri
   */
  function setOVRLandContainerURI(uint256 _tokenId, string memory _uri)
    public
    onlyRole(URI_EDITOR_ROLE)
  {
    _setTokenURI(_tokenId, _uri);
  }

  /**
   * @dev This method is used to claim unsupported tokens accidentally sent to the contract.
   * It can only be called by the owner.
   * @param _token The address of the token contract (zero address for claiming native coins).
   * @param _to The address of the tokens/coins receiver.
   * @param _amount Amount to claim.
   */
  function claimTokens(
    address _token,
    address _to,
    uint256 _amount
  ) external onlyRole(DEFAULT_ADMIN_ROLE) {
    require(_to != address(0) && _to != address(this), "Not a valid recipient");
    IERC20Upgradeable(_token).transfer(_to, _amount);
  }

  // The following functions are overrides required by Solidity.

  function _beforeTokenTransfer(
    address from,
    address to,
    uint256 tokenId
  ) internal override(ERC721Upgradeable, ERC721EnumerableUpgradeable) {
    super._beforeTokenTransfer(from, to, tokenId);
  }

  function _burn(uint256 tokenId)
    internal
    override(ERC721Upgradeable, ERC721URIStorageUpgradeable)
  {
    super._burn(tokenId);
  }

  function tokenURI(uint256 tokenId)
    public
    view
    override(ERC721Upgradeable, ERC721URIStorageUpgradeable)
    returns (string memory)
  {
    return super.tokenURI(tokenId);
  }

  function supportsInterface(bytes4 interfaceId)
    public
    view
    override(
      ERC721Upgradeable,
      ERC721EnumerableUpgradeable,
      AccessControlUpgradeable
    )
    returns (bool)
  {
    return super.supportsInterface(interfaceId);
  }
}
