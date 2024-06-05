// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import { Script, console } from "forge-std/Script.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import { INonceManager } from "@account-abstraction/contracts/interfaces/INonceManager.sol";

// 4337
import { EntryPoint } from "@cloned/entrypoint/core/EntryPoint.sol";
import { TokenEntryPoint } from "../src/4337/TokenEntryPoint.sol";

import { BadgeCollection } from "../src/BadgeCollection.sol";

contract BadgeCollectionScript is Script {
	BadgeCollection public badgeCollection;
	EntryPoint public entryPoint;
	TokenEntryPoint public tokenEntryPoint;

	address public proxy;

	function run() public {
		uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
		address deployerAddress = vm.envAddress("ACCOUNT_ADDRESS");
		vm.startBroadcast(deployerPrivateKey);

		badgeCollection = new BadgeCollection();
		entryPoint = new EntryPoint();
		tokenEntryPoint = new TokenEntryPoint(INonceManager(address(entryPoint)));

		address implementation = address(new BadgeCollection());

		bytes memory data = abi.encodeCall(BadgeCollection.initialize, deployerAddress);
		proxy = address(new ERC1967Proxy(implementation, data));

		badgeCollection = BadgeCollection(proxy);

		vm.stopBroadcast();
	}
}
