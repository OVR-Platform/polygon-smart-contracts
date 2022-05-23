// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract OVRLandMapping is ERC721, ERC721URIStorage, AccessControl {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIdCounter;

    IERC721 public OVRLand;

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");
    bytes32 public constant URI_EDITOR_ROLE = keccak256("URI_EDITOR_ROLE");

    // OVRLand ID ==> OVRLandMapping ID ==> MAP
    mapping(uint256 => mapping(uint256 => string)) public mappings;

    constructor(address _ovrLandAddress) ERC721("OVR Map", "OVRMap") {
        OVRLand = IERC721(_ovrLandAddress);
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(MINTER_ROLE, _msgSender());
        _setupRole(BURNER_ROLE, _msgSender());
         _setupRole(URI_EDITOR_ROLE, _msgSender());
    }

    /* ========== ROLES ========== */

    function addAdmin(address _admin) public onlyRole(DEFAULT_ADMIN_ROLE) {
        grantRole(DEFAULT_ADMIN_ROLE, _admin);
        grantRole(MINTER_ROLE, _admin);
        grantRole(URI_EDITOR_ROLE, _admin);
    }

    function removeAdmin(address _admin) public onlyRole(DEFAULT_ADMIN_ROLE) {
        revokeRole(DEFAULT_ADMIN_ROLE, _admin);
    }

    function addMinter(address _minter) public onlyRole(DEFAULT_ADMIN_ROLE) {
        grantRole(MINTER_ROLE, _minter);
    }

    function removeMinter(address _minter) public onlyRole(DEFAULT_ADMIN_ROLE) {
        revokeRole(MINTER_ROLE, _minter);
    }

    function addBurner(address _burner) public onlyRole(DEFAULT_ADMIN_ROLE) {
        grantRole(BURNER_ROLE, _burner);
    }

    function removeBurner(address _burner) public onlyRole(DEFAULT_ADMIN_ROLE) {
        revokeRole(BURNER_ROLE, _burner);
    }

    function addEditor(address _editor) public onlyRole(DEFAULT_ADMIN_ROLE) {
        grantRole(URI_EDITOR_ROLE, _editor);
    }

    function removeEditor(address _editor) public onlyRole(DEFAULT_ADMIN_ROLE) {
        revokeRole(URI_EDITOR_ROLE, _editor);
    }

    /* ========== MINTING ========== */

    function safeMint(
        address _to,
        uint256 _ovrLandId,
        string memory _tokenURI,
        string memory _mappingURI
    ) public onlyRole(MINTER_ROLE) {
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();

        _safeMint(_to, tokenId);

        setMappingURI(_ovrLandId, tokenId, _mappingURI);
        _setTokenURI(tokenId, _tokenURI);
    }

    /**
     * @notice Function to batch minting tokens
     * @param _to address
     * @param _ovrLandId OVRLand NFT ID
     * @param _tokenURI OVRLandMapping token uri
     * @param _mappingURI OVRLandMapping map uri
     */
    function batchSafeMint(
        address[] memory _to,
        uint256[] memory _ovrLandId,
        string[] memory _tokenURI,
        string[] memory _mappingURI
    ) public onlyRole(MINTER_ROLE) {
        require(_to.length == _tokenURI.length, "Different array input size");
        for (uint256 i = 0; i < _to.length; i++) {
            uint256 tokenId = _tokenIdCounter.current();
            _tokenIdCounter.increment();

            _safeMint(_to[i], tokenId);

            setMappingURI(_ovrLandId[i], tokenId, _mappingURI[i]);
            _setTokenURI(tokenId, _tokenURI[i]);
        }
    }

    /* ========== URI ========== */

    function setMappingURI(
        uint256 _ovrLandId,
        uint256 _tokenId,
        string memory _mappingURI
    ) public onlyRole(URI_EDITOR_ROLE) {
        mappings[_ovrLandId][_tokenId] = _mappingURI;
    }

    function tokenURI(uint256 _tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(_tokenId);
    }

    function mappingURI(uint256 _ovrLandId, uint256 _tokenId)
        public
        view
        returns (string memory)
    {
        return mappings[_ovrLandId][_tokenId];
    }

    function burn(uint256 _ovrLandId, uint256 _tokenId)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        delete mappings[_ovrLandId][_tokenId];
        _burn(_tokenId);
    }

    // The following functions are overrides required by Solidity.

    function _burn(uint256 _tokenId)
        internal
        override(ERC721, ERC721URIStorage)
        onlyRole(BURNER_ROLE)
    {
        super._burn(_tokenId);
    }

    function supportsInterface(bytes4 _interfaceId)
        public
        view
        override(ERC721, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(_interfaceId);
    }
}
