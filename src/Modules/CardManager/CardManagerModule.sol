// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import { CompatibilityFallbackHandler } from "safe-smart-account/contracts/handler/CompatibilityFallbackHandler.sol";
import { Enum, ModuleManager, OwnerManager } from "safe-smart-account/contracts/Safe.sol";

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

import { CardFactory } from "./CardFactory.sol";

error CM10_InstanceAlreadyExists(bytes32 id);
error CM11_OnlyInstanceOwner(address instanceOwner);
error CM12_InstanceDoesNotExist(bytes32 id);
error CM13_InstanceIsPaused(bytes32 id);
error CM14_InstanceNotAuthorized(bytes32 id);
error CM15_NoTokensAuthorizedForInstance(bytes32 id);
error CM16_TokenNotAuthorizedForInstance(bytes32 id, address token);
error CM20_AddressNotWhitelisted(bytes32 id, address addr);
error CM33_CardNotCreated();
error CM34_FailedToAddOwner();
error CM40_FailedToWithdraw();

contract CardManagerModule is
	CompatibilityFallbackHandler,
	Initializable,
	ReentrancyGuardUpgradeable,
	OwnableUpgradeable,
	UUPSUpgradeable
{
	string public constant NAME = "Card Manager Module";
	string public constant VERSION = "0.0.1";

	////////////////

	// keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
	bytes32 private constant DOMAIN_SEPARATOR_TYPEHASH =
		0x8b73c3c69bb8fe3d512ecc4cf759cc79239f7b179b0ffacaa9a75d522b39400f;

	/// @dev Returns the chain id used by this contract.
	function getChainId() public view returns (uint256) {
		uint256 id;
		// solhint-disable-next-line no-inline-assembly
		assembly {
			id := chainid()
		}
		return id;
	}

	function domainSeparator() public view returns (bytes32) {
		return
			keccak256(
				abi.encode(
					DOMAIN_SEPARATOR_TYPEHASH,
					keccak256(abi.encodePacked(NAME)),
					keccak256(abi.encodePacked(VERSION)),
					getChainId(),
					// address(communityModule),
					this
				)
			);
	}

	/////////////////////////////////////////////////
	// VARIABLES

	address public cardFactory;
	mapping(bytes32 => address) public instanceOwners;
	mapping(bytes32 => address[]) public instanceContracts;
	mapping(bytes32 => bool) public instancePaused;
	uint256 public instanceCount;
	int256 public cardCount;
	mapping(address => mapping(bytes32 => bool)) public authorizedInstances;

	mapping(bytes32 => uint256) private _whitelistVersion;
	mapping(bytes32 => mapping(address => uint256)) private _whitelist;

	/////////////////////////////////////////////////
	// EVENTS
	event InstanceCreated(bytes32 id, address owner);
	event WhitelistUpdated(bytes32 id, address[] addresses);

	event CardCreated(address indexed card);

	/////////////////////////////////////////////////
	// INITIALIZATION

	function initialize(address _owner, address _cardFactory) external initializer {
		__Ownable_init(_owner);
		__UUPSUpgradeable_init();
		__ReentrancyGuard_init();

		cardFactory = _cardFactory;
	}

	/////////////////////////////////////////////////

	/////////////////////////////////////////////////
	// UPGRADE AUTHORIZATION

	function _authorizeUpgrade(address newImplementation) internal view override onlyOwner {
		(newImplementation);
	}

	/////////////////////////////////////////////////

	/////////////////////////////////////////////////
	// INSTANCE MANAGEMENT

	function getInstanceId(uint256 salt) external view returns (bytes32) {
		return keccak256(abi.encodePacked(salt, address(this)));
	}

	function instanceOwner(bytes32 id) external view returns (address) {
		return instanceOwners[id];
	}

	function createInstance(bytes32 id, address[] memory tokens) external {
		if (instanceOwners[id] != address(0)) {
			revert CM10_InstanceAlreadyExists(id);
		}

		instanceCount++;

		instanceOwners[id] = msg.sender;
		instanceContracts[id] = tokens;
		emit InstanceCreated(id, msg.sender);
	}

	function updateInstanceTokens(bytes32 id, address[] memory tokens) external onlyInstanceOwner(id) {
		instanceContracts[id] = tokens;
	}

	function authorizeNewInstance(
		bytes32 id,
		bytes32 newInstanceId,
		bytes32 hashedSerial
	) external onlyInstanceOwner(id) onlyAuthorizedInstance(id, hashedSerial) {
		address cardAddress = getCardAddress(id, hashedSerial);
		authorizedInstances[cardAddress][newInstanceId] = true;
	}

	function pauseInstance(bytes32 id) external onlyInstanceOwner(id) {
		instancePaused[id] = true;
	}

	function unpauseInstance(bytes32 id) external onlyInstanceOwner(id) {
		instancePaused[id] = false;
	}

	modifier onlyInstanceOwner(bytes32 id) {
		if (instanceOwners[id] == address(0)) {
			revert CM12_InstanceDoesNotExist(id);
		}

		if (instanceOwners[id] != msg.sender) {
			revert CM11_OnlyInstanceOwner(msg.sender);
		}
		_;
	}

	modifier onlyCreatedInstance(bytes32 id) {
		if (instanceOwners[id] == address(0)) {
			revert CM12_InstanceDoesNotExist(id);
		}
		_;
	}

	modifier onlyUnpausedInstance(bytes32 id) {
		if (instancePaused[id]) {
			revert CM13_InstanceIsPaused(id);
		}
		_;
	}

	modifier onlyAuthorizedInstance(bytes32 id, bytes32 hashedSerial) {
		address cardAddress = getCardAddress(id, hashedSerial);
		if (!authorizedInstances[cardAddress][id]) {
			revert CM14_InstanceNotAuthorized(id);
		}
		_;
	}

	modifier onlyInstanceContract(bytes32 id, address to) {
		if (instanceContracts[id].length == 0) {
			revert CM15_NoTokensAuthorizedForInstance(id);
		}

		bool isContractAuthorized = false;
		for (uint256 i = 0; i < instanceContracts[id].length; i++) {
			if (instanceContracts[id][i] == to) {
				isContractAuthorized = true;
				break;
			}
		}
		if (!isContractAuthorized) {
			revert CM16_TokenNotAuthorizedForInstance(id, to);
		}
		_;
	}

	/////////////////////////////////////////////////
	// WHITELIST

	modifier onlyWhitelisted(bytes32 id, address addr) {
		if (!isWhitelisted(id, addr)) {
			revert CM20_AddressNotWhitelisted(id, addr);
		}
		_;
	}

	/**
	 * @dev Checks if an address is in the whitelist.
	 * @param id The id of the whitelist.
	 * @param addr The address to check.
	 * @return A boolean indicating whether the address is in the whitelist.
	 */
	function isWhitelisted(bytes32 id, address addr) public view returns (bool) {
		return _whitelist[id][addr] == _whitelistVersion[id];
	}

	function _updateWhiteList(bytes32 id, address[] memory addresses) internal virtual {
		// bump the version number so that we don't have to clear the mapping
		_whitelistVersion[id]++;

		for (uint256 i = 0; i < addresses.length; i++) {
			_whitelist[id][addresses[i]] = _whitelistVersion[id];
		}
	}

	/**
	 * @dev Updates the whitelist.
	 * @param id The id of the whitelist.
	 * @param addresses The addresses to update the whitelist.
	 */
	function updateWhitelist(bytes32 id, address[] memory addresses) public onlyInstanceOwner(id) {
		_updateWhiteList(id, addresses);

		emit WhitelistUpdated(id, addresses);
	}

	/////////////////////////////////////////////////
	// CARD MANAGEMENT

	/**
	 * @dev Calculates the hash value for a given card.
	 * This function should only be used to test hash values.
	 *
	 * @param id The id of the card.
	 * @param hashedSerial The hashed serial of the card.
	 * @return The calculated hash value.
	 */
	function getCardHash(bytes32 id, bytes32 hashedSerial) public view returns (bytes32) {
		return keccak256(abi.encodePacked(id, hashedSerial, address(this)));
	}

	/**
	 * @dev Creates a card.
	 * @param id The id of the card.
	 * @param hashedSerial The hashed serial of the card.
	 * @return The address of the card.
	 */
	function createCard(bytes32 id, bytes32 hashedSerial) public returns (address) {
		bytes32 cardHash = getCardHash(id, hashedSerial);

		(uint256 cardNonce, address cardAddress) = _getCardNonceAndAddress(cardHash);
		if (contractExists(cardAddress)) {
			return cardAddress;
		}

		cardCount++;
		authorizedInstances[cardAddress][id] = true;

		CardFactory(cardFactory).createAccount(address(this), cardNonce);

		emit CardCreated(cardAddress);

		return cardAddress;
	}

	/**
	 * @dev Retrieves the address of a card.
	 * @param id The id of the card.
	 * @param hashedSerial The hashed serial of the card.
	 * @return The address of the card.
	 */
	function getCardAddress(bytes32 id, bytes32 hashedSerial) public view returns (address) {
		bytes32 cardHash = getCardHash(id, hashedSerial);

		(, address cardAddress) = _getCardNonceAndAddress(cardHash);

		return cardAddress;
	}

	function _getCardNonceAndAddress(bytes32 cardHash) internal view returns (uint256, address) {
		uint256 cardNonce = _bytes32ToUint256(cardHash);

		address cardAddress = CardFactory(cardFactory).getAddress(address(this), cardNonce);

		return (cardNonce, cardAddress);
	}

	function _bytes32ToUint256(bytes32 b) internal pure returns (uint256) {
		return uint256(b);
	}

	/////////////////////////////////////////////////
	// CARD OWNERSHIP

	function addOwner(
		bytes32 id,
		bytes32 hashedSerial,
		address newOwner
	) public onlyInstanceOwner(id) onlyAuthorizedInstance(id, hashedSerial) {
		address cardAddress = getCardAddress(id, hashedSerial);

		if (!contractExists(cardAddress)) {
			revert CM33_CardNotCreated();
		}

		uint256 threshold = OwnerManager(cardAddress).getThreshold();

		bytes memory data = abi.encodeCall(OwnerManager.addOwnerWithThreshold, (newOwner, threshold));

		bool success = ModuleManager(cardAddress).execTransactionFromModule(cardAddress, 0, data, Enum.Operation.Call);
		if (!success) {
			revert CM34_FailedToAddOwner();
		}
	}

	/////////////////////////////////////////////////
	// Execute on Card

	function callOnCard(
		bytes32 id,
		bytes32 hashedSerial,
		address to,
		uint256 value,
		bytes memory data
	) public onlyCreatedInstance(id) onlyInstanceContract(id, to) onlyWhitelisted(id, msg.sender) onlyUnpausedInstance(id) {
		address cardAddress = getCardAddress(id, hashedSerial);

		if (!contractExists(cardAddress)) {
			createCard(id, hashedSerial);
		}

		_callOnCard(id, hashedSerial, to, value, data);
	}

	function _callOnCard(
		bytes32 id,
		bytes32 hashedSerial,
		address to,
		uint256 value,
		bytes memory data
	) internal onlyAuthorizedInstance(id, hashedSerial) {
		address cardAddress = getCardAddress(id, hashedSerial);

		bool success = ModuleManager(cardAddress).execTransactionFromModule(to, value, data, Enum.Operation.Call);
		if (!success) {
			revert CM40_FailedToWithdraw();
		}
	}

	/////////////////////////////////////////////////
	// HELPERS

	function contractExists(address contractAddress) public view returns (bool) {
		uint256 size;
		// solhint-disable-next-line no-inline-assembly
		assembly {
			size := extcodesize(contractAddress)
		}
		return size > 0;
	}

	/////////////////////////////////////////////////
}
