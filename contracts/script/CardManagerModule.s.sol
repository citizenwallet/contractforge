// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import { Script, console } from "forge-std/Script.sol";

import { CardFactory } from "../src/Modules/CardManager/CardFactory.sol";
import { CardManagerModule } from "../src/Modules/CardManager/CardManagerModule.sol";

contract CardManagerModuleScript is Script {
	function deploy(address communityModule) public returns (CardManagerModule, CardFactory) {
		uint256 deployerPrivateKey = isAnvil()
			? 77_814_517_325_470_205_911_140_941_194_401_928_579_557_062_014_761_831_930_645_393_041_380_819_009_408
			: vm.envUint("PRIVATE_KEY");
		address deployer = vm.addr(deployerPrivateKey);

		vm.startBroadcast(deployerPrivateKey);

		if (isAnvil()) {
			vm.deal(vm.addr(deployerPrivateKey), 100 ether);
		}

		// Chicken and egg deployment
		CardManagerModule cardManagerModule = new CardManagerModule();

		// the card factory needs the card manager module address to deploy
		CardFactory cardFactory = new CardFactory(communityModule, address(cardManagerModule));

		// the card manager module needs the card factory address in order to function
		cardManagerModule.initialize(deployer, address(cardFactory));

		vm.stopBroadcast();

		return (cardManagerModule, cardFactory);
	}

	function isAnvil() private view returns (bool) {
		return block.chainid == 31_337;
	}
}
