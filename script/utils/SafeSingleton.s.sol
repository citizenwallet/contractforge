// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// @custom:artifact-size-ignore

import "forge-std/Script.sol";
import "../../src/utils/SafeSuiteLib.sol";
import "./SafeBytecode.sol";
import "./SafeDeploymentBytecode.sol";

/**
 * Contract deployed bytecode and addresses
 * https://github.com/safe-global/safe-deployments
 */
contract SafeSingletonScript is Script {
	address public constant SAFE_SINGLETON_ADDRESS = 0x41675C099F32341bf84BFc5382aF534df5C7461a;
	SafeDeploymentBytecode public bytecodeLib;

	function setUp() public virtual {
		// deploy singleton contract
		vm.etch(SAFE_SINGLETON_ADDRESS, SafeBytecode.MAINNET_SAFE_SINGLETON_DEPLOYED_CODE);

		bytecodeLib = new SafeDeploymentBytecode();
		deployEntireSafeSuite();
	}

	/**
	 * @dev Check if the base Singleton deployment factory contract exists
	 */
	function hasSingletonContract() internal view returns (bool) {
		uint256 singletonCodeSize = 0;
		assembly {
			singletonCodeSize := extcodesize(SAFE_SINGLETON_ADDRESS)
		}
		return singletonCodeSize > 0;
	}

	/**
	 * @dev The base Singleton deployment factory contract must exist
	 */
	function mustHaveSingletonContract() internal view {
		require(hasSingletonContract(), "No Safe Singleton deployed");
	}

	/**
	 * @dev helper function to deploy all the singletons for Safe
	 */
	function deployEntireSafeSuite() internal {
		deploySimulateTxAccessor();
		deploySafeProxyFactory();
		deployTokenCallbackHandler();
		deployCompatibilityFallbackHandler();
		deployCreateCall();
		deployMultiSend();
		deployMultiSendCallOnly();
		deploySignMessageLib();
		deploySafe();
	}

	function deploySimulateTxAccessor() internal {
		deployContractFromSingletonDefault(
			SafeSuiteLib.SAFE_SimulateTxAccessor_ADDRESS,
			bytecodeLib.getSimulateTxAccessorCode()
		);
	}

	/**
	 * @dev deploy the safe proxy factory
	 * @notice Anchored to Safe v1.4.0. The source code is the latest audited version.
	 * bytecode extracted from 0x4e1DCf7AD4e460CfD30791CCC4F9c8a4f820ec67,
	 * according to safe-global/safe-deployments/src/assets/v1.4.0/safe_proxy_factory.json
	 */
	function deploySafeProxyFactory() internal {
		deployContractFromSingletonDefault(
			SafeSuiteLib.SAFE_SafeProxyFactory_ADDRESS,
			bytecodeLib.getSafeProxyFactoryCode()
		);
	}

	/**
	 * @dev deploy the TokenCallbackHandler
	 * @notice Anchored to Safe v1.4.0. The source code is the latest audited version.
	 * bytecode extracted from 0xeDCF620325E82e3B9836eaaeFdc4283E99Dd7562,
	 * according to https://github.com/safe-global/safe-contracts/blob/main/CHANGELOG.md
	 */
	function deployTokenCallbackHandler() internal {
		deployContractFromSingletonDefault(
			SafeSuiteLib.SAFE_TokenCallbackHandler_ADDRESS,
			bytecodeLib.getTokenCallbackHandlerCode()
		);
	}

	/**
	 * @dev deploy the Compatibility Fallback Handler
	 * @notice Anchored to Safe v1.4.0. The source code is the latest audited version.
	 * bytecode extracted from 0x2a15DE4410d4c8af0A7b6c12803120f43C42B820,
	 * according to safe-global/safe-deployments/src/assets/v1.4.0/compatibility_fallback_handler.json
	 */
	function deployCompatibilityFallbackHandler() internal {
		deployContractFromSingletonDefault(
			SafeSuiteLib.SAFE_CompatibilityFallbackHandler_ADDRESS,
			bytecodeLib.getCompatibilityFallbackHandlerCode()
		);
	}

	/**
	 * @dev deploy the Create Call
	 * @notice Anchored to Safe v1.4.0. The source code is the latest audited version.
	 * bytecode extracted from 0x9b35Af71d77eaf8d7e40252370304687390A1A52,
	 * according to safe-global/safe-deployments/src/assets/v1.4.0/create_call.json
	 */
	function deployCreateCall() internal {
		deployContractFromSingletonDefault(
			SafeSuiteLib.SAFE_CreateCall_ADDRESS,
			bytecodeLib.getCreateCallCode()
		);
	}

	/**
	 * @dev deploy the MultiSend
	 * @notice Anchored to Safe v1.4.0. The source code is the latest audited version.
	 * bytecode extracted from 0x38869bf66a61cF6bDB996A6aE40D5853Fd43B526,
	 * according to safe-global/safe-deployments/src/assets/v1.4.0/multi_send.json
	 */
	function deployMultiSend() internal {
		deployContractFromSingletonDefault(
			SafeSuiteLib.SAFE_MultiSend_ADDRESS,
			bytecodeLib.getMultiSendCode()
		);
	}

	/**
	 * @dev deploy the MultiSendCallOnly
	 * @notice Anchored to Safe v1.4.0. The source code is the latest audited version.
	 * bytecode extracted from 0x9641d764fc13c8B624c04430C7356C1C7C8102e2,
	 * according to safe-global/safe-deployments/src/assets/v1.4.0/multi_send_call_only.json
	 */
	function deployMultiSendCallOnly() internal {
		deployContractFromSingletonDefault(
			SafeSuiteLib.SAFE_MultiSendCallOnly_ADDRESS,
			bytecodeLib.getMultiSendCallOnlyCode()
		);
	}

	/**
	 * @dev deploy the sign message lab
	 * @notice Anchored to Safe v1.4.0. The source code is the latest audited version.
	 * bytecode extracted from 0x58FCe385Ed16beB4BCE49c8DF34c7d6975807520,
	 * according to safe-global/safe-deployments/src/assets/v1.4.0/sign_message_lib.json
	 */
	function deploySignMessageLib() internal {
		deployContractFromSingletonDefault(
			SafeSuiteLib.SAFE_SignMessageLib_ADDRESS,
			bytecodeLib.getSignMessageLibCode()
		);
	}

	/**
	 * @dev deploy the safe
	 * @notice Anchored to Safe v1.4.0. The source code is the latest audited version.
	 * bytecode extracted from 0xc962E67D9490E154D81181879ddf4CD3b65D2132,
	 * according to safe-global/safe-deployments/src/assets/v1.4.0/safe.json
	 */
	function deploySafe() internal {
		deployContractFromSingletonDefault(
			SafeSuiteLib.SAFE_Safe_ADDRESS,
			SafeBytecode.MAINNET_SAFE_SINGLETON_DEPLOYED_CODE
		);
	}

	/**
	 * @dev deploy an arbitrary contract from the Singleton contract
	 * without providing the salt, it gets defaut to 0x
	 */
	function deployContractFromSingletonDefault(address expectedAddress, bytes memory contractDeploymentCode) internal {
		if (isContract(expectedAddress)) {
			return;
		}
		bytes memory deploymentCode = abi.encodePacked(bytes32(0x00), contractDeploymentCode);
		(bool success, ) = SAFE_SINGLETON_ADDRESS.call(deploymentCode);
		if (!success) {
			console.log("Cannot deploy safe proxy factory");
		}
	}

	/**
	 * @dev Check if an address is a contract
	 */
	function isContract(address account) internal view returns (bool) {
		uint256 size;
		assembly {
			size := extcodesize(account)
		}
		return size > 0;
	}
}
