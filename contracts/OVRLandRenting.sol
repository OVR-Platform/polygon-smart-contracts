//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.4;

import "hardhat/console.sol";

// Contracts
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol"; // Includes Intialize, Context
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "../contracts/PriceCalculator.sol";

// Libraries
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";

// Interfaces
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../interfaces/IOVRLand.sol";
import "../interfaces/IOVRLandExperience.sol";

contract OVRLandRenting is
    UUPSUpgradeable,
    AccessControlUpgradeable,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable,
    PriceCalculator
{
    using AddressUpgradeable for address;
    using SafeMath for uint256;

    IERC20 public token;
    IOVRLand public OVRLand;
    IOVRLandExperience public OVRLandExperience;
    address public OVRLandHosting;

    mapping(uint256 => Offer) public offers;

    mapping(uint256 => uint256) public noRentsEnd;
    uint256 public noRentPrice;
    uint256 public noRentDuration;

    uint256 public feeUSD;
    address public feeReceiver;

    /**
     * @param from offer created by
     * @param nftId OVRLand ID
     * @param valuePerMonth OVR tokens per month
     * @param months number of months
     * @param fee fee in OVR
     * @param timestamp creation timestamp
     * @param experienceUri experience uri
     */
    struct Offer {
        address from;
        uint256 nftId;
        uint256 valuePerMonth;
        uint256 months;
        uint256 fee;
        uint256 timestamp;
        string experienceUri;
    }

    /* ========== EVENTS ========== */

    event OfferPlaced(
        uint256 indexed nftId,
        address indexed sender,
        uint256 amountPerMonth,
        uint256 months, // 1-12 months
        uint256 timestamp
    );

    event Overbid(
        uint256 indexed nftId,
        address indexed sender,
        uint256 amountPerMonth,
        uint256 months,
        uint256 timestamp
    );

    event OfferAccepted(
        uint256 indexed nftId,
        address indexed sender,
        uint256 amountPerMonth,
        uint256 months,
        uint256 timestamp
    );

    event NoRentActivated(
        uint256 indexed nftId,
        address indexed owner,
        uint256 timestamp,
        uint256 period
    );

    event NoRentDeactivated(
        uint256 indexed nftId,
        address indexed owner,
        uint256 timestamp
    );

    /* ========== MODIFIERS ========== */

    modifier isOfferBetter(uint256 _nftId, uint256 _amount) {
        require(offers[_nftId].valuePerMonth < _amount, "Offer is too low");
        _;
    }

    function initialize(
        address _tokenAddress,
        address _OVRLandAddress,
        address _OVRLandExperience,
        address _OVRLandHosting,
        address _feeReceiver,
        uint256 _noRentPrice
    ) public initializer {
        token = IERC20(_tokenAddress);
        OVRLand = IOVRLand(_OVRLandAddress);
        OVRLandExperience = IOVRLandExperience(_OVRLandExperience);
        OVRLandHosting = _OVRLandHosting;

        noRentPrice = _noRentPrice;
        noRentDuration = 60 days; // 2 months

        feeUSD = 10e22;
        feeReceiver = _feeReceiver;

        __AccessControl_init();
        __Pausable_init();
        __ReentrancyGuard_init();

        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
    }

    function setOVRLandExperienceAddress(address _address)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        OVRLandExperience = IOVRLandExperience(_address);
    }

    /* ========== NO RENT ========== */

    /**
     * @dev Callable from OVRLand owner to prevent renters from
     * independently accepting offers of 1 month duration.
     * @param _nftId token id
     */
    function activateNoRent(uint256 _nftId) public {
        require(_msgSender() == OVRLand.ownerOf(_nftId), "Not the owner");
        require(
            token.transferFrom(_msgSender(), address(this), noRentPrice),
            "Transfer failed"
        );

        noRentsEnd[_nftId] = _now().add(noRentDuration);
        emit NoRentActivated(_nftId, _msgSender(), _now(), noRentDuration);
    }

    function activateNoRentFromHosting(uint256 _nftId, uint256 _monthsDuration)
        public
    {
        require(_msgSender() == OVRLandHosting, "Not authorized");
        uint256 expiration = _now().add(_monthsDuration.mul(30 days));
        noRentsEnd[_nftId] = expiration;

        emit NoRentActivated(_nftId, _msgSender(), _now(), expiration);
    }

    /**
     * @dev Callable from OVRLand owner to turn off NoRent
     * @param _nftId token id
     */
    function deactivateNoRent(uint256 _nftId) public {
        require(_msgSender() == OVRLand.ownerOf(_nftId), "Not the owner");

        delete noRentsEnd[_nftId];
        emit NoRentDeactivated(_nftId, _msgSender(), _now());
    }

    /**
     * @dev admin can set the hosting contrat
     */
    function setHostingContract(address _address)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(_address != address(0), "Not valid addres");
        OVRLandHosting = _address;
    }

    /**
     * @dev Check if NoRent is active
     * @param _nftId token id
     * @return bool
     */
    function isNoRentActive(uint256 _nftId) public view returns (bool) {
        if (noRentsEnd[_nftId] == 0) {
            return false;
        }
        if (_now() < noRentsEnd[_nftId]) {
            return true;
        } else {
            return false;
        }
    }

    /**
     * @dev Callable by admin to update NoRent price
     * @param _price NoRent price
     */
    function changeNoRentPrice(uint256 _price)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        noRentPrice = _price;
    }

    /**
     * @dev Callable by admin to update NoRent duration
     * @param _duration NoRent duration
     */
    function changeNoRentDuration(uint256 _duration)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        noRentDuration = _duration;
    }

    /* ========== OFFERS ========== */

    /**
     * @dev In the case of an overbid it returns the amount spent by the previous bidder.
     * @param _nftId token id
     */
    function repayPreviousOfferer(uint256 _nftId) internal nonReentrant {
        if (offers[_nftId].from != address(0)) {
            uint256 oldFee = offers[_nftId].fee;
            address from = offers[_nftId].from;
            uint256 paid = offers[_nftId].valuePerMonth.mul(
                offers[_nftId].months
            );

            uint256 totalToReturn = paid.add(oldFee);
            offers[_nftId].from = address(0); // Improve safety
            require(
                token.transfer(from, totalToReturn),
                "Insufficient contract balance"
            );
        }
    }

    /**
     * @dev Internal method to save new offer
     * @param _nftId tokenId
     * @param _sender created by
     * @param _amountPerMonth OVR tokens per month
     * @param _fee fee in OVR
     * @param _months number of months
     * @param _uri experience uri
     */
    function saveOffer(
        uint256 _nftId,
        address _sender,
        uint256 _amountPerMonth,
        uint256 _fee,
        uint256 _months,
        string memory _uri
    ) internal nonReentrant {
        offers[_nftId] = Offer(
            _sender,
            _nftId,
            _amountPerMonth,
            _months,
            _fee,
            _now(),
            _uri
        );
    }

    /**
     * @dev Method to place new offer
     * This function can be called by everyone if no offer is present. If an offer already exists
     * it must be higher. Is allowed to overbid if 24 hours have not passed or after 7 days
     * (indicates that owner and renter are not active).
     * @param _nftId tokenId
     * @param _amount OVR tokens per month
     * @param _months number of months
     * @param _uri experience uri
     */
    function placeOffer(
        uint256 _nftId,
        uint256 _amount,
        uint256 _months,
        string memory _uri
    ) public isOfferBetter(_nftId, _amount) whenNotPaused {
        require(!OVRLandExperience.isOVRLandRented(_nftId), "Still rented");
        require(OVRLand.ownerOf(_nftId) != _msgSender(), "You are the owner");
        require(_months > 0 && _months < 13, "Only 12 months interval");

        uint256 priceOVR = valueOfAsset(1);
        uint256 calculatedFees = feeUSD.div(priceOVR).mul(1e14);

        if (offers[_nftId].timestamp != 0) {
            // There is already an offer
            if (
                _now() < offers[_nftId].timestamp.add(1 days) ||
                _now() > offers[_nftId].timestamp.add(8 days)
            ) {
                // 24h not passed or 7 days passed
                repayPreviousOfferer(_nftId);
                emit Overbid(_nftId, _msgSender(), _amount, _months, _now());
            } else {
                revert("Not a valid offer");
            }
        } else {
            // No offer made until now
            emit OfferPlaced(_nftId, _msgSender(), _amount, _months, _now());
        }

        require(
            token.transferFrom(
                _msgSender(),
                address(this),
                (_amount.mul(_months)).add(calculatedFees)
            ),
            "Transfer failed"
        );

        saveOffer(_nftId, _msgSender(), _amount, calculatedFees, _months, _uri);
    }

    /**
     * @dev Method to accept offer
     * The OVRLand owner may accept an offer at any time. If the offer has a duration
     * of 1 month also the renter can accept it if for more than 24 hours no new offers arrive.
     * In this case, the renter has 7 days to finalize the renting before new offers come to outbid him.
     *
     * This condition is present mainly to avoid a liability of the owner who may not be active
     * or may have lost his private keys.
     * @param _nftId tokenId
     */
    function acceptOffer(uint256 _nftId) public whenNotPaused {
        // only renter or owner
        require(
            _msgSender() == OVRLand.ownerOf(_nftId) ||
                _msgSender() == offers[_nftId].from,
            "Not authorized"
        );
        // land should not be rented
        require(!OVRLandExperience.isOVRLandRented(_nftId), "Still renting");
        require(offers[_nftId].from != address(0), "Not valid offer");

        if (isNoRentActive(_nftId)) {
            // no rent active - only owner can accept
            require(_msgSender() == OVRLand.ownerOf(_nftId), "No Rent");
        }

        // owner can accept everytime
        if (_msgSender() != OVRLand.ownerOf(_nftId)) {
            // if renter
            if (offers[_nftId].months == 1) {
                // renter can accept after 24h for 1 month duration
                require(
                    _now() > offers[_nftId].timestamp.add(1 days),
                    "24 hours not yet elapsed"
                );
                require(
                    _now() < offers[_nftId].timestamp.add(8 days),
                    "Acceptance time window of 7 days expired"
                );
            } else {
                // renter can't accept if months are more than 1
                revert("Renters can't accept more than 1 month duration");
            }
        }

        bool success = OVRLandExperience.startOVRLandRenting(
            _nftId,
            offers[_nftId].from,
            _now(),
            offers[_nftId].months,
            offers[_nftId].experienceUri
        );

        if (success) {
            uint256 tokenForOwner = offers[_nftId].valuePerMonth.mul(
                offers[_nftId].months
            );

            token.transfer(OVRLand.ownerOf(_nftId), tokenForOwner);
            token.transfer(feeReceiver, offers[_nftId].fee);

            delete offers[_nftId];
        } else {
            revert("Error");
        }
    }

    function cancelOffer(uint256 _nftId) public {
        require(_msgSender() == offers[_nftId].from, "Not authorized");
        require(
            _now() > offers[_nftId].timestamp.add(8 days),
            "You must wait 8 days to withdraw"
        );
        repayPreviousOfferer(_nftId);
        delete offers[_nftId];
    }

    function _now() internal view returns (uint256) {
        return block.timestamp;
    }

    function pause() public onlyRole(DEFAULT_ADMIN_ROLE) whenNotPaused {
        _pause();
    }

    function unpause() public onlyRole(DEFAULT_ADMIN_ROLE) whenPaused {
        _unpause();
    }

    function _authorizeUpgrade(address)
        internal
        override
        onlyRole(DEFAULT_ADMIN_ROLE)
    {}
}
