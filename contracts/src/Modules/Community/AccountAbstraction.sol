// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { INonceManager } from "account-abstraction/interfaces/INonceManager.sol";

import { Safe, OwnerManager, ModuleManager, Enum } from "safe-smart-account/contracts/Safe.sol";
import { CompatibilityFallbackHandler } from "safe-smart-account/contracts/handler/CompatibilityFallbackHandler.sol";

import { UserOperation, UserOperationLib } from "account-abstraction/interfaces/UserOperation.sol";

import { toEthSignedMessageHash } from "../../utils/Helpers.sol";

error CountIsZero(address safeAddr);
error ModuleNotEnabled(address safeAddr);

contract AccountAbstractionModule is CompatibilityFallbackHandler {
	string public constant NAME = "Account Abstraction Module";
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
					this
				)
			);
	}

	/**
	 * @dev Throws if the caller is not an enabled module.
	 */
	modifier onlyWhenModuleIsEnabled(address safeAddr) {
		bool isEnabled = ModuleManager(payable(safeAddr)).isModuleEnabled(address(this));
		if (!isEnabled) revert ModuleNotEnabled(safeAddr);
		_;
	}

	uint256 internal constant SIG_VALIDATION_FAILED = 1;

	/// implement template method of BaseAccount
	// function _validateSignature(
	// 	UserOperation calldata userOp,
	// 	bytes32 userOpHash
	// ) internal view override returns (uint256 validationData) {
	// 	bytes32 hash = userOpHash.toEthSignedMessageHash();
	// 	if (owner() != hash.recover(userOp.signature)) return SIG_VALIDATION_FAILED;
	// 	return 0;
	// }

	// function validateUserOp(UserOperation calldata userOp, bytes32 userOpHash) external returns (bool) {
	// 	bool isValid = _validateSignature(userOp, userOpHash) == 0;
	// 	if (isValid) {
	// 		uint192 key = _parseNonce(userOp.nonce);
	// 		INonceManager(entryPoint()).incrementNonce(key);
	// 	}

	// 	return isValid;
	// }

	// ************************

	// related to safe specific methods

	function _checkSignaturesLength(bytes calldata signatures, uint256 threshold) internal pure returns (bool isValid) {
		uint256 maxLength = threshold * 0x41;

		// Make sure that `signatures` bytes are at least as long as the static part of the signatures for the specified
		// threshold (i.e. we have at least 65 bytes per signer). This avoids out-of-bound access reverts when decoding
		// the signature in order to adhere to the ERC-4337 specification.
		if (signatures.length < maxLength) {
			return false;
		}

		for (uint256 i = 0; i < threshold; i++) {
			// Each signature is 0x41 (65) bytes long, where fixed part of a Safe contract signature is encoded as:
			//      {32-bytes signature verifier}{32-bytes dynamic data position}{1-byte signature type}
			// and the dynamic part is encoded as:
			//      {32-bytes signature length}{bytes signature data}
			//
			// For each signature we check whether or not the signature is a contract signature (signature type of 0).
			// If it is, we need to read the length of the contract signature bytes from the signature data, and add it
			// to the maximum signatures length.
			//
			// In order to keep the implementation simpler, and unlike in the length check above, we intentionally
			// revert here on out-of-bound bytes array access as well as arithmetic overflow, as you would have to
			// **intentionally** build invalid `signatures` data to trigger these conditions. Furthermore, there are no
			// security issues associated with reverting in these cases, just not optimally following the ERC-4337
			// standard (specifically: "SHOULD return `SIG_VALIDATION_FAILED` (and not revert) on signature mismatch").

			uint256 signaturePos = i * 0x41;
			uint8 signatureType = uint8(signatures[signaturePos + 0x40]);

			if (signatureType == 0) {
				uint256 signatureOffset = uint256(bytes32(signatures[signaturePos + 0x20:]));
				uint256 signatureLength = uint256(bytes32(signatures[signatureOffset:]));
				maxLength += 0x20 + signatureLength;
			}
		}

		isValid = signatures.length <= maxLength;
	}

	// function _validateSignatures(PackedUserOperation calldata userOp) internal view returns (uint256 validationData) {
	// 	(bytes memory operationData, uint48 validAfter, uint48 validUntil, bytes calldata signatures) = _getSafeOp(
	// 		userOp
	// 	);

	// 	// The `checkSignatures` function in the Safe contract does not force a fixed size on signature length.
	// 	// A malicious bundler can pad the Safe operation `signatures` with additional bytes, causing the account to pay
	// 	// more gas than needed for user operation validation (capped by `verificationGasLimit`).
	// 	// `_checkSignaturesLength` ensures that there are no additional bytes in the `signature` than are required.
	// 	bool validSignature = _checkSignaturesLength(signatures, ISafe(payable(userOp.sender)).getThreshold());

	// 	try
	// 		ISafe(payable(userOp.sender)).checkSignatures(keccak256(operationData), operationData, signatures)
	// 	{} catch {
	// 		validSignature = false;
	// 	}

	// 	// The timestamps are validated by the entry point, therefore we will not check them again.
	// 	validationData = _packValidationData(!validSignature, validUntil, validAfter);
	// }

	// ************************

	// related to nonces

	// parse uint192 key from uint256 nonce
	function _parseNonce(uint256 nonce) internal pure returns (uint192 key) {
		return uint192(nonce >> 64);
	}

	// ************************
}
