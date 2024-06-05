// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import { ERC1155URIStorageUpgradeable, ERC1155Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155URIStorageUpgradeable.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { AccessControlUpgradeable } from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

contract BadgeCollection is
	Initializable,
	ERC1155URIStorageUpgradeable,
	OwnableUpgradeable,
	AccessControlUpgradeable,
	UUPSUpgradeable
{
	using Strings for uint256;

	bytes32 internal constant NULL = "";
	bytes32 public constant BADGE_COLLECTION_ADMIN_ROLE = keccak256("BADGE_COLLECTION_ADMIN_ROLE");
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
	event BadgeClaimRangeUpdated(uint256 indexed id, uint48 claimFrom, uint48 claimTo);
	event BadgeMaxClaimUpdated(uint256 indexed id, uint256 maxClaim);
	event BadgeArchived(uint256 indexed id);

	// Custom errors
	error NotManager(address account);
	error Exists(uint256 id);
	error DoesNotExist(uint256 id);
	error InvalidClaimRange(uint48 claimFrom, uint48 claimTo);
	error InvalidUpdateUntil(uint48 updateUntil);
	error UpdateBlocked(uint256 id);
	error EmptyURI();
	error BadgeAlreadyArchived(uint256 id);

	error BeforeClaimPeriod();
	error AfterClaimPeriod();

	error MaximumClaimsReached(uint256 id);

	modifier onlyManager() {
		if (!hasRole(BADGE_ADMIN_ROLE, msg.sender)) revert NotManager(msg.sender);
		_;
	}

	modifier badgeExists(uint256 id) {
		if (!_exists(id)) revert DoesNotExist(id);
		_;
	}

	modifier badgeDoesNotExist(uint256 id) {
		if (_exists(id)) revert Exists(id);
		_;
	}

	modifier beforeUpdateUntil(uint256 id) {
		if (block.timestamp > badges[id].updateUntil) revert UpdateBlocked(id);
		_;
	}

	function _exists(uint256 id) internal view returns (bool) {
		return bytes(uri(id)).length > 0;
	}

	function exists(uint256 id) external view returns (bool) {
		return _exists(id);
	}

	function initialize(address _owner) external initializer {
		__ERC1155_init("");
		__Ownable_init(_owner);
		__AccessControl_init();
		__UUPSUpgradeable_init();

		_grantRole(DEFAULT_ADMIN_ROLE, _owner);

		_setRoleAdmin(BADGE_COLLECTION_ADMIN_ROLE, DEFAULT_ADMIN_ROLE);

		_grantRole(BADGE_COLLECTION_ADMIN_ROLE, _owner);
		_grantRole(BADGE_ADMIN_ROLE, _owner);
	}

	function create(
		uint256 id,
		uint48 claimFrom,
		uint48 claimTo,
		uint256 maxClaim,
		uint48 updateUntil,
		string memory _uri
	) external onlyManager badgeDoesNotExist(id) {
		if (bytes(_uri).length == 0) revert EmptyURI();
		if (claimFrom > claimTo) revert InvalidClaimRange(claimFrom, claimTo);
		if (updateUntil < block.timestamp) revert InvalidUpdateUntil(updateUntil);

		badges[id] = Badge(claimFrom, claimTo, maxClaim, updateUntil, false);
		_setURI(id, _uri);

		emit BadgeCreated(id, claimFrom, claimTo, maxClaim, updateUntil, _uri);
	}

	function updateContent(uint256 id, string memory _uri) external onlyManager badgeExists(id) beforeUpdateUntil(id) {
		if (bytes(_uri).length == 0) revert EmptyURI();
		_setURI(id, _uri);
		emit BadgeUpdated(id, _uri);
	}

	function updateClaimRange(
		uint256 id,
		uint48 claimFrom,
		uint48 claimTo
	) external onlyManager badgeExists(id) beforeUpdateUntil(id) {
		if (claimFrom > claimTo) revert InvalidClaimRange(claimFrom, claimTo);
		badges[id].claimFrom = claimFrom;
		badges[id].claimTo = claimTo;
		emit BadgeClaimRangeUpdated(id, claimFrom, claimTo);
	}

	function updateMaxClaim(uint256 id, uint256 maxClaim) external onlyManager badgeExists(id) beforeUpdateUntil(id) {
		badges[id].maxClaim = maxClaim;
		emit BadgeMaxClaimUpdated(id, maxClaim);
	}

	function archive(uint256 id) external onlyManager badgeExists(id) {
		badges[id].archived = true;
		emit BadgeArchived(id);
	}

	function claim(uint256 id) external badgeExists(id) {
		if (block.timestamp < badges[id].claimFrom) revert BeforeClaimPeriod();
		if (block.timestamp > badges[id].claimTo) revert AfterClaimPeriod();
		if (badges[id].archived) revert BadgeAlreadyArchived(id);
		if (badges[id].maxClaim > 0 && claims[id][msg.sender] >= badges[id].maxClaim) revert MaximumClaimsReached(id);

		claims[id][msg.sender]++;

		_mint(msg.sender, id, 1, "");
	}

	function get(
		uint256 id
	)
		external
		view
		badgeExists(id)
		returns (uint48 claimFrom, uint48 claimTo, uint256 maxClaim, uint48 updateUntil, string memory _uri)
	{
		Badge memory badge = badges[id];
		return (badge.claimFrom, badge.claimTo, badge.maxClaim, badge.updateUntil, uri(id));
	}

	function supportsInterface(
		bytes4 interfaceId
	) public view override(ERC1155Upgradeable, AccessControlUpgradeable) returns (bool) {
		return super.supportsInterface(interfaceId);
	}

	function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
