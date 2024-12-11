// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import { Script, console } from "forge-std/Script.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { Upgrades } from "openzeppelin-foundry-upgrades/Upgrades.sol";

import { INonceManager } from "account-abstraction/interfaces/INonceManager.sol";

import { UpgradeableCommunityToken } from "../src/ERC20/UpgradeableCommunityToken.sol";
import { Paymaster } from "../src/Modules/Community/Paymaster.sol";

contract UpgradeableCommunityTokenScript is Script {
	UpgradeableCommunityToken public token;

	function deploy(address[] calldata minters, string calldata name, string calldata symbol) public returns (UpgradeableCommunityToken) {
		uint256 deployerPrivateKey = isAnvil()
            ? 77_814_517_325_470_205_911_140_941_194_401_928_579_557_062_014_761_831_930_645_393_041_380_819_009_408
            : vm.envUint("PRIVATE_KEY");
		address deployer = vm.addr(deployerPrivateKey);

		vm.startBroadcast(deployerPrivateKey);

		if (isAnvil()) {
            vm.deal(vm.addr(deployerPrivateKey), 100 ether);
        }

		address implementation = address(new UpgradeableCommunityToken());

		bytes memory data = abi.encodeCall(UpgradeableCommunityToken.initialize, (deployer, minters, name, symbol));
		address proxy = address(new ERC1967Proxy(implementation, data));

		vm.stopBroadcast();

		token = UpgradeableCommunityToken(proxy);

		return token;
	}

	function testDeploy() public returns (UpgradeableCommunityToken) {
		uint256 deployerPrivateKey = isAnvil()
            ? 77_814_517_325_470_205_911_140_941_194_401_928_579_557_062_014_761_831_930_645_393_041_380_819_009_408
            : vm.envUint("PRIVATE_KEY");
		address deployer = vm.addr(deployerPrivateKey);

		vm.startBroadcast(deployerPrivateKey);

		if (isAnvil()) {
            vm.deal(vm.addr(deployerPrivateKey), 100 ether);
        }

		address implementation = address(new UpgradeableCommunityToken());

		address[] memory minters = new address[](1);
		minters[0] = deployer;

		bytes memory data = abi.encodeCall(UpgradeableCommunityToken.initialize, (deployer, minters, "Community Token", "CT"));
		address proxy = address(new ERC1967Proxy(implementation, data));

		vm.stopBroadcast();

		token = UpgradeableCommunityToken(proxy);

		return token;
	}

	function addMinter(address minter) public {
		uint256 deployerPrivateKey = isAnvil()
            ? 77_814_517_325_470_205_911_140_941_194_401_928_579_557_062_014_761_831_930_645_393_041_380_819_009_408
            : vm.envUint("PRIVATE_KEY");

		vm.startBroadcast(deployerPrivateKey);

		if (isAnvil()) {
            vm.deal(vm.addr(deployerPrivateKey), 100 ether);
        }

		token.grantRole(token.MINTER_ROLE(), minter);

		vm.stopBroadcast();
	}

	function mint(address to, uint256 amount) public {
		uint256 deployerPrivateKey = isAnvil()
            ? 77_814_517_325_470_205_911_140_941_194_401_928_579_557_062_014_761_831_930_645_393_041_380_819_009_408
            : vm.envUint("PRIVATE_KEY");

		vm.startBroadcast(deployerPrivateKey);

		if (isAnvil()) {
            vm.deal(vm.addr(deployerPrivateKey), 100 ether);
        }

		token.mint(to, amount);

		vm.stopBroadcast();
	}

	function isAnvil() private view returns (bool) {
        return block.chainid == 31_337;
    }
}
