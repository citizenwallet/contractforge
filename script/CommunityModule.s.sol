// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import { Script, console } from "forge-std/Script.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { Upgrades } from "openzeppelin-foundry-upgrades/Upgrades.sol";

import { INonceManager } from "account-abstraction/interfaces/INonceManager.sol";

import { CommunityModule } from "../src/Modules/Community/CommunityModule.sol";
import { Paymaster } from "../src/Modules/Community/Paymaster.sol";

import { Create2 } from "../src/Create2/Create2.sol";

contract CommunityModuleScript is Script {
	function deploy(address[] calldata addresses) public returns (CommunityModule, Paymaster) {
		uint256 deployerPrivateKey = isAnvil()
            ? 77_814_517_325_470_205_911_140_941_194_401_928_579_557_062_014_761_831_930_645_393_041_380_819_009_408
            : vm.envUint("PRIVATE_KEY");
		address deployer = vm.addr(deployerPrivateKey);

		vm.startBroadcast(deployerPrivateKey);

		address entryPoint = vm.envAddress("ERC4337_ENTRYPOINT");

		if (isAnvil()) {
            vm.deal(vm.addr(deployerPrivateKey), 100 ether);

			// vm.etch(entryPoint, MAINNET_ENTRYPOINT_DEPLOYED_CODE);
        }

		Create2 create2Deployer = Create2(vm.envAddress("CREATE2_FACTORY_ADDRESS"));

		// Deploy the implementation contract
		CommunityModule communityImplementation = new CommunityModule(INonceManager(entryPoint));

		// Prepare initialization data
		bytes memory initData = abi.encodeCall(CommunityModule.initialize, (deployer));

		// Prepare the creation code for the proxy
		bytes memory proxyBytecode = abi.encodePacked(
			type(ERC1967Proxy).creationCode,
			abi.encode(address(communityImplementation), initData)
		);

		bytes32 salt = keccak256(abi.encodePacked("SAFE_COMMUNITY_MODULE_1"));

		// Deploy the proxy using Create2
		address communityProxy = create2Deployer.deploy(salt, proxyBytecode);

		if (communityProxy == address(0)) {
			console.log("CommunityModule proxy deployment failed");
			vm.stopBroadcast();
			return (CommunityModule(address(0)), Paymaster(address(0)));
		}

		console.log("CommunityModule implementation created at: ", address(communityImplementation));
		console.log("CommunityModule proxy created at: ", communityProxy);

		address paymasterImplementation = address(new Paymaster());

		bytes memory data = abi.encodeCall(Paymaster.initialize, (deployer, addresses));
		address paymasterProxy = address(new ERC1967Proxy(paymasterImplementation, data));

		vm.stopBroadcast();

		console.log("communityProxy: %s", communityProxy);
		console.log("paymasterProxy: %s", paymasterProxy);

		return (CommunityModule(communityProxy), Paymaster(paymasterProxy));
	}

	function isAnvil() private view returns (bool) {
        return block.chainid == 31_337;
    }
}
