// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import { ModuleManager } from "safe-smart-account/contracts/Safe.sol";
import { CounterModule, CountIsZero } from "../src/Modules/CounterModule.sol";
import { SafeSuiteSetupScript } from "../script/SafeSuiteSetup.s.sol";
import { DeploymentScript } from "../script/Deployment.s.sol";

contract CounterModuleTest is Test {
	CounterModule public counterModule;
    address public safeSingleton;
	address[] public safes;

	function setUp() public {
        // Deploy the safe singleton
		SafeSuiteSetupScript setupScript = new SafeSuiteSetupScript();
		setupScript.run();

		safeSingleton = setupScript.SAFE_SINGLETON_ADDRESS();

		DeploymentScript deploymentScript = new DeploymentScript();
		deploymentScript.fundDeployer();

		// Deploy the counter module
		counterModule = CounterModule(deploymentScript.deployModule());
		safes = deploymentScript.createSafesWithModule(3, 300, address(counterModule));
	}

	function testModuleIsEnabled() public {
		for (uint256 i = 0; i < safes.length; i++) {
			bool isEnabled = ModuleManager(payable(safes[i])).isModuleEnabled(address(counterModule));
			assertTrue(isEnabled, "CounterModule should be enabled for the Safe");
		}
	}

	function testInitialCount() public {
	    uint256 initialCount = counterModule.getCount(safes[0]);
	    assertEq(initialCount, 0);
	}

	function testIncrement() public {
	    counterModule.increment(safes[0]);
	    uint256 newCount = counterModule.getCount(safes[0]);
	    assertEq(newCount, 1);
	}

	function testDecrement() public {
	    counterModule.increment(safes[0]); // increment first to avoid underflow
	    counterModule.decrement(safes[0]);
	    uint256 newCount = counterModule.getCount(safes[0]);
	    assertEq(newCount, 0);
	}

	function testDecrementBelowZero() public {
	    vm.expectRevert(abi.encodeWithSelector(CountIsZero.selector, safes[0]));
	    counterModule.decrement(safes[0]);
	}
}
