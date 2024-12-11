// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import { Script, console } from "forge-std/Script.sol";

import { AccountFactory } from "../src/Modules/Community/AccountFactory.sol";

import { Create2 } from "../src/Create2/Create2.sol";

contract AccountFactoryScript is Script {
	function deploy(address _communityModule) public returns (AccountFactory) {
		uint256 deployerPrivateKey = isAnvil()
			? 77_814_517_325_470_205_911_140_941_194_401_928_579_557_062_014_761_831_930_645_393_041_380_819_009_408
			: vm.envUint("PRIVATE_KEY");

		vm.startBroadcast(deployerPrivateKey);

		if (isAnvil()) {
			vm.deal(vm.addr(deployerPrivateKey), 100 ether);
		}

		Create2 create2Deployer = Create2(vm.envAddress("CREATE2_FACTORY_ADDRESS"));
		if (isAnvil()) {
			// Create2 factory is not available on Anvil, make a new one
			create2Deployer = new Create2();
		}

		// Prepare the creation code for the actual contract (not a proxy)
		bytes memory contractBytecode = abi.encodePacked(
			type(AccountFactory).creationCode,
			abi.encode(_communityModule)
		);

		bytes32 salt = keccak256(abi.encodePacked("SAFE_ACCOUNT_FACTORY_26-11-2024"));

		// Deploy the contract using Create2
		address accountFactoryAddress = create2Deployer.deploy(salt, contractBytecode);

		if (accountFactoryAddress == address(0)) {
			console.log("AccountFactory deployment failed");
			vm.stopBroadcast();
			return AccountFactory(address(0));
		}

		AccountFactory accountFactory = AccountFactory(accountFactoryAddress);

		vm.stopBroadcast();

		console.log("AccountFactory created at: ", address(accountFactory));

		return accountFactory;
	}

	function isAnvil() private view returns (bool) {
		return block.chainid == 31_337;
	}
}
