// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import { CompatibilityFallbackHandler } from "safe-smart-account/contracts/handler/CompatibilityFallbackHandler.sol";
import { Enum, Safe, ModuleManager, OwnerManager } from "safe-smart-account/contracts/Safe.sol";

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

import { CardFactory } from "./CardFactory.sol";

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

	address immutable cardFactory;
	mapping(bytes32 => address) public instanceOwners;
	mapping(bytes32 => bool) public instancePaused;
	uint256 public instanceCount;
	mapping(bytes32 => uint256) public instanceCardCount;

	mapping(bytes32 => uint256) private _whitelistVersion;
	mapping(bytes32 => mapping(address => uint256)) private _whitelist;

	/////////////////////////////////////////////////
	// EVENTS
	event InstanceCreated(bytes32 id, address owner);
	event WhitelistUpdated(bytes32 id, address[] addresses);

	event CardCreated(address indexed card);

	/////////////////////////////////////////////////
	// INITIALIZATION

	/// @custom:oz-upgrades-unsafe-allow constructor
	constructor(address _cardFactory) {
		cardFactory = _cardFactory;
		_disableInitializers();
	}

	function initialize(address _owner) external initializer {
		__Ownable_init(_owner);
		__UUPSUpgradeable_init();
		__ReentrancyGuard_init();
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

	function getInstanceId(uint256 salt) external pure returns (bytes32) {
		return keccak256(abi.encodePacked(salt, address(this)));
	}

	function instanceOwner(bytes32 id) external view returns (address) {
		return instanceOwners[id];
	}

	function createInstance(bytes32 id) external {
		if (instanceOwners[id] != address(0)) {
			revert("CM10 Instance already exists");
		}

		instanceCount++;

		instanceOwners[id] = msg.sender;

		emit InstanceCreated(id, msg.sender);
	}

	function pauseInstance(bytes32 id) external onlyInstanceOwner(id) {
		instancePaused[id] = true;
	}

	function unpauseInstance(bytes32 id) external onlyInstanceOwner(id) {
		instancePaused[id] = false;
	}

	modifier onlyInstanceOwner(bytes32 id) {
		if (instanceOwners[id] == address(0)) {
			revert("CM12 Instance does not exist");
		}

		if (instanceOwners[id] != msg.sender) {
			revert("CM11 Only instance owner can call this function");
		}
		_;
	}

	modifier onlyUnpausedInstance(bytes32 id) {
		if (instancePaused[id]) {
			revert("CM13 Instance is paused");
		}
		_;
	}

	/////////////////////////////////////////////////
	// WHITELIST

	modifier onlyWhitelisted(bytes32 id, address addr) {
		if (!isWhitelisted(id, addr)) {
			revert("CM20 Address not whitelisted");
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

		for (uint i = 0; i < addresses.length; i++) {
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
	 * @param id The id of the instance.
	 * @param serial The serial to be hashed.
	 * @return The calculated hash value.
	 */
	function getCardHash(bytes32 id, uint256 serial) public view returns (bytes32) {
		return keccak256(abi.encodePacked(id, serial, address(this)));
	}

	function createCard(bytes32 id, uint256 serial) public returns (address) {
		(uint256 cardNonce, address cardAddress) = _getCardNonceAndAddress(id, serial);
		if (contractExists(cardAddress)) {
			return cardAddress;
		}

		instanceCardCount[id]++;

		CardFactory(cardFactory).createAccount(address(this), cardNonce);

		emit CardCreated(cardAddress);

		return cardAddress;
	}

	/**
	 * @dev Retrieves the address of a card.
	 * @param id The id of the card.
	 * @param serial The serial of the card.
	 * @return The address of the card.
	 */
	function getCardAddress(bytes32 id, uint256 serial) public view returns (address) {
		( , address cardAddress) = _getCardNonceAndAddress(id, serial);

		return cardAddress;
	}

	function _getCardNonceAndAddress(bytes32 id, uint256 serial) internal view returns (uint256, address) {
		bytes32 cardHash = getCardHash(id, serial);

		uint256 cardNonce = _bytes32ToUint256(cardHash);

		address cardAddress = CardFactory(cardFactory).getAddress(address(this), cardNonce);

		return (cardNonce, cardAddress);
	}

	function _bytes32ToUint256(bytes32 b) internal pure returns (uint256) {
		return uint256(b);
	}

	/////////////////////////////////////////////////
	// CARD OWNERSHIP

	function addOwner(bytes32 id, uint256 serial, address newOwner) public onlyInstanceOwner(id) {
		address cardAddress = getCardAddress(id, serial);

		if (!contractExists(cardAddress)) {
			revert("CM33 Card is not created");
		}

		uint256 threshold = OwnerManager(cardAddress).getThreshold();

		bytes memory data = abi.encodeCall(OwnerManager.addOwnerWithThreshold, (newOwner, threshold));

		bool success = ModuleManager(cardAddress).execTransactionFromModule(cardAddress, 0, data, Enum.Operation.Call); // MAYBE DELEGATECALL?
		if (!success) {
			revert("CM34 Failed to add owner");
		}
	}

	/////////////////////////////////////////////////
	// FUND WITHDRAWAL

	function withdraw(bytes32 id, uint256 serial, IERC20 token, address to, uint256 amount) public onlyWhitelisted(id, to) {
		address cardAddress = getCardAddress(id, serial);

		if (!contractExists(cardAddress)) {
			createCard(id, serial);
		}

		bytes memory data = abi.encodeCall(ERC20.transfer, (to, amount));

		bool success = ModuleManager(cardAddress).execTransactionFromModule(cardAddress, 0, data, Enum.Operation.Call); // MAYBE DELEGATECALL?
		if (!success) {
			revert("CM40 Failed to withdraw");
		}
	}

	/////////////////////////////////////////////////
	// HELPERS

	function contractExists(address contractAddress) public view returns (bool) {
		uint size;
		assembly {
			size := extcodesize(contractAddress)
		}
		return size > 0;
	}

	/////////////////////////////////////////////////

	// address immutable communityModule;

	// constructor(address _communityModule) {
	// 	communityModule = _communityModule;
	// }

	// /**
	//  * @notice Creates a new account
	//  * @dev This function creates a new account by deploying a Safe proxy and enabling the CommunityModule
	//  * @param _owner The address of the account owner
	//  * @param _nonce A unique number to ensure different salts for the same owner
	//  * @return address The address of the created account
	//  */
	// function createAccount(address _owner, uint256 _nonce) external returns (address) {
	// 	// compute the address of the account
	// 	address safeAddress = getAddress(_owner, _nonce);
	// 	// check if the account already exists
	// 	if (isContract(safeAddress)) {
	// 		// skip the deployment
	// 		return safeAddress;
	// 	}

	// 	bytes memory safeInitializer = _getInitializer(_owner, safeAddress);
	// 	bytes32 salt = _getSalt(_owner, _nonce);

	// 	// Deploy Safe proxy
	// 	SafeProxy safeProxy = deployProxy(SafeSuiteLib.SAFE_Safe_ADDRESS, safeInitializer, salt);

	// 	emit ProxyCreation(safeProxy, SafeSuiteLib.SAFE_Safe_ADDRESS);

	// 	return address(safeProxy);
	// }

	// /**
	//  * @notice Computes the address of a proxy that would be created using CREATE2
	//  * @param _owner Address of the owner
	//  * @param _nonce Nonce that will be used to generate the salt
	//  * @return The computed address of the proxy
	//  */
	// function getAddress(address _owner, uint256 _nonce) public view returns (address) {
	// 	bytes32 create2Input = _getCreate2Input(_owner, _nonce);

	// 	return address(uint160(uint256(create2Input)));
	// }

	// /**
	//  * @notice Generates a unique salt for CREATE2 deployment
	//  * @dev This function combines the owner's address and a nonce to create a unique identifier
	//  * @param _owner The address of the account owner
	//  * @param _nonce A unique number to ensure different salts for the same owner
	//  * @return bytes32 A unique salt value used in CREATE2 deployment
	//  */
	// function _getSalt(address _owner, uint256 _nonce) internal pure returns (bytes32) {
	// 	return keccak256(abi.encodePacked(_owner, _nonce));
	// }

	// /**
	//  * @notice Generates the CREATE2 input for the Safe proxy
	//  * @dev This function combines the proxy creation code and the salt to generate a unique identifier
	//  * @param _owner The address of the account owner
	//  * @param _nonce A unique number to ensure different salts for the same owner
	//  * @return bytes32 The CREATE2 input value used in the proxy creation
	//  */
	// function _getCreate2Input(address _owner, uint256 _nonce) internal view returns (bytes32) {
	// 	bytes32 salt = _getSalt(_owner, _nonce);

	// 	return
	// 		keccak256(
	// 			abi.encodePacked(
	// 				bytes1(0xff),
	// 				address(this),
	// 				salt,
	// 				keccak256(abi.encodePacked(proxyCreationCode(), uint256(uint160(SafeSuiteLib.SAFE_Safe_ADDRESS))))
	// 			)
	// 		);
	// }

	// /**
	//  * @notice Generates the initializer data for the Safe proxy
	//  * @dev This function sets up the Safe with the necessary owners and modules
	//  * @param _owner The address of the account owner
	//  * @param _safe The address of the Safe proxy
	//  * @return bytes memory The initializer data for the Safe proxy
	//  */
	// function _getInitializer(address _owner, address _safe) internal view returns (bytes memory) {
	// 	address[] memory owners = new address[](1);
	// 	owners[0] = _owner;

	// 	address[] memory modules = new address[](1);
	// 	modules[0] = communityModule;

	// 	// Prepare the data to call enableModule on the CommunityModule
	// 	// Encode the enableModule function call
	// 	bytes memory enableModuleData = abi.encodeCall(this.enableModules, (_safe, modules));

	// 	// Prepare safe initializer data
	// 	bytes memory safeInitializer = abi.encodeWithSelector(
	// 		Safe.setup.selector,
	// 		owners,
	// 		1, // threshold
	// 		address(this), // to
	// 		enableModuleData, // data
	// 		// address(0), // to
	// 		// "", // data
	// 		SafeSuiteLib.SAFE_TokenCallbackHandler_ADDRESS, // fallbackHandler
	// 		address(0), // paymentToken
	// 		0, // payment
	// 		address(0) // paymentReceiver
	// 	);
	// 	return safeInitializer;
	// }

	// /**
	//  * @notice Enables modules on the Safe proxy
	//  * @dev Can only be called as a part of the initialization process of a Safe
	//  * @param _safe The address of the Safe proxy
	//  * @param _safeModules The address of the modules to enable
	//  */
	// function enableModules(address _safe, address[] memory _safeModules) public payable {
	// 	Safe safe = Safe(payable(_safe));

	// 	for (uint256 i = 0; i < _safeModules.length; i++) {
	// 		address module = _safeModules[i];

	// 		// Check if the module is already enabled
	// 		if (ModuleManager(payable(safe)).isModuleEnabled(module)) {
	// 			return;
	// 		}

	// 		ModuleManager(payable(safe)).enableModule(module);
	// 	}
	// }
}
