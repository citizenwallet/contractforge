// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import { Script, console } from "forge-std/Script.sol";

import { OnRampSwapper } from "../src/OnRampProvider/OnRampSwapper.sol";

contract OnRampSwapperScript is Script {
	function deploy(address _quickswapRouter, address _ctznToken, address _treasuryAddress) public {
		uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
		address deployerAddress = vm.envAddress("ACCOUNT_ADDRESS");
		vm.startBroadcast(deployerPrivateKey);

		address implementation = address(new OnRampSwapper(_quickswapRouter, _ctznToken, _treasuryAddress));

		console.logAddress(implementation);

		vm.stopBroadcast();
	}
}
