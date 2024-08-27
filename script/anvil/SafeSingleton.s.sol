// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Script, console } from "forge-std/Script.sol";
import { Safe } from "safe-smart-account/contracts/Safe.sol";

contract SafeSingletonScript is Script {
	address public constant SAFE_SINGLETON_ADDRESS = 0x41675C099F32341bf84BFc5382aF534df5C7461a;

	function deploy() public {
		uint256 deployerPrivateKey = isAnvil()
			? 77_814_517_325_470_205_911_140_941_194_401_928_579_557_062_014_761_831_930_645_393_041_380_819_009_408
			: vm.envUint("PRIVATE_KEY");
		address deployer = vm.addr(deployerPrivateKey);

		if (isAnvil()) {
			vm.deal(vm.addr(deployerPrivateKey), 100 ether);
		}

		vm.startBroadcast(deployerPrivateKey);

		Safe safe = new Safe();

		console.log("safe: %s", address(safe));

		bytes memory bytecode = address(safe).code;

		// Deploy a new contract at the SAFE_SINGLETON_ADDRESS
		assembly {
			let success := create(0, add(bytecode, 0x20), mload(bytecode))
			if iszero(success) {
				revert(0, 0)
			}
		}

		vm.stopBroadcast();

		bytes memory deployedCode = address(SAFE_SINGLETON_ADDRESS).code;

		console.log("deploying to", SAFE_SINGLETON_ADDRESS);
		console.log("Deployed code length:", deployedCode.length);

		require(deployedCode.length > 0, "No code deployed");
		require(keccak256(deployedCode) == keccak256(address(safe).code), "Incorrect code deployed");

		console.log("Safe Singleton deployed successfully");
	}

	function isAnvil() private view returns (bool) {
		return block.chainid == 31_337;
	}
}
