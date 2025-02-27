// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Safe, ModuleManager } from "safe-smart-account/contracts/Safe.sol";
import { SafeProxyFactory } from "safe-smart-account/contracts/proxies/SafeProxyFactory.sol";
import { SafeProxy } from "safe-smart-account/contracts/proxies/SafeProxy.sol";

import { SafeSuiteLib } from "../../utils/SafeSuiteLib.sol";

contract TwoFAFactory is SafeProxyFactory {
	address immutable public COMMUNITY_MODULE;
	address immutable public SESSION_MANAGER_MODULE;

	string public constant NAME = "2FA Factory";
	string public constant VERSION = "0.0.1";

	constructor(address _communityModule, address _sessionManagerModule) {
		COMMUNITY_MODULE = _communityModule;
		SESSION_MANAGER_MODULE = _sessionManagerModule;
	}

	/**
	 * @notice Creates a new account
	 * @dev This function creates a new account by deploying a Safe proxy and enabling the CommunityModule
	 * @param _provider The address of the account owner
	 * @param _salt A unique number to ensure different salts for the same owner
	 * @return address The address of the created account
	 */
	function createAccount(address _provider, uint256 _salt) external returns (address) {
		// compute the address of the account
		address safeAddress = getAddress(_provider, _salt);
		// check if the account already exists
		if (isContract(safeAddress)) {
			// skip the deployment
			return safeAddress;
		}

		bytes memory safeInitializer = _getInitializer(safeAddress);
		bytes32 salt = _getSalt(_provider, _salt);

		// Deploy Safe proxy
		SafeProxy safeProxy = deployProxy(SafeSuiteLib.SAFE_Safe_ADDRESS, safeInitializer, salt);

		emit ProxyCreation(safeProxy, SafeSuiteLib.SAFE_Safe_ADDRESS);

		return address(safeProxy);
	}

	/**
	 * @notice Computes the address of a proxy that would be created using CREATE2
	 * @param _provider Address of the owner
	 * @param _salt Nonce that will be used to generate the salt
	 * @return The computed address of the proxy
	 */
	function getAddress(address _provider, uint256 _salt) public view returns (address) {
		bytes32 create2Input = _getCreate2Input(_provider, _salt);

		return address(uint160(uint256(create2Input)));
	}

	/**
	 * @notice Generates a unique salt for CREATE2 deployment
	 * @dev This function combines the owner's address and a nonce to create a unique identifier
	 * @param _provider The address of the account owner
	 * @param _salt A unique number to ensure different salts for the same owner
	 * @return bytes32 A unique salt value used in CREATE2 deployment
	 */
	function _getSalt(address _provider, uint256 _salt) internal pure returns (bytes32) {
		return keccak256(abi.encodePacked(_provider, _salt));
	}

	/**
	 * @notice Generates the CREATE2 input for the Safe proxy
	 * @dev This function combines the proxy creation code and the salt to generate a unique identifier
	 * @param _provider The address of the account owner
	 * @param _salt A unique number to ensure different salts for the same owner
	 * @return bytes32 The CREATE2 input value used in the proxy creation
	 */
	function _getCreate2Input(address _provider, uint256 _salt) internal view returns (bytes32) {
		bytes32 salt = _getSalt(_provider, _salt);

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
	 * @param _safe The address of the Safe proxy
	 * @return bytes memory The initializer data for the Safe proxy
	 */
	function _getInitializer(address _safe) internal view returns (bytes memory) {
		address[] memory owners = new address[](0);

		address[] memory modules = new address[](2);
		modules[0] = COMMUNITY_MODULE;
		modules[1] = SESSION_MANAGER_MODULE;

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
			SafeSuiteLib.SAFE_TokenCallbackHandler_ADDRESS, // fallbackHandler
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
