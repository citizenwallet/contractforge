// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import { Script, console } from "forge-std/Script.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import { BadgeCollection } from "../src/BadgeCollection.sol";

contract BadgeCollectionScript is Script {
	BadgeCollection public badgeCollection;

	address public proxy;

	function run() public {
		uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
		address deployerAddress = vm.envAddress("ACCOUNT_ADDRESS");
		vm.startBroadcast(deployerPrivateKey);

		address implementation = address(new BadgeCollection());

		bytes memory data = abi.encodeCall(BadgeCollection.initialize, deployerAddress);
		proxy = address(new ERC1967Proxy(implementation, data));

		badgeCollection = BadgeCollection(proxy);

		console.logAddress(proxy);

		vm.stopBroadcast();
	}
}
