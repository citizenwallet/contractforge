// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import { INonceManager } from "account-abstraction/interfaces/INonceManager.sol";
import { UserOperation } from "account-abstraction/interfaces/UserOperation.sol";
import { Safe, ModuleManager, Enum } from "safe-smart-account/contracts/Safe.sol";

import { Utils } from "./utils/Utils.sol";

import { SafeSuiteSetupScript } from "../script/SafeSuiteSetup.s.sol";
import { AAModuleScript } from "../script/4337Module.s.sol";
import { DeploymentScript } from "../script/Deployment.s.sol";
import { CommunityModuleScript } from "../script/CommunityModule.s.sol";
import { UpgradeableCommunityTokenScript } from "../script/UpgradeableCommunityToken.s.sol";

import { CommunityModule } from "../src/Modules/Community/CommunityModule.sol";
import { Paymaster } from "../src/Modules/Community/Paymaster.sol";
import { UpgradeableCommunityToken } from "../src/ERC20/UpgradeableCommunityToken.sol";

import { toEthSignedMessageHash } from "../src/utils/Helpers.sol";

contract CommunityModuleTest is Test {
	uint256 public ownerPrivateKey;
	address public owner;

	UpgradeableCommunityTokenScript upgradeableCommunityTokenScript;

	CommunityModule public communityModule;
	Paymaster public paymaster;
	UpgradeableCommunityToken public token;
	address public safeSingleton;
	address public aaModule;
	address[] public safes;

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

		safes = deploymentScript.createSafesWithModule(3, 300, address(communityModule));

		// Deploy the Safe 4337 Module
		AAModuleScript aaModuleScript = new AAModuleScript();
		aaModule = aaModuleScript.deploy();

		deploymentScript.enableModule(safes, aaModule);

		upgradeableCommunityTokenScript.mint(safes[0], 100000000);
	}

	function testModuleIsEnabled() public {
		for (uint256 i = 0; i < safes.length; i++) {
			bool isEnabled = ModuleManager(payable(safes[i])).isModuleEnabled(address(communityModule));
			assertTrue(isEnabled, "CommunityModule should be enabled for the Safe");
		}
	}

	function testInitialNonce() public {
		for (uint256 i = 0; i < safes.length; i++) {
			uint256 nonce = communityModule.getNonce(safes[i], 0);
			assertEq(nonce, 0, "Nonce should be 0");
		}
	}

	function testPaymasterAddress() public {
		address paymasterAddress = communityModule.paymaster();
		assertEq(paymasterAddress, address(paymaster), "Paymaster address should be that of deployed paymaster");
	}

	function testTokenBalance() public {
		assertEq(token.balanceOf(safes[0]), 100000000, "Balance should be 100000000");
		assertEq(token.balanceOf(safes[1]), 0, "Balance should be 0");
		assertEq(token.balanceOf(safes[2]), 0, "Balance should be 0");
	}

	function testDirectTransfer() public {
		assertEq(token.balanceOf(owner), 0, "Balance should be 0");
		assertEq(token.balanceOf(safes[2]), 0, "Balance should be 0");

		upgradeableCommunityTokenScript.mint(owner, 100000000);

		vm.startBroadcast(ownerPrivateKey);

		token.transfer(safes[2], 100000000);
		assertEq(token.balanceOf(safes[2]), 100000000, "Balance should be 100000000");
		assertEq(token.balanceOf(owner), 0, "Balance should be 0");

		vm.stopBroadcast();
	}

	function testTransfer() public {
		bytes memory transferData = abi.encodeWithSignature("transfer(address,uint256)", safes[1], 100000000);
		bytes memory callData = abi.encodeWithSelector(
			ModuleManager.execTransactionFromModule.selector,
			address(token),
			0,
			transferData,
			Enum.Operation.Call
		);

		UserOperation memory userOperation = UserOperation({
			sender: safes[0],
			nonce: getNonce(safes[0], 0),
			initCode: bytes(""),
			callData: callData,
			callGasLimit: 100000,
			verificationGasLimit: 100000,
			preVerificationGas: 100000,
			maxFeePerGas: 100000000000000000,
			maxPriorityFeePerGas: 100000000000000000,
			paymasterAndData: bytes(""),
			signature: bytes("")
		});

		uint48 validUntil = uint48(block.timestamp + 1 hours);
		uint48 validAfter = uint48(block.timestamp);

		bytes32 paymasterHash = toEthSignedMessageHash(paymaster.getHash(userOperation, validUntil, validAfter));

		// sign the paymaster hash
		(uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, paymasterHash);
		bytes memory signature = abi.encodePacked(r, s, v);
		userOperation.paymasterAndData = constructPaymasterAndData(validUntil, validAfter, signature);

		// sign the user operation
		bytes32 userOperationHash = toEthSignedMessageHash(communityModule.getUserOpHash(userOperation));
		// userOperation.signature = generateSafeSignature(userOperationHash);
		(v, r, s) = vm.sign(ownerPrivateKey, userOperationHash);
		signature = abi.encodePacked(r, s, v);
		userOperation.signature = signature;

		UserOperation[] memory userOperations = new UserOperation[](1);
		userOperations[0] = userOperation;

		vm.startBroadcast(ownerPrivateKey);

		communityModule.handleOps(userOperations, payable(owner));

		vm.stopBroadcast();

		assertEq(token.balanceOf(safes[0]), 0, "Balance should be 0");
		assertEq(token.balanceOf(safes[1]), 100000000, "Balance should be 100000000");
	}

	function constructPaymasterAndData(
		uint48 validUntil,
		uint48 validAfter,
		bytes memory signature
	) public view returns (bytes memory) {
		return abi.encodePacked(address(paymaster), abi.encode(validUntil, validAfter), signature);
	}

	function getSafe4337TxCalldata(
		address sender,
		address target,
		uint256 value,
		bytes memory data,
		uint8 operation // {0: Call, 1: DelegateCall}
	) internal returns (bytes memory) {
		// Get nonce from Entrypoint
		// uint256 nonce = entrypoint.getNonce(sender, 0);

		return
			abi.encodeWithSignature(
				"checkAndExecTransactionFromModule(address,address,uint256,bytes,uint8,uint256)",
				sender,
				target,
				value,
				data,
				operation,
				0
			);
	}

	// Add this function to generate a Safe-compatible signature
	function generateSafeSignature(bytes32 hash) internal view returns (bytes memory) {
		// Assuming a single owner for simplicity. Adjust if there are multiple owners.
		(uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, hash);

		bytes memory signature = abi.encodePacked(r, s, v);

		// Safe signature format: {bytes32 r}{bytes32 s}{uint8 v}{uint256 guardianSignatureType}
		// guardianSignatureType: 0 = EOA, 1 = EIP1271
		return
			abi.encodePacked(
				bytes32(uint256(1)), // Threshold
				signature,
				uint256(0) // EOA signature type
			);
	}

	function getNonce(address sender, uint192 key) internal view returns (uint256) {
		address entryPoint = vm.envAddress("ERC4337_ENTRYPOINT");

		return INonceManager(payable(entryPoint)).getNonce(sender, key);
	}

	function isAnvil() private view returns (bool) {
		return block.chainid == 31_337;
	}
}
