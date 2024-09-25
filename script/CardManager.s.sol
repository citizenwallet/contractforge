// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Script.sol";

import "account-abstraction/interfaces/IEntryPoint.sol";

import "../src/CardManager/interfaces/ITokenEntryPoint.sol";

import { Create2 } from "../src/Create2/Create2.sol";
import { CardManager } from "../src/CardManager/CardManager.sol";

contract CardManagerDeploy is Script {
	function run() external {
		uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
		address owner = vm.envAddress("OWNER_ADDRESS");
		address entrypoint = vm.envAddress("ERC4337_ENTRYPOINT");
		// address tokenEntrypoint = vm.envAddress("ERC4337_TOKEN_ENTRYPOINT_BASE"); // BASE
		address tokenEntrypoint = vm.envAddress("ERC4337_TOKEN_ENTRYPOINT_GNOSIS"); // GNOSIS
		vm.startBroadcast(deployerPrivateKey);

		address[] memory whitelist = new address[](0);

		Create2 deployer = Create2(vm.envAddress("CREATE2_FACTORY_ADDRESS"));
		bytes memory bytecode = getCardManagerBytecode(owner);

		bytes32 salt = keccak256(abi.encodePacked("REGEN_VILLAGE_CARD_MANAGER_2"));

		address cm = deployer.deploy(salt, bytecode);

		if (cm == address(0)) {
			console.log("CardManager deployment failed");

			vm.stopBroadcast();
			return;
		}

		console.log("CardManager created at: ", address(cm));

		CardManager(cm).initialize(IEntryPoint(entrypoint), ITokenEntryPoint(tokenEntrypoint), whitelist);

		vm.stopBroadcast();
	}

	function getCardManagerBytecode(address _owner) public pure returns (bytes memory) {
		bytes memory bytecode = type(CardManager).creationCode;
		return abi.encodePacked(bytecode, abi.encode(_owner));
	}
}
