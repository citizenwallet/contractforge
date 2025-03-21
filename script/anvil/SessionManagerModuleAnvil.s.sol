// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

// @custom:artifact-size-ignore

import { Script, console } from "forge-std/Script.sol";

import { UpgradeableCommunityTokenScript } from "../UpgradeableCommunityToken.s.sol";
import { CommunityAndPaymasterModuleScript } from "../CommunityAndPaymaster.s.sol";
import { AccountFactoryScript } from "../AccountFactory.s.sol";

import { SafeSuiteSetupScript } from "../SafeSuiteSetup.s.sol";

import { AccountFactory } from "../../src/Modules/Community/AccountFactory.sol";
import { CardFactory } from "../../src/Modules/CardManager/CardFactory.sol";
import { CardManagerModule } from "../../src/Modules/CardManager/CardManagerModule.sol";
import { TwoFAFactory } from "../../src/Modules/Session/TwoFAFactory.sol";
import { SessionManagerModule } from "../../src/Modules/Session/SessionManagerModule.sol";
import { CommunityModule } from "../../src/Modules/Community/CommunityModule.sol";
import { Paymaster } from "../../src/Modules/Community/Paymaster.sol";
import { UpgradeableCommunityToken } from "../../src/ERC20/UpgradeableCommunityToken.sol";

import { SessionManagerModuleScript } from "../SessionManagerModule.s.sol";

contract SessionManagerModuleAnvilScript is Script {
	address public constant SAFE_SINGLETON_ADDRESS = 0x914d7Fec6aaC8cd542e72Bca78B30650d45643d7;

	function deploy() public {
		uint256 deployerPrivateKey = isAnvil()
			? 77_814_517_325_470_205_911_140_941_194_401_928_579_557_062_014_761_831_930_645_393_041_380_819_009_408
			: vm.envUint("PRIVATE_KEY");
		address deployer = vm.addr(deployerPrivateKey);

		if (isAnvil()) {
			vm.deal(vm.addr(deployerPrivateKey), 100 ether);
		}

		// Deploy the safe singleton
		SafeSuiteSetupScript setupScript = new SafeSuiteSetupScript();
		setupScript.run();

		console.log("SAFE_SINGLETON_ADDRESS: %s", SAFE_SINGLETON_ADDRESS);
		console.log("isContract(SAFE_SINGLETON_ADDRESS): %s", isContract(SAFE_SINGLETON_ADDRESS));

		console.log("SAFE_SINGLETON_ADDRESS: %s", SAFE_SINGLETON_ADDRESS);
		console.log("isContract(SAFE_SINGLETON_ADDRESS): %s", isContract(SAFE_SINGLETON_ADDRESS));

		UpgradeableCommunityTokenScript upgradeableCommunityTokenScript = new UpgradeableCommunityTokenScript();
		UpgradeableCommunityToken token = upgradeableCommunityTokenScript.testDeploy();

		address[] memory whitelist = new address[](1);
		whitelist[0] = address(token);

		CommunityAndPaymasterModuleScript communityModuleScript = new CommunityAndPaymasterModuleScript();

		(CommunityModule communityModule, Paymaster paymaster) = communityModuleScript.deploy(whitelist);

		AccountFactoryScript accountFactoryScript = new AccountFactoryScript();
		AccountFactory accountFactory = accountFactoryScript.deploy(address(communityModule));

		console.log("--------------------------------");
		console.log("deployer: %s", deployer);
		console.log("deployerPrivateKey: 0x%x", deployerPrivateKey);
		console.log("token: %s", address(token));
		console.log("communityModule: %s", address(communityModule));
		console.log("paymaster: %s", address(paymaster));
		console.log("accountFactory: %s", address(accountFactory));

		// vm.startBroadcast(deployerPrivateKey);

		// Chicken and egg deployment
		// CardManagerModule cardManagerModule = new CardManagerModule();

		// // the card factory needs the card manager module address to deploy
		// CardFactory cardFactory = new CardFactory(address(communityModule), address(cardManagerModule));

		// // the card manager module needs the card factory address in order to function
		// cardManagerModule.initialize(deployer, address(cardFactory));

		// console.log("cardManagerModule: %s", address(cardManagerModule));
		// console.log("cardFactory: %s", address(cardFactory));

		// bytes32 id = keccak256("test");

		// address[] memory tokens = new address[](1);
		// tokens[0] = address(token);

		// cardManagerModule.createInstance(id, tokens);

		// console.log("instance id:");
		// console.logBytes32(id);

		// vm.stopBroadcast();

		SessionManagerModuleScript sessionManagerModuleScript = new SessionManagerModuleScript();
		(SessionManagerModule sessionManagerModule, TwoFAFactory twoFAFactory) = sessionManagerModuleScript.deploy(
			address(communityModule)
		);

		console.log("sessionManagerModule: %s", address(sessionManagerModule));
		console.log("twoFAFactory: %s", address(twoFAFactory));

		console.log("SAFE_SINGLETON_ADDRESS: %s", SAFE_SINGLETON_ADDRESS);
		console.log("isContract(SAFE_SINGLETON_ADDRESS): %s", isContract(SAFE_SINGLETON_ADDRESS));

		vm.startBroadcast(deployerPrivateKey);

		console.log("SAFE_SINGLETON_ADDRESS: %s", SAFE_SINGLETON_ADDRESS);
		console.log("isContract(SAFE_SINGLETON_ADDRESS): %s", isContract(SAFE_SINGLETON_ADDRESS));

		accountFactory.createAccount(deployer, 0);
		address sessionProvider = accountFactory.getAddress(deployer, 0);

		console.log("--------------------------------");
		console.log("sessionProvider: %s", sessionProvider);

		vm.stopBroadcast();
	}

	function isAnvil() private view returns (bool) {
		return block.chainid == 31_337;
	}

	/**
	 * @dev Check if an address is a contract
	 */
	function isContract(address account) internal view returns (bool) {
		uint256 size;
		assembly {
			size := extcodesize(account)
		}
		return size > 0;
	}
}
