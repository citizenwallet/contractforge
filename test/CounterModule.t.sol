// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import { ModuleManager, Safe, Enum } from "safe-smart-account/contracts/Safe.sol";
import { CounterModule, CountIsZero } from "../src/Modules/CounterModule.sol";
import { SafeSuiteSetupScript } from "../script/SafeSuiteSetup.s.sol";
import { DeploymentScript } from "../script/Deployment.s.sol";

contract CounterModuleTest is Test {
	CounterModule public counterModule;
	address public safeSingleton;
	address[] public safes;

	uint256 internal deployerPrivateKey;

	function setUp() public {
		// Deploy the safe singleton
		SafeSuiteSetupScript setupScript = new SafeSuiteSetupScript();
		setupScript.run();

		safeSingleton = setupScript.SAFE_SINGLETON_ADDRESS();

		DeploymentScript deploymentScript = new DeploymentScript();
		deploymentScript.fundDeployer();

		// Deploy the counter module
		counterModule = new CounterModule();
		safes = deploymentScript.createSafesWithModule(3, 300, address(counterModule));
	}

	function testModuleIsEnabled() public view {
		for (uint256 i = 0; i < safes.length; i++) {
			bool isEnabled = ModuleManager(payable(safes[i])).isModuleEnabled(address(counterModule));
			assertTrue(isEnabled, "CounterModule should be enabled for the Safe");
		}
	}

	function testInitialCount() public view {
		uint256 initialCount = counterModule.getCount(safes[0]);
		assertEq(initialCount, 0);
	}

	function testIncrement() public {
		// increment through module
		counterModule.callIncrement(safes[0]);

		// Check the final count
		uint256 newCount = counterModule.getCount(safes[0]);
		assertEq(newCount, 1, "Count should be incremented to 1");
	}

	function testDecrement() public {
		// increment through module
		counterModule.callIncrement(safes[0]);
		counterModule.callDecrement(safes[0]);

		// Check the final count
		uint256 newCount = counterModule.getCount(safes[0]);
		assertEq(newCount, 0, "Count should be decremented to 0");
	}

	function testDecrementBelowZero() public {
		bool success = counterModule.callDecrement(safes[0]);
		assertFalse(success, "Decrement should fail when count is zero");
	}
}
