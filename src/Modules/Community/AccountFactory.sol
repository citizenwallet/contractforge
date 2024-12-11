// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Safe, ModuleManager } from "safe-smart-account/contracts/Safe.sol";
import { SafeProxyFactory } from "safe-smart-account/contracts/proxies/SafeProxyFactory.sol";
import { SafeProxy } from "safe-smart-account/contracts/proxies/SafeProxy.sol";

import { SafeSuiteLib } from "../../utils/SafeSuiteLib.sol";

contract AccountFactory is SafeProxyFactory {
	address immutable communityModule;

	string public constant NAME = "Account Factory";
	string public constant VERSION = "0.0.1";

	constructor(address _communityModule) {
		communityModule = _communityModule;
	}

	/**
	 * @notice Creates a new account
	 * @dev This function creates a new account by deploying a Safe proxy and enabling the CommunityModule
	 * @param _owner The address of the account owner
	 * @param _nonce A unique number to ensure different salts for the same owner
	 * @return address The address of the created account
	 */
	function createAccount(address _owner, uint256 _nonce) external returns (address) {
		// compute the address of the account
		address safeAddress = getAddress(_owner, _nonce);
		// check if the account already exists
		if (isContract(safeAddress)) {
			// skip the deployment
			return safeAddress;
		}

		bytes memory safeInitializer = _getInitializer(_owner, safeAddress);
		bytes32 salt = _getSalt(_owner, _nonce);

		// Deploy Safe proxy
		SafeProxy safeProxy = deployProxy(SafeSuiteLib.SAFE_Safe_ADDRESS, safeInitializer, salt);

		emit ProxyCreation(safeProxy, SafeSuiteLib.SAFE_Safe_ADDRESS);

		return address(safeProxy);
	}

	/**
	 * @notice Computes the address of a proxy that would be created using CREATE2
	 * @param _owner Address of the owner
	 * @param _nonce Nonce that will be used to generate the salt
	 * @return The computed address of the proxy
	 */
	function getAddress(address _owner, uint256 _nonce) public view returns (address) {
		bytes32 create2Input = _getCreate2Input(_owner, _nonce);

		return address(uint160(uint256(create2Input)));
	}

	/**
	 * @notice Generates a unique salt for CREATE2 deployment
	 * @dev This function combines the owner's address and a nonce to create a unique identifier
	 * @param _owner The address of the account owner
	 * @param _nonce A unique number to ensure different salts for the same owner
	 * @return bytes32 A unique salt value used in CREATE2 deployment
	 */
	function _getSalt(address _owner, uint256 _nonce) internal pure returns (bytes32) {
		return keccak256(abi.encodePacked(_owner, _nonce));
	}

	/**
	 * @notice Generates the CREATE2 input for the Safe proxy
	 * @dev This function combines the proxy creation code and the salt to generate a unique identifier
	 * @param _owner The address of the account owner
	 * @param _nonce A unique number to ensure different salts for the same owner
	 * @return bytes32 The CREATE2 input value used in the proxy creation
	 */
	function _getCreate2Input(address _owner, uint256 _nonce) internal view returns (bytes32) {
		bytes32 salt = _getSalt(_owner, _nonce);

		return
			keccak256(
				abi.encodePacked(
					bytes1(0xff),
					address(this),
					salt,
					keccak256(abi.encodePacked(proxyCreationCode(), uint256(uint160(SafeSuiteLib.SAFE_Safe_ADDRESS))))
				)
			);
	}

	/**
	 * @notice Generates the initializer data for the Safe proxy
	 * @dev This function sets up the Safe with the necessary owners and modules
	 * @param _owner The address of the account owner
	 * @param _safe The address of the Safe proxy
	 * @return bytes memory The initializer data for the Safe proxy
	 */
	function _getInitializer(address _owner, address _safe) internal view returns (bytes memory) {
		address[] memory owners = new address[](1);
		owners[0] = _owner;

		address[] memory modules = new address[](1);
		modules[0] = communityModule;

		// Prepare the data to call enableModule on the CommunityModule
		// Encode the enableModule function call
		bytes memory enableModuleData = abi.encodeCall(this.enableModules, (_safe, modules));

		// Prepare safe initializer data
		bytes memory safeInitializer = abi.encodeWithSelector(
			Safe.setup.selector,
			owners,
			1, // threshold
			address(this), // to
			enableModuleData, // data
			// address(0), // to
			// "", // data
			SafeSuiteLib.SAFE_CompatibilityFallbackHandler_ADDRESS, // fallbackHandler
			address(0), // paymentToken
			0, // payment
			address(0) // paymentReceiver
		);
		return safeInitializer;
	}

	/**
	 * @notice Enables modules on the Safe proxy
	 * @dev Can only be called as a part of the initialization process of a Safe
	 * @param _safe The address of the Safe proxy
	 * @param _safeModules The address of the modules to enable
	 */
	function enableModules(address _safe, address[] memory _safeModules) public payable {
		Safe safe = Safe(payable(_safe));

		for (uint256 i = 0; i < _safeModules.length; i++) {
			address module = _safeModules[i];

			// Check if the module is already enabled
			if (ModuleManager(payable(safe)).isModuleEnabled(module)) {
				continue;
			}

			ModuleManager(payable(safe)).enableModule(module);
		}
	}
}
