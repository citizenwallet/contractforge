// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import { Script, console } from "forge-std/Script.sol";

import { TwoFAFactory } from "../src/Modules/Session/TwoFAFactory.sol";
import { SessionManagerModule } from "../src/Modules/Session/SessionManagerModule.sol";

contract SessionManagerModuleScript is Script {
	function deploy(address communityModule) public returns (SessionManagerModule, TwoFAFactory) {
		uint256 deployerPrivateKey = isAnvil()
			? 77_814_517_325_470_205_911_140_941_194_401_928_579_557_062_014_761_831_930_645_393_041_380_819_009_408
			: vm.envUint("PRIVATE_KEY");
		address deployer = vm.addr(deployerPrivateKey);

		vm.startBroadcast(deployerPrivateKey);

		if (isAnvil()) {
			vm.deal(vm.addr(deployerPrivateKey), 100 ether);
		}

		// Chicken and egg deployment
		SessionManagerModule sessionManagerModule = new SessionManagerModule();

		// the card factory needs the card manager module address to deploy
		TwoFAFactory twoFAFactory = new TwoFAFactory(communityModule, address(sessionManagerModule));

		// the card manager module needs the card factory address in order to function
		sessionManagerModule.initialize(deployer, address(twoFAFactory));

		vm.stopBroadcast();

		console.log("SessionManagerModule created at: ", address(sessionManagerModule));
		console.log("TwoFAFactory created at: ", address(twoFAFactory));

		return (sessionManagerModule, twoFAFactory);
	}

	function isAnvil() private view returns (bool) {
		return block.chainid == 31_337;
	}
}
