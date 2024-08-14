// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import { INonceManager } from "account-abstraction/interfaces/INonceManager.sol";
import { ModuleManager } from "safe-smart-account/contracts/Safe.sol";
import { CommunityModule } from "../src/Modules/Community/CommunityModule.sol";
import { SafeSuiteSetupScript } from "../script/SafeSuiteSetup.s.sol";
import { DeploymentScript } from "../script/Deployment.s.sol";

contract CounterModuleTest is Test {
	CommunityModule public communityModule;
    address public safeSingleton;
	address[] public safes;

	function setUp() public {
        // Deploy the safe singleton
		SafeSuiteSetupScript setupScript = new SafeSuiteSetupScript();
		setupScript.run();

		safeSingleton = setupScript.SAFE_SINGLETON_ADDRESS();

		DeploymentScript deploymentScript = new DeploymentScript();
		deploymentScript.fundDeployer();

		// Deploy the community module
		address entryPoint = vm.envAddress("ERC4337_ENTRYPOINT");
		communityModule = new CommunityModule(INonceManager(entryPoint));
		safes = deploymentScript.createSafesWithModule(3, 300, address(communityModule));
	}

	function testModuleIsEnabled() public {
		for (uint256 i = 0; i < safes.length; i++) {
			bool isEnabled = ModuleManager(payable(safes[i])).isModuleEnabled(address(communityModule));
			assertTrue(isEnabled, "CounterModule should be enabled for the Safe");
		}
	}
}
