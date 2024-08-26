// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import { Script, console } from "forge-std/Script.sol";

import { AccountFactory } from "../src/Modules/Community/AccountFactory.sol";

contract AccountFactoryScript is Script {
	function deploy(address _communityModule) public returns (AccountFactory) {
		uint256 deployerPrivateKey = isAnvil()
			? 77_814_517_325_470_205_911_140_941_194_401_928_579_557_062_014_761_831_930_645_393_041_380_819_009_408
			: vm.envUint("PRIVATE_KEY");

		vm.startBroadcast(deployerPrivateKey);

		if (isAnvil()) {
			vm.deal(vm.addr(deployerPrivateKey), 100 ether);
		}

		AccountFactory accountFactory = new AccountFactory(_communityModule);

		vm.stopBroadcast();

		return accountFactory;
	}

	function isAnvil() private view returns (bool) {
		return block.chainid == 31_337;
	}
}
