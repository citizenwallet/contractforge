// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import { Utils } from "./utils/Utils.sol";

import { INonceManager } from "account-abstraction/interfaces/INonceManager.sol";
import { UserOperation } from "account-abstraction/interfaces/UserOperation.sol";
import { Safe, ModuleManager, Enum } from "safe-smart-account/contracts/Safe.sol";
import { SafeProxyFactory } from "safe-smart-account/contracts/proxies/SafeProxyFactory.sol";

import { Utils } from "./utils/Utils.sol";

import { SafeSuiteSetupScript } from "../script/SafeSuiteSetup.s.sol";
import { CardFactoryScript } from "../script/CardFactory.s.sol";
import { AccountFactoryScript } from "../script/AccountFactory.s.sol";
import { CardManagerModuleScript } from "../script/CardManagerModule.s.sol";
import { DeploymentScript } from "../script/Deployment.s.sol";
import { CommunityModuleScript } from "../script/CommunityModule.s.sol";
import { UpgradeableCommunityTokenScript } from "../script/UpgradeableCommunityToken.s.sol";

import { CommunityModule } from "../src/Modules/Community/CommunityModule.sol";
import { Paymaster } from "../src/Modules/Community/Paymaster.sol";
import { CardFactory } from "../src/Modules/CardManager/CardFactory.sol";
import { AccountFactory } from "../src/Modules/Community/AccountFactory.sol";
import { CardManagerModule } from "../src/Modules/CardManager/CardManagerModule.sol";
import { UpgradeableCommunityToken } from "../src/ERC20/UpgradeableCommunityToken.sol";

import { toEthSignedMessageHash } from "../src/utils/Helpers.sol";

contract CardManagerModuleTest is Test {
	uint256 public ownerPrivateKey;
	address public owner;

	UpgradeableCommunityTokenScript upgradeableCommunityTokenScript;

	Utils public utils = new Utils();

	CommunityModule public communityModule;
	Paymaster public paymaster;
	CardManagerModule public cardManagerModule;
	AccountFactory public accountFactory;
	CardFactory public cardFactory;
	UpgradeableCommunityToken public token;
	address public safeSingleton;
	address[] public vendors;
	address[] public tags;
	address[] public modules;

	uint256 private constant VALID_TIMESTAMP_OFFSET = 20;

	uint256 private constant SIGNATURE_OFFSET = 84;

	function setUp() public {
		ownerPrivateKey = isAnvil()
			? 77_814_517_325_470_205_911_140_941_194_401_928_579_557_062_014_761_831_930_645_393_041_380_819_009_408
			: vm.envUint("PRIVATE_KEY");
		owner = vm.addr(ownerPrivateKey);

		vm.deal(owner, 100 ether);

		// Deploy the safe singleton
		SafeSuiteSetupScript setupScript = new SafeSuiteSetupScript();
		setupScript.run();

		safeSingleton = setupScript.SAFE_SINGLETON_ADDRESS();

		DeploymentScript deploymentScript = new DeploymentScript();
		deploymentScript.fundDeployer();

		// Deploy the community module
		upgradeableCommunityTokenScript = new UpgradeableCommunityTokenScript();
		token = upgradeableCommunityTokenScript.deploy();

		address[] memory whitelistedAddresses = new address[](1);
		whitelistedAddresses[0] = address(token);

		CommunityModuleScript communityModuleScript = new CommunityModuleScript();
		(communityModule, paymaster) = communityModuleScript.deploy(whitelistedAddresses);

		// Deploy the account factory
		AccountFactoryScript accountFactoryScript = new AccountFactoryScript();
		accountFactory = accountFactoryScript.deploy(address(communityModule));

		// Deploy the card manager module
		CardManagerModuleScript cardManagerModuleScript = new CardManagerModuleScript();
		(cardManagerModule, cardFactory) = cardManagerModuleScript.deploy(address(communityModule)); // chicken and egg problem

		modules = new address[](2);
		modules[0] = address(communityModule);
		modules[1] = address(cardManagerModule);

		vm.startBroadcast(ownerPrivateKey);

		uint256 numVendors = 3;
		vendors = new address[](numVendors);
		for (uint256 i = 0; i < numVendors; i++) {
			// create the vendors
			vendors[i] = accountFactory.createAccount(owner, i);
		}

		uint256 numSafe = 3;
		tags = new address[](numSafe);
		for (uint256 i = 0; i < numSafe; i++) {
			// create the tags
			tags[i] = cardFactory.createAccount(owner, i);
		}

		vm.stopBroadcast();

		upgradeableCommunityTokenScript.mint(tags[0], 100000000);
	}

	function testCommunityModuleIsEnabled() public view {
		for (uint256 i = 0; i < vendors.length; i++) {
			bool isEnabled = ModuleManager(payable(vendors[i])).isModuleEnabled(address(communityModule));
			assertTrue(isEnabled, "CommunityModule should be enabled for the Safe");
		}
	}

	function testModulesAreEnabled() public view {
		for (uint256 i = 0; i < modules.length; i++) {
			for (uint256 j = 0; j < tags.length; j++) {
				bool isEnabled = ModuleManager(payable(tags[j])).isModuleEnabled(modules[i]);
				assertTrue(isEnabled, "Module should be enabled for the Safe");
			}
		}
	}

	function testInitialNonce() public view {
		for (uint256 i = 0; i < tags.length; i++) {
			uint256 nonce = communityModule.getNonce(tags[i], 0);
			assertEq(nonce, 0, "Nonce should be 0");
		}
	}

	function testAccountFactory() public {
		address userA = utils.getNextUserAddress();

		address counterFactualSafeA = cardFactory.getAddress(userA, 0);

		address safeA = cardFactory.createAccount(userA, 0);
		assertEq(safeA, counterFactualSafeA, "Account factory address should be that of deployed account factory");
	}

	function testTokenBalance() public view {
		assertEq(token.balanceOf(tags[0]), 100000000, "Balance should be 100000000");
		assertEq(token.balanceOf(tags[1]), 0, "Balance should be 0");
		assertEq(token.balanceOf(tags[2]), 0, "Balance should be 0");
	}

	function testDirectTransfer() public {
		assertEq(token.balanceOf(owner), 0, "Balance should be 0");
		assertEq(token.balanceOf(tags[2]), 0, "Balance should be 0");

		upgradeableCommunityTokenScript.mint(owner, 100000000);

		vm.startBroadcast(ownerPrivateKey);

		token.transfer(tags[2], 100000000);
		assertEq(token.balanceOf(tags[2]), 100000000, "Balance should be 100000000");
		assertEq(token.balanceOf(owner), 0, "Balance should be 0");

		vm.stopBroadcast();
	}

	function testTransfer() public {
		bytes memory initCode = bytes("");

		bytes memory transferData = abi.encodeWithSignature("transfer(address,uint256)", tags[1], 100000000);

		UserOperation memory userOp = createUserOperation(tags[0], initCode, transferData);
		signAndExecuteUserOp(userOp, ownerPrivateKey);

		assertEq(token.balanceOf(tags[0]), 0, "Balance should be 0");
		assertEq(token.balanceOf(tags[1]), 100000000, "Balance should be 100000000");
	}

	function testNewSafeTransfer() public {
		(address newSafe, uint256 newOwnerPrivateKey) = setupNewSafe();

		bytes memory initCode = generateInitCode(address(cardFactory), vm.addr(newOwnerPrivateKey), 0);

		bytes memory transferData = abi.encodeWithSignature("transfer(address,uint256)", tags[2], 100000000);

		UserOperation memory userOp = createUserOperation(newSafe, initCode, transferData);
		signAndExecuteUserOp(userOp, newOwnerPrivateKey);
		

		assertEq(token.balanceOf(newSafe), 0, "Balance should be 0");
		assertEq(token.balanceOf(tags[2]), 100000000, "Balance should be 100000000");
	}

	function setupNewSafe() private returns (address, uint256) {
		uint256 newOwnerPrivateKey = uint256(keccak256(abi.encodePacked("deterministic_salt", block.number)));
		address newOwner = vm.addr(newOwnerPrivateKey);
		address newSafe = cardFactory.getAddress(newOwner, 0);
		upgradeableCommunityTokenScript.mint(newSafe, 100000000);
		return (newSafe, newOwnerPrivateKey);
	}

	function createUserOperation(address _safe, bytes memory initCode, bytes memory transferData) private view returns (UserOperation memory) {
		bytes memory callData = abi.encodeWithSelector(
			ModuleManager.execTransactionFromModule.selector,
			address(token),
			0,
			transferData,
			Enum.Operation.Call
		);

		return UserOperation({
			sender: _safe,
			nonce: getNonce(_safe, 0),
			initCode: initCode,
			callData: callData,
			callGasLimit: 100000,
			verificationGasLimit: 100000,
			preVerificationGas: 100000,
			maxFeePerGas: 100000000000000000,
			maxPriorityFeePerGas: 100000000000000000,
			paymasterAndData: bytes(""),
			signature: bytes("")
		});
	}

	function signAndExecuteUserOp(UserOperation memory userOp, uint256 newOwnerPrivateKey) private {
		(userOp.paymasterAndData, userOp.signature) = signUserOp(userOp, newOwnerPrivateKey);

		UserOperation[] memory userOperations = new UserOperation[](1);
		userOperations[0] = userOp;

		vm.startBroadcast(ownerPrivateKey);
		communityModule.handleOps(userOperations, payable(owner));
		vm.stopBroadcast();
	}

	function signUserOp(UserOperation memory userOp, uint256 newOwnerPrivateKey) private view returns (bytes memory, bytes memory) {
		uint48 validUntil = uint48(block.timestamp + 1 hours);
		uint48 validAfter = uint48(block.timestamp);

		bytes32 paymasterHash = toEthSignedMessageHash(paymaster.getHash(userOp, validUntil, validAfter));
		(uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, paymasterHash);
		bytes memory paymasterAndData = constructPaymasterAndData(validUntil, validAfter, abi.encodePacked(r, s, v));

		userOp.paymasterAndData = paymasterAndData;

		bytes32 userOperationHash = toEthSignedMessageHash(communityModule.getUserOpHash(userOp));
		(v, r, s) = vm.sign(newOwnerPrivateKey, userOperationHash);
		bytes memory signature = abi.encodePacked(r, s, v);

		return (paymasterAndData, signature);
	}

	function constructPaymasterAndData(
		uint48 validUntil,
		uint48 validAfter,
		bytes memory signature
	) public view returns (bytes memory) {
		return abi.encodePacked(address(paymaster), abi.encode(validUntil, validAfter), signature);
	}

	function getNonce(address sender, uint192 key) internal view returns (uint256) {
		address entryPoint = vm.envAddress("ERC4337_ENTRYPOINT");

		return INonceManager(payable(entryPoint)).getNonce(sender, key);
	}

	function generateInitCode(address factoryAddress, address _owner, uint256 salt) public pure returns (bytes memory) {
		// Define the function selector for the createAccount function
		bytes4 functionSelector = bytes4(keccak256("createAccount(address,uint256)"));

		// Encode the calldata for the factory function
		bytes memory calldataEncoded = abi.encodeWithSelector(functionSelector, _owner, salt);

		// Concatenate the factory address and the calldata
		bytes memory initCode = abi.encodePacked(factoryAddress, calldataEncoded);

		return initCode;
	}

	function isAnvil() private view returns (bool) {
		return block.chainid == 31_337;
	}
}
