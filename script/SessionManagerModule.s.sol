// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import { Script, console } from "forge-std/Script.sol";

import { TwoFAFactory } from "../src/Modules/Session/TwoFAFactory.sol";
import { SessionManagerModule } from "../src/Modules/Session/SessionManagerModule.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract SessionManagerModuleScript is Script {
	function deploy(address communityModule) public returns (SessionManagerModule, TwoFAFactory) {
		uint256 deployerPrivateKey = isAnvil()
			? 77_814_517_325_470_205_911_140_941_194_401_928_579_557_062_014_761_831_930_645_393_041_380_819_009_408
			: vm.envUint("PRIVATE_KEY");
		address deployer = vm.addr(deployerPrivateKey);

		vm.startBroadcast(deployerPrivateKey);

		if (isAnvil()) {
			vm.deal(vm.addr(deployerPrivateKey), 100 ether);
		}

		// Chicken and egg deployment

		// Calculate the future address of TwoFAFactory before deployment
		uint256 deployerNonce = vm.getNonce(deployer);
		// Add 2 to the nonce: +1 for sessionManagerModuleImpl, +1 for sessionManagerProxy
		address predictedTwoFAFactoryAddress = computeDeployedAddress(deployer, deployerNonce + 2);
		console.log("Predicted TwoFAFactory address: ", predictedTwoFAFactoryAddress);
		
		// Deploy the implementation contract
		SessionManagerModule sessionManagerModuleImpl = new SessionManagerModule();
		
		// Deploy the proxy pointing to the implementation
		ERC1967Proxy sessionManagerProxy = new ERC1967Proxy(
			address(sessionManagerModuleImpl),
			abi.encodeCall(SessionManagerModule.initialize, (deployer, predictedTwoFAFactoryAddress)) // Use predicted address
		);
		
		// Cast the proxy to the SessionManagerModule interface
		SessionManagerModule sessionManagerModule = SessionManagerModule(address(sessionManagerProxy));
		
		// Deploy the TwoFAFactory with the proxy address
		TwoFAFactory twoFAFactory = new TwoFAFactory(communityModule, address(sessionManagerModule));

		vm.stopBroadcast();

		console.log("SessionManagerModule created at: ", address(sessionManagerModule));
		console.log("TwoFAFactory created at: ", address(twoFAFactory));

		return (sessionManagerModule, twoFAFactory);
	}

	function isAnvil() private view returns (bool) {
		return block.chainid == 31_337;
	}
	
	// Helper function to compute the address for a regular CREATE deployment
	function computeDeployedAddress(address deployer, uint256 nonce) public pure returns (address) {
		return address(uint160(uint256(keccak256(abi.encodePacked(
			bytes1(0xd6), bytes1(0x94), deployer, bytes1(uint8(nonce))
		)))));
	}
}
