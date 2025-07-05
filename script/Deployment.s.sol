// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "./Network.s.sol";
import { Safe, OwnerManager, ModuleManager, Enum } from "safe-smart-account/contracts/Safe.sol";
import { SafeProxy } from "safe-smart-account/contracts/proxies/SafeProxy.sol";
import { SafeProxyFactory } from "safe-smart-account/contracts/proxies/SafeProxyFactory.sol";
import { SafeSuiteLib } from "../src/utils/SafeSuiteLib.sol";

/**
 * @dev script to deploy module and safes
 */
contract DeploymentScript is NetworkUtilsScript {
	bytes internal approvalHashSig =
		abi.encodePacked(
			abi.encode(
				// Encode the contract's address to be used in EIP-1271 signature verification
				bytes32(uint256(uint160(address(this)))),
				bytes32(0)
			),
			bytes1(hex"01")
		);

	/**
	 * @dev Create safes with a deployed faucet module
	 * @param numSafe number of Safe instances to be created
	 * @param fundValue ether value in finney (1e15 wei) to send to each Safe
	 * @param safeModule address of faucet module
	 * @return safes addresses of created safe instances
	 */
	function createSafesWithModule(
		uint256 numSafe,
		uint256 fundValue,
		address safeModule
	) public payable returns (address[] memory safes) {
		// get network and msg sender
		getNetworkAndMsgSender();

		// deploy safes and transfer msg.value equally to each safe
		safes = new address[](numSafe);
		for (uint256 i = 0; i < safes.length; i++) {
			safes[i] = deploySafe(
				vm.addr(deployerPrivateKey),
				uint256(keccak256(abi.encodePacked(deployerPrivateKey, i, block.number)))
			);

			payable(safes[i]).transfer(fundValue * 1e15);

			// add module to Safe proxy
			bytes memory enableModuleData = abi.encodeWithSelector(ModuleManager.enableModule.selector, safeModule);
			prepareSafeTx(Safe(payable(safes[i])), 0, enableModuleData);

			bool isEnabled = Safe(payable(safes[i])).isModuleEnabled(safeModule);
			console.log("isEnabled", isEnabled);

			// return the safe instance
			emit log_named_address("Safe", safes[i]);
		}

		vm.stopBroadcast();
	}

	function enableModule(address[] memory safes, address safeModule) public payable {
		// get network and msg sender
		getNetworkAndMsgSender();

		for (uint256 i = 0; i < safes.length; i++) {
			Safe safe = Safe(payable(safes[i]));

			// Check if the module is already enabled
			if (safe.isModuleEnabled(safeModule)) {
				continue;
			}

			// Prepare the transaction to enable the module
			bytes memory enableModuleData = abi.encodeWithSelector(ModuleManager.enableModule.selector, safeModule);

			// Execute the transaction to enable the module
			bool success = executeSafeTx(safe, enableModuleData);

			if (success) {
				emit log_named_address("Safe with module enabled", safes[i]);
			}
		}

		vm.stopBroadcast();
	}

	function executeSafeTx(Safe safe, bytes memory data) private returns (bool) {
		bytes32 txHash = safe.getTransactionHash(
			address(safe),
			0,
			data,
			Enum.Operation.Call,
			0,
			0,
			0,
			address(0),
			address(0),
			safe.nonce()
		);

		(uint8 v, bytes32 r, bytes32 s) = vm.sign(deployerPrivateKey, txHash);
		bytes memory signature = abi.encodePacked(r, s, v);

		try
			safe.execTransaction(
				address(safe),
				0,
				data,
				Enum.Operation.Call,
				0,
				0,
				0,
				address(0),
				payable(address(0)),
				signature
			)
		returns (bool success) {
			return success;
		} catch {
			return false;
		}
	}

	/**
	 * @dev deploy a vanilla safe
	 * @param owner owner address
	 * @param nonce nonce for creating the safe
	 */
	function deploySafe(address owner, uint256 nonce) public returns (address safeInstanceAddr) {
		// Prepare safe owner
		address[] memory owners = new address[](1);
		owners[0] = owner;
		// Prepare safe initializer data
		bytes memory safeInitializer = abi.encodeWithSelector(
			Safe.setup.selector,
			owners,
			1, // threshold
			address(0),
			"",
			SafeSuiteLib.SAFE_CompatibilityFallbackHandler_ADDRESS,
			address(0),
			0,
			address(0)
		);

		// Deploy Safe proxy
		SafeProxy safeProxy = SafeProxyFactory(SafeSuiteLib.SAFE_SafeProxyFactory_ADDRESS).createProxyWithNonce(
			SafeSuiteLib.SAFE_Safe_ADDRESS,
			safeInitializer,
			nonce
		);

		return address(safeProxy);
	}

	/**
	 * @dev utility function to get network and msg sender
	 */
	function getNetworkAndMsgSender() private {
		// 1. Check network and get msg sender
		checkNetwork();

		// 2. start broadcasting
		vm.startBroadcast(deployerPrivateKey);
	}

	/**
	 * @dev prepare Safe tx
	 */
	function prepareSafeTx(Safe safe, uint256 nonce, bytes memory data) private {
		bytes32 dataHash = safe.getTransactionHash(
			address(safe),
			0,
			data,
			Enum.Operation.Call,
			0,
			0,
			0,
			address(0),
			vm.addr(deployerPrivateKey),
			nonce
		);
		(uint8 v, bytes32 r, bytes32 s) = vm.sign(deployerPrivateKey, dataHash);
		safe.execTransaction(
			address(safe),
			0,
			data,
			Enum.Operation.Call,
			0,
			0,
			0,
			address(0),
			payable(vm.addr(deployerPrivateKey)),
			abi.encodePacked(r, s, v)
		);
	}
}
