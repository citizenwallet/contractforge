// script/UpgradeCommunityModule.s.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Script, console } from "forge-std/Script.sol";
import { CommunityModule } from "../../src/Modules/Community/CommunityModule.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { INonceManager } from "account-abstraction/interfaces/INonceManager.sol";

contract UpgradeCommunityModuleScript is Script {
	function run(address proxyAddress) external {
		uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
		vm.startBroadcast(deployerPrivateKey);

        address entryPoint = vm.envAddress("ERC4337_ENTRYPOINT");

		// Deploy the new implementation
		CommunityModule newImplementation = new CommunityModule(INonceManager(entryPoint));

		// Upgrade the proxy to the new implementation
		UUPSUpgradeable proxy = UUPSUpgradeable(proxyAddress);
		proxy.upgradeToAndCall(
			address(newImplementation),
			"" // No initialization function call needed for this upgrade
		);

		vm.stopBroadcast();

		console.log("Upgraded proxy at %s to implementation at %s", proxyAddress, address(newImplementation));
	}
}
