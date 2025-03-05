// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import { Script, console } from "forge-std/Script.sol";

import { Paymaster } from "../src/Modules/Community/Paymaster.sol";

import { Create2 } from "../src/Create2/Create2.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract PaymasterDeploy is Script {
	function deploy(address sponsor, address[] calldata addresses) external {
		uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

		vm.startBroadcast(deployerPrivateKey);

		// Deploy the implementation contract
		// address implementation = address(new Paymaster());

		// bytes memory data = abi.encodeCall(Paymaster.initialize, (sponsor, addresses));
		// address proxyAddress = address(new ERC1967Proxy(implementation, data));

		Paymaster implementation = new Paymaster();

		// Prepare initialization data
		bytes memory initData = abi.encodeCall(Paymaster.initialize, (sponsor, addresses));

		// Prepare the creation code for the proxy
		bytes memory proxyBytecode = abi.encodePacked(
			type(ERC1967Proxy).creationCode,
			abi.encode(address(implementation), initData)
		);

		bytes32 salt = keccak256(abi.encodePacked("PAYMASTER_GRATITUDE"));

		// Deploy the proxy using Create2
		address proxyAddress = Create2(vm.envAddress("CREATE2_FACTORY_ADDRESS")).deploy(salt, proxyBytecode);

		if (proxyAddress == address(0)) {
			console.log("Paymaster proxy deployment failed");
			vm.stopBroadcast();
			return;
		}

		console.log("Paymaster implementation created at: ", address(implementation));
		console.log("Paymaster proxy created at: ", proxyAddress);

		vm.stopBroadcast();
	}
}
