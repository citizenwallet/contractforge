// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import { Script, console } from "forge-std/Script.sol";

import { UpgradeableCommunityTokenScript } from "../UpgradeableCommunityToken.s.sol";
import { CommunityModuleScript } from "../CommunityModule.s.sol";
import { AccountFactoryScript } from "../AccountFactory.s.sol";

import { AccountFactory } from "../../src/Modules/Community/AccountFactory.sol";
import { CardFactory } from "../../src/Modules/CardManager/CardFactory.sol";
import { CardManagerModule } from "../../src/Modules/CardManager/CardManagerModule.sol";
import { CommunityModule } from "../../src/Modules/Community/CommunityModule.sol";
import { Paymaster } from "../../src/Modules/Community/Paymaster.sol";
import { UpgradeableCommunityToken } from "../../src/ERC20/UpgradeableCommunityToken.sol";

contract CommunityWithTokenScript is Script {
	function deploy() public {
		uint256 deployerPrivateKey = isAnvil()
			? 77_814_517_325_470_205_911_140_941_194_401_928_579_557_062_014_761_831_930_645_393_041_380_819_009_408
			: vm.envUint("PRIVATE_KEY");
		address deployer = vm.addr(deployerPrivateKey);

		if (isAnvil()) {
			vm.deal(vm.addr(deployerPrivateKey), 100 ether);
		}

        UpgradeableCommunityTokenScript upgradeableCommunityTokenScript = new UpgradeableCommunityTokenScript();
        UpgradeableCommunityToken token = upgradeableCommunityTokenScript.testDeploy();

        address[] memory whitelist = new address[](1);
        whitelist[0] = address(token);

        CommunityModuleScript communityModuleScript = new CommunityModuleScript();

        (CommunityModule communityModule, Paymaster paymaster) = communityModuleScript.deploy(whitelist);

		AccountFactoryScript accountFactoryScript = new AccountFactoryScript();
		AccountFactory accountFactory = accountFactoryScript.deploy(address(communityModule));

		console.log("token: %s", address(token));
		console.log("communityModule: %s", address(communityModule));
		console.log("paymaster: %s", address(paymaster));
		console.log("accountFactory: %s", address(accountFactory));
	}

	function isAnvil() private view returns (bool) {
		return block.chainid == 31_337;
	}
}
