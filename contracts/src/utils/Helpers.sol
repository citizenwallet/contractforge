// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

function toEthSignedMessageHash(bytes32 hash) pure returns (bytes32 message) {
	// 32 is the length in bytes of hash,
	// enforced by the type signature above
	/// @solidity memory-safe-assembly
	assembly {
		mstore(0x00, "\x19Ethereum Signed Message:\n32")
		mstore(0x1c, hash)
		message := keccak256(0x00, 0x3c)
	}
}
