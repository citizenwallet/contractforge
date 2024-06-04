// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155URIStorageUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import "@openzeppelin/contracts/utils/Strings.sol";

contract BadgeCollection is
    Initializable,
    ERC1155URIStorageUpgradeable,
    OwnableUpgradeable,
    AccessControlUpgradeable,
    UUPSUpgradeable
{
    using Strings for uint256;

    bytes32 constant NULL = "";
    bytes32 public constant BADGE_COLLECTION_ADMIN_ROLE =
        keccak256("BADGE_COLLECTION_ADMIN_ROLE");
    bytes32 public constant BADGE_ADMIN_ROLE = keccak256("BADGE_ADMIN_ROLE");

    struct Badge {
        uint48 claimFrom;
        uint48 claimTo;
        uint256 maxClaim;
        uint48 updateUntil;
        bool archived;
    }

    mapping(uint256 => Badge) public badges;
    mapping(uint256 => mapping(address => uint256)) public claims;

    event BadgeCreated(
        uint256 indexed id,
        uint48 claimFrom,
        uint48 claimTo,
        uint256 maxClaim,
        uint48 updateUntil,
        string uri
    );
    event BadgeUpdated(uint256 indexed id, string uri);
    event BadgeClaimRangeUpdated(
        uint256 indexed id,
        uint48 claimFrom,
        uint48 claimTo
    );
    event BadgeMaxClaimUpdated(uint256 indexed id, uint256 maxClaim);
    event BadgeArchived(uint256 indexed id);

    modifier onlyManager() {
        require(hasRole(BADGE_ADMIN_ROLE, msg.sender), "Not manager");
        _;
    }

    modifier badgeExists(uint256 id) {
        require(_exists(id), "Badge does not exist");
        _;
    }

    modifier beforeUpdateUntil(uint256 id) {
        require(
            block.timestamp <= badges[id].updateUntil,
            "Cannot update after updateUntil"
        );
        _;
    }

    function _exists(uint256 id) internal view returns (bool) {
        return bytes(uri(id)).length > 0;
    }

    function exists(uint256 id) external view returns (bool) {
        return _exists(id);
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _owner) external onlyOwner {
        __ERC1155_init("");
        __Ownable_init();
        __AccessControl_init();
        __UUPSUpgradeable_init();

        _setupRole(DEFAULT_ADMIN_ROLE, _owner);

        _grantRole(BADGE_COLLECTION_ADMIN_ROLE, _owner);
        _grantRole(BADGE_ADMIN_ROLE, _owner);

        transferOwnership(_owner);
    }

    function create(
        uint256 id,
        uint48 claimFrom,
        uint48 claimTo,
        uint256 maxClaim,
        uint48 updateUntil,
        string memory _uri
    ) external onlyManager {
        require(bytes(uri(id)).length == 0, "Badge exists");
        require(bytes(_uri).length > 0, "Empty URI");
        require(claimFrom < claimTo, "Invalid claim range");
        require(updateUntil >= block.timestamp, "Invalid updateUntil");

        badges[id] = Badge(claimFrom, claimTo, maxClaim, updateUntil, false);
        _setURI(id, _uri);

        emit BadgeCreated(id, claimFrom, claimTo, maxClaim, updateUntil, _uri);
    }

    function updateContent(
        uint256 id,
        string memory _uri
    ) external onlyManager badgeExists(id) beforeUpdateUntil(id) {
        require(bytes(_uri).length > 0, "Empty URI");
        _setURI(id, _uri);
        emit BadgeUpdated(id, _uri);
    }

    function updateClaimRange(
        uint256 id,
        uint48 claimFrom,
        uint48 claimTo
    ) external onlyManager badgeExists(id) beforeUpdateUntil(id) {
        require(claimFrom < claimTo, "Invalid claim range");
        badges[id].claimFrom = claimFrom;
        badges[id].claimTo = claimTo;
        emit BadgeClaimRangeUpdated(id, claimFrom, claimTo);
    }

    function updateMaxClaim(
        uint256 id,
        uint256 maxClaim
    ) external onlyManager badgeExists(id) beforeUpdateUntil(id) {
        badges[id].maxClaim = maxClaim;
        emit BadgeMaxClaimUpdated(id, maxClaim);
    }

    function archive(uint256 id) external onlyManager badgeExists(id) {
        badges[id].archived = true;
        emit BadgeArchived(id);
    }

    function claim(uint256 id) external badgeExists(id) {
        require(
            block.timestamp >= badges[id].claimFrom &&
                block.timestamp <= badges[id].claimTo,
            "Claim period invalid"
        );
        require(!badges[id].archived, "Badge archived");
        require(
            badges[id].maxClaim == 0 ||
                claims[id][msg.sender] < badges[id].maxClaim,
            "Max claim reached"
        );

        claims[id][msg.sender]++;

        _mint(msg.sender, id, 1, "");
    }

    function get(
        uint256 id
    )
        external
        view
        badgeExists(id)
        returns (
            uint48 claimFrom,
            uint48 claimTo,
            uint256 maxClaim,
            uint48 updateUntil,
            string memory _uri
        )
    {
        Badge memory badge = badges[id];
        return (
            badge.claimFrom,
            badge.claimTo,
            badge.maxClaim,
            badge.updateUntil,
            uri(id)
        );
    }

    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        override(ERC1155Upgradeable, AccessControlUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}
}
