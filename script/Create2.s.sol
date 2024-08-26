// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import { Script, console } from "forge-std/Script.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { Upgrades } from "openzeppelin-foundry-upgrades/Upgrades.sol";

import { BadgeCollection } from "../src/BadgeCollection.sol";

contract BadgeCollectionScript is Script {
	BadgeCollection public badgeCollection;
	address public proxy;

	function setUp() public {
		badgeCollection = new BadgeCollection();
		// bytes memory data = abi.encodeWithSignature("initialize(address)", address(this));
		// proxy = new ERC1967Proxy(address(badgeCollection), data);
		proxy = Upgrades.deployUUPSProxy(
			"BadgeCollection.sol",
			abi.encodeCall(BadgeCollection.initialize, (address(this)))
		);

		badgeCollection = BadgeCollection(address(proxy));
	}

	function run() public {
		vm.broadcast();

		// interact with contract manually

		vm.stopBroadcast();
	}
}
