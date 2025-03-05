// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Safe, OwnerManager, ModuleManager, Enum } from "safe-smart-account/contracts/Safe.sol";
import { Guard } from "safe-smart-account/contracts/base/GuardManager.sol";
import { StorageAccessible } from "safe-smart-account/contracts/common/StorageAccessible.sol";
import { CompatibilityFallbackHandler } from "safe-smart-account/contracts/handler/CompatibilityFallbackHandler.sol";

import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import { IERC1271 } from "@openzeppelin/contracts/interfaces/IERC1271.sol";

import { ValidationData, _parseValidationData } from "account-abstraction/core/Helpers.sol";
import { SenderCreator } from "account-abstraction/core/SenderCreator.sol";
import { UserOperation, UserOperationLib } from "account-abstraction/interfaces/UserOperation.sol";
import { IPaymaster } from "account-abstraction/interfaces/IPaymaster.sol";
import { INonceManager } from "account-abstraction/interfaces/INonceManager.sol";

import { UserOpHandler } from "./UserOpHandler.sol";

import { ITokenEntryPoint } from "./interfaces/ITokenEntryPoint.sol";
import { IUserOpValidator } from "./interfaces/IUserOpValidator.sol";

error CountIsZero(address safeAddr);
error ModuleNotEnabled(address safeAddr);

contract CommunityModule is
	UserOpHandler,
	CompatibilityFallbackHandler,
	ITokenEntryPoint,
	INonceManager,
	Initializable,
	ReentrancyGuardUpgradeable,
	OwnableUpgradeable,
	UUPSUpgradeable
{
	string public constant NAME = "Community Module";
	string public constant VERSION = "0.0.1";

	////////////////

	// keccak256("guard_manager.guard.address")
	bytes32 internal constant GUARD_STORAGE_SLOT = 0x4a204f620c8c5ccdca3fd54d003badd85ba500436a431f0cbda4f558c93c34c8;

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
					this
				)
			);
	}

	using ECDSA for bytes32;
	using UserOperationLib for UserOperation;

	SenderCreator private senderCreator;

	/// @custom:oz-upgrades-unsafe-allow state-variable-immutable
	INonceManager private immutable _entrypoint;

	/// @custom:oz-upgrades-unsafe-allow constructor
	constructor(INonceManager anEntryPoint) {
		_entrypoint = anEntryPoint;
		_disableInitializers();
	}

	// we make the owner of also the sponsor by default
	function initialize(address anOwner) public virtual initializer {
		__Ownable_init(anOwner);
		__UUPSUpgradeable_init();
		__ReentrancyGuard_init();

		_initialize();
	}

	function _initialize() internal virtual {
		senderCreator = new SenderCreator();

		executeSelector = bytes4(keccak256(bytes("execTransactionFromModule(address,uint256,bytes,uint8)")));
	}

	mapping(address => mapping(uint192 => uint256)) public nonceSequenceNumber;

	function getNonce(address sender, uint192 key) public view override returns (uint256 nonce) {
		return _entrypoint.getNonce(sender, key);
	}

	function incrementNonce(uint192 key) external override onlyOwner {}

	// parse uint192 key from uint256 nonce
	function _parseNonce(uint256 nonce) internal pure returns (uint192 key, uint64 seq) {
		return (uint192(nonce >> 64), uint64(nonce));
	}

	/**
	 * @dev Executes a batch of user operations.
	 * @param ops Array of UserOperation structs containing the operations to execute.
	 * @param beneficiary << kept to make sure we keep the same function signature.
	 * @notice This function is non-reentrant and requires at least one user operation.
	 * @notice Each operation is validated for nonce, account, and paymaster signature before execution.
	 */
	function handleOps(
		UserOperation[] calldata ops,
		address payable beneficiary // kept to make sure we keep the same function signature
	) public nonReentrant {
		(beneficiary);
		require(ops.length > 0, "AA42 needs at least one user operation");

		uint256 len = ops.length;
		for (uint256 i = 0; i < len; ) {
			// handle each op
			UserOperation calldata op = ops[i];

			address sender = op.getSender();

			(uint192 key, uint64 seq) = _parseNonce(op.nonce);

			// verify nonce
			_validateNonce(op, sender, key);

			(address to, uint256 value, bytes memory data) = _parseFromCallData(op.callData);

			// verify call data
			_validateCallData(op);

			// call the initCode
			if (seq == 0 && !_contractExists(sender)) {
				_initAccount(op, sender);
			}

			address guard = _getSafeGuard(sender);

			if (guard != address(0)) {
				_preCallGuard(guard, to, value, data, op);
			}

			// verify account
			_validateAccount(op, sender, key);

			// verify paymaster signature
			_validatePaymasterUserOp(op);

			// execute the op
			bool success = _call(sender, to, value, data);

			if (guard != address(0)) {
				_postCallGuard(guard, op, success);
			}

			unchecked {
				++i;
			}
		}
	}

	/**
	 * @dev Validates the nonce of a user operation against the nonce stored in the account.
	 * @param op The user operation to validate.
	 * @param sender The address of the account to validate against.
	 * Requirements:
	 * - The nonce in the user operation must match the nonce in the account.
	 */
	function _validateNonce(UserOperation calldata op, address sender, uint192 key) internal virtual {
		uint256 nonce = getNonce(sender, key);

		// the nonce in the user op must match the nonce in the account
		require(nonce == op.nonce, "AA25 invalid account nonce");
	}

	/**
	 * @dev Validates a user operation and its signature.
	 * @param op The user operation to validate.
	 * @param sender The address of the sender of the user operation.
	 */
	function _validateAccount(UserOperation calldata op, address sender, uint192 key) internal virtual {
		// verify the user op signature
		require(validateUserOp(op, getUserOpHash(op)), "AA24 signature error");

		// INonceManager(_entrypoint).incrementNonce(key);
		// Call incrementNonce through the Safe
		bytes memory incrementNonceData = abi.encodeWithSelector(INonceManager.incrementNonce.selector, key);
		_call(sender, address(_entrypoint), 0, incrementNonceData);
	}

	/**
	 * @dev Initializes a new account using the provided UserOperation.
	 * @param op The UserOperation which contains the initCode.
	 */
	function _initAccount(UserOperation calldata op, address sender) internal virtual {
		bytes calldata initCode = op.initCode;

		// initCode must be at least 20 bytes long, and the first 20 bytes must be the factory address
		require(initCode.length >= 20, "AA17 invalid initCode");

		address factory = address(bytes20(initCode[0:20]));

		// the factory in the init code must be deployed
		require(_contractExists(factory), "AA16 invalid factory or does not exist");

		// call the factory
		address created = senderCreator.createSender(initCode);

		require(sender != address(0), "AA13 initCode failed or OOG");
		require(sender == created, "AA14 initCode must return sender");

		// the account must be created
		require(_contractExists(created), "AA15 initCode must create sender");
	}

	/**
	 * @dev Validates the paymaster address and data of a user operation.
	 * @param op The user operation to validate.
	 */
	function _validatePaymasterUserOp(UserOperation calldata op) internal virtual {
		address paymasterAddress = _getPaymaster(op);

		// verify paymasterAndData signature
		(, uint256 validationData) = IPaymaster(paymasterAddress).validatePaymasterUserOp(op, op.hash(), 0);

		address pmAggregator;
		bool outOfTimeRange;
		(pmAggregator, outOfTimeRange) = _getValidationData(validationData);
		if (pmAggregator != address(0)) {
			revert("AA34 signature error");
		}
		if (outOfTimeRange) {
			revert("AA32 paymaster expired or not due");
		}
	}

	function _getValidationData(
		uint256 validationData
	) internal view returns (address aggregator, bool outOfTimeRange) {
		if (validationData == 0) {
			return (address(0), false);
		}
		ValidationData memory data = _parseValidationData(validationData);
		// solhint-disable-next-line not-rely-on-time
		outOfTimeRange = block.timestamp > data.validUntil || block.timestamp < data.validAfter;
		aggregator = data.aggregator;
	}

	function _getPaymaster(UserOperation calldata op) internal virtual returns (address) {
		bytes calldata paymasterAndData = op.paymasterAndData;

		// paymasterAndData must be at least 20 bytes long, and the first 20 bytes must be the paymaster address
		require(paymasterAndData.length >= 20, "AA36 invalid paymaster data");

		address paymasterAddress = address(bytes20(paymasterAndData[0:20]));

		require(_contractExists(paymasterAddress), "AA30 paymaster not deployed");

		return paymasterAddress;
	}

	bytes4 private executeSelector;

	/**
	 * @dev Validates the call data in the user operation to make sure that only the functions we chose are allowed and that only whitelisted smart contracts can be called.
	 * @param op The user operation to validate.
	 */
	function _validateCallData(UserOperation calldata op) internal virtual {
		// callData must be at least 4 bytes long, and the first 4 bytes must be the function selector
		require(op.callData.length >= 4, "AA26 invalid calldata");

		bytes4 selector = bytes4(op.callData[0:4]);

		// the function selector must be valid
		require(selector != bytes4(0), "AA27 invalid function selector");

		// we only allow execute or executeBatch calls
		require(selector == executeSelector, "AA27 invalid function selector");
	}

	/**
	 * @dev Extracts the address from the call data of a user operation.
	 * @param rawData The call data to extract the address from.
	 * @return An address.
	 */
	function _parseFromCallData(bytes calldata rawData) internal pure returns (address, uint256, bytes memory) {
		// Decode the first argument as an address (the aaModule address)
		(address to, uint256 value, bytes memory data) = abi.decode(rawData[4:], (address, uint256, bytes));

		return (to, value, data);
	}

	/**
	 * generate a request Id - unique identifier for this request.
	 * the request ID is a hash over the content of the userOp (except the signature), the entrypoint and the chainid.
	 */
	function getUserOpHash(UserOperation calldata userOp) public view returns (bytes32) {
		return keccak256(abi.encode(userOp.hash(), address(this), block.chainid));
	}

	/**
	 * @dev Checks if a contract exists at a given address.
	 * @param contractAddress The address to check.
	 * @return A boolean indicating whether a contract exists at the given address.
	 */
	function _contractExists(address contractAddress) internal virtual returns (bool) {
		uint256 size;
		assembly {
			size := extcodesize(contractAddress)
		}
		return size > 0;
	}

	function _getSafeGuard(address safe) internal virtual returns (address) {
		uint256 offset = uint256(GUARD_STORAGE_SLOT);
		bytes memory storageData = StorageAccessible(safe).getStorageAt(offset, 1);
		address guard = address(uint160(uint256(bytes32(storageData))));
		return guard;
	}

	function _preCallGuard(
		address guard,
		address to,
		uint256 value,
		bytes memory data,
		UserOperation calldata op
	) internal virtual {
		address sender = op.getSender();

		Guard(guard).checkTransaction(
			to,
			value,
			data,
			Enum.Operation.Call,
			0,
			0,
			0,
			address(0),
			payable(0),
			op.signature,
			sender
		);
	}

	function _postCallGuard(address guard, UserOperation calldata op, bool success) internal virtual {
		Guard(guard).checkAfterExecution(op.hash(), success);
	}

	/**
	 * @dev Internal function to call a contract with value and data.
	 * If the call fails, it reverts with the reason returned by the callee.
	 * @param sender The address of the sender of the user operation.
	 * @param to The address of the contract to call.
	 * @param value The amount of ether to send with the call.
	 * @param data The data to send with the call.
	 */
	function _call(address sender, address to, uint256 value, bytes memory data) internal returns (bool) {
		(bool success, bytes memory result) = Safe(payable(sender)).execTransactionFromModuleReturnData(
			to,
			value,
			data,
			Enum.Operation.Call
		);
		if (!success) {
			assembly {
				revert(add(result, 32), mload(result))
			}
		}

		return success;
	}

	function _authorizeUpgrade(address newImplementation) internal view override onlyOwner {
		(newImplementation);
	}
}
