// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import { INonceManager } from "account-abstraction/interfaces/INonceManager.sol";
import { UserOperation } from "account-abstraction/interfaces/UserOperation.sol";
import { Safe, ModuleManager, Enum } from "safe-smart-account/contracts/Safe.sol";

import { SafeSuiteSetupScript } from "../script/SafeSuiteSetup.s.sol";
import { AAModuleScript } from "../script/4337Module.s.sol";
import { DeploymentScript } from "../script/Deployment.s.sol";
import { CommunityModuleScript } from "../script/CommunityModule.s.sol";
import { UpgradeableCommunityTokenScript } from "../script/UpgradeableCommunityToken.s.sol";

import { CommunityModule } from "../src/Modules/Community/CommunityModule.sol";
import { Paymaster } from "../src/Modules/Community/Paymaster.sol";
import { UpgradeableCommunityToken } from "../src/ERC20/UpgradeableCommunityToken.sol";

contract CommunityModuleTest is Test {
	uint256 public ownerPrivateKey;
	address public owner;

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
		UpgradeableCommunityTokenScript upgradeableCommunityTokenScript = new UpgradeableCommunityTokenScript();
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

	function testTransfer() public {
		bytes memory transferData = abi.encodeWithSignature("transfer(address,uint256)", safes[1], 100000000);
		console.log("address(token)", address(token));
		// bytes memory executeData = abi.encodeWithSignature(
		// 	"execute(address,uint256,bytes)",
		// 	address(token),
		// 	0,
		// 	transferData
		// );
		bytes memory callData = abi.encodeWithSelector(
			ModuleManager.execTransactionFromModule.selector,
			address(token),
			0,
			transferData,
			Enum.Operation.DelegateCall
		);

		UserOperation memory userOperation = UserOperation({
			sender: safes[0],
			nonce: 0,
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
		console.log("validUntil", validUntil);
		console.log("validAfter", validAfter);
		bytes32 paymasterHash = paymaster.getHash(userOperation, validUntil, validAfter);
		console.logBytes32(paymasterHash);

		// sign the paymaster hash
		(uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerPrivateKey, paymasterHash);
		bytes memory signature = abi.encodePacked(r, s, v);
		userOperation.paymasterAndData = constructPaymasterAndData(validUntil, validAfter, signature);

		// sign the user operation
		bytes32 userOperationHash = communityModule.getUserOpHash(userOperation);
		(v, r, s) = vm.sign(ownerPrivateKey, userOperationHash);
		userOperation.signature = abi.encodePacked(r, s, v);

		UserOperation[] memory userOperations = new UserOperation[](1);
		userOperations[0] = userOperation;

		communityModule.handleOps(userOperations, payable(owner));

		console.log("token balance of safes[0]", token.balanceOf(safes[0]));
		console.log("token balance of safes[1]", token.balanceOf(safes[1]));

		console.log("address(token)", address(token));

		// assertEq(token.balanceOf(safes[0]), 0, "Balance should be 0");
		// assertEq(token.balanceOf(safes[1]), 100000000, "Balance should be 100000000");
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

	function isAnvil() private view returns (bool) {
		return block.chainid == 31_337;
	}
}
