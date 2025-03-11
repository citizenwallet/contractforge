// script/upgrade/TestUpgradeSessionManagerModule.s.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Script, console } from "forge-std/Script.sol";
import { SessionManagerModule } from "../../src/Modules/Session/SessionManagerModule.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract TestUpgradeSessionManagerModuleScript is Script {
    function testDeploy(address proxyAddress) public returns (SessionManagerModule) {
        // Deploy the new implementation
        SessionManagerModule newImplementation = new SessionManagerModule();

        // Upgrade the proxy to the new implementation
        UUPSUpgradeable proxy = UUPSUpgradeable(proxyAddress);
        proxy.upgradeToAndCall(
            address(newImplementation),
            "" // No initialization function call needed for this upgrade
        );

        console.log("Test upgraded SessionManagerModule proxy at %s to implementation at %s", proxyAddress, address(newImplementation));
        
        return newImplementation;
    }

    function run(address proxyAddress) external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        
        testDeploy(proxyAddress);
        
        vm.stopBroadcast();
    }
} 