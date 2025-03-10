// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import { Utils } from "./utils/Utils.sol";

import { INonceManager } from "account-abstraction/interfaces/INonceManager.sol";
import { UserOperation } from "account-abstraction/interfaces/UserOperation.sol";
import { Safe, ModuleManager, OwnerManager, GuardManager, Enum } from "safe-smart-account/contracts/Safe.sol";
import { StorageAccessible } from "safe-smart-account/contracts/common/StorageAccessible.sol";
import { SafeProxyFactory } from "safe-smart-account/contracts/proxies/SafeProxyFactory.sol";

import { Utils } from "./utils/Utils.sol";

import { SafeSuiteSetupScript } from "../script/SafeSuiteSetup.s.sol";
import { AccountFactoryScript } from "../script/AccountFactory.s.sol";
import { SessionManagerModuleScript } from "../script/SessionManagerModule.s.sol";
import { DeploymentScript } from "../script/Deployment.s.sol";
import { CommunityAndPaymasterModuleScript } from "../script/CommunityAndPaymaster.s.sol";
import { UpgradeableCommunityTokenScript } from "../script/UpgradeableCommunityToken.s.sol";

import { CommunityModule } from "../src/Modules/Community/CommunityModule.sol";
import { Paymaster } from "../src/Modules/Community/Paymaster.sol";
import { TwoFAFactory } from "../src/Modules/Session/TwoFAFactory.sol";
import { AccountFactory } from "../src/Modules/Community/AccountFactory.sol";
import { SessionManagerModule } from "../src/Modules/Session/SessionManagerModule.sol";
import { UpgradeableCommunityToken } from "../src/ERC20/UpgradeableCommunityToken.sol";

import { toEthSignedMessageHash } from "../src/utils/Helpers.sol";

contract SessionManagerModuleTest is Test {
	uint256 public ownerPrivateKey;
	address public owner;

	uint256 public providerPrivateKey;
	address public provider;
	address public providerAccount;

	UpgradeableCommunityTokenScript upgradeableCommunityTokenScript;

	Utils public utils = new Utils();
	// keccak256("guard_manager.guard.address")
	bytes32 internal constant GUARD_STORAGE_SLOT = 0x4a204f620c8c5ccdca3fd54d003badd85ba500436a431f0cbda4f558c93c34c8;

	CommunityModule public communityModule;
	Paymaster public paymaster;
	SessionManagerModule public sessionManagerModule;
	AccountFactory public accountFactory;
	TwoFAFactory public twoFAFactory;
	UpgradeableCommunityToken public token;
	UpgradeableCommunityToken public token2;
	address public safeSingleton;

	address[] public accounts;
	bytes32 public sessionSalt1;
	address public account1;
	bytes32 public sessionSalt2;
	address public account2;

	uint256 public vendorPrivateKey;
	address public vendor;

	uint256 public badVendorPrivateKey;
	address public badVendor;

	address[] public modules;

	uint256 private constant VALID_TIMESTAMP_OFFSET = 20;

	uint256 private constant SIGNATURE_OFFSET = 84;

	// out of memory optimization for tests
	UserOperation userOp;
	UserOperation userOp1;

	function _bytes32ToUint256(bytes32 b) public pure returns (uint256) {
		return uint256(b);
	}

	function setUp() public {
		ownerPrivateKey = isAnvil()
			? 77_814_517_325_470_205_911_140_941_194_401_928_579_557_062_014_761_831_930_645_393_041_380_819_009_408
			: vm.envUint("PRIVATE_KEY");
		owner = vm.addr(ownerPrivateKey);

		providerPrivateKey = isAnvil()
			? 77_814_517_325_470_205_911_140_941_194_401_928_579_557_062_014_761_831_930_645_393_041_380_819_009_409
			: vm.envUint("PRIVATE_KEY");
		provider = vm.addr(providerPrivateKey);

		vm.deal(owner, 100 ether);
		vm.deal(provider, 100 ether);

		// Deploy the safe singleton
		SafeSuiteSetupScript setupScript = new SafeSuiteSetupScript();
		setupScript.run();

		safeSingleton = setupScript.SAFE_SINGLETON_ADDRESS();

		DeploymentScript deploymentScript = new DeploymentScript();
		deploymentScript.fundDeployer();

		// Deploy the community module
		upgradeableCommunityTokenScript = new UpgradeableCommunityTokenScript();
		token2 = upgradeableCommunityTokenScript.testDeploy();
		token = upgradeableCommunityTokenScript.testDeploy();

		address[] memory whitelistedAddresses = new address[](1);
		whitelistedAddresses[0] = address(token);

		CommunityAndPaymasterModuleScript communityAndPaymasterModuleScript = new CommunityAndPaymasterModuleScript();
		(communityModule, paymaster) = communityAndPaymasterModuleScript.deploy(whitelistedAddresses);

		// Deploy the account factory
		AccountFactoryScript accountFactoryScript = new AccountFactoryScript();
		accountFactory = accountFactoryScript.deploy(address(communityModule));

		// Deploy the session manager module
		SessionManagerModuleScript sessionManagerModuleScript = new SessionManagerModuleScript();
		(sessionManagerModule, twoFAFactory) = sessionManagerModuleScript.deploy(address(communityModule));

		modules = new address[](2);
		modules[0] = address(communityModule);
		modules[1] = address(sessionManagerModule);

		vm.startBroadcast(ownerPrivateKey);

		// make sure the session manager module is whitelisted
		whitelistedAddresses = new address[](3);
		whitelistedAddresses[0] = address(token);
		whitelistedAddresses[1] = address(token2);
		whitelistedAddresses[2] = address(sessionManagerModule);

		paymaster.updateWhitelist(whitelistedAddresses);

		providerAccount = accountFactory.createAccount(provider, 0);

		vendorPrivateKey = 0x1234567890123456789012345678901234567890123456789012345678901234;
		vendor = accountFactory.createAccount(vm.addr(vendorPrivateKey), 0);

		badVendorPrivateKey = 0x1234567890123456789012345678901234567890123456789012345678901235;
		badVendor = accountFactory.createAccount(vm.addr(badVendorPrivateKey), 0);

		sessionSalt1 = keccak256(abi.encodePacked("+32478121212:sms"));
		twoFAFactory.createAccount(providerAccount, _bytes32ToUint256(sessionSalt1));
		account1 = twoFAFactory.getAddress(providerAccount, _bytes32ToUint256(sessionSalt1));

		sessionSalt2 = keccak256(abi.encodePacked("+32478343434:sms"));
		twoFAFactory.createAccount(providerAccount, _bytes32ToUint256(sessionSalt2));
		account2 = twoFAFactory.getAddress(providerAccount, _bytes32ToUint256(sessionSalt2));

		accounts = new address[](2);
		accounts[0] = account1;
		accounts[1] = account2;

		vm.stopBroadcast();

		upgradeableCommunityTokenScript.mint(account1, 100000000);
	}

	function testTwoFAFactory() public view {
		assertEq(
			twoFAFactory.getAddress(providerAccount, _bytes32ToUint256(sessionSalt1)),
			account1,
			"Account should be created"
		);
		assertEq(
			twoFAFactory.getAddress(providerAccount, _bytes32ToUint256(sessionSalt2)),
			account2,
			"Account should be created"
		);
	}

	function testCommunityModuleIsEnabled() public view {
		bool isEnabled = ModuleManager(payable(account1)).isModuleEnabled(address(communityModule));
		assertTrue(isEnabled, "CommunityModule should be enabled for the Safe");
	}

	function testModulesAreEnabled() public view {
		for (uint256 i = 0; i < modules.length; i++) {
			for (uint256 j = 0; j < accounts.length; j++) {
				bool isEnabled = ModuleManager(payable(accounts[j])).isModuleEnabled(modules[i]);
				assertTrue(isEnabled, "Module should be enabled for the Safe");
			}
		}
	}

	function testGuardIsSet() public view {
		for (uint256 i = 0; i < accounts.length; i++) {
			// Convert bytes32 storage slot to uint256 offset
			uint256 offset = uint256(GUARD_STORAGE_SLOT);
			bytes memory storageData = StorageAccessible(accounts[i]).getStorageAt(offset, 1);
			address guard = address(uint160(uint256(bytes32(storageData))));
			assertEq(guard, address(sessionManagerModule), "Guard should be set to the session manager module");
		}
	}

	function testInitialNonce() public view {
		for (uint256 i = 0; i < accounts.length; i++) {
			uint256 nonce = communityModule.getNonce(accounts[i], 0);
			assertEq(nonce, 0, "Nonce should be 0");
		}
	}

	function testAccountFactory() public {
		address userA = utils.getNextUserAddress();

		address counterFactualSafeA = twoFAFactory.getAddress(userA, 0);

		address safeA = twoFAFactory.createAccount(userA, 0);
		assertEq(safeA, counterFactualSafeA, "Account factory address should be that of deployed account factory");
	}

	function testTokenBalance() public view {
		assertEq(token.balanceOf(account1), 100000000, "Balance should be 100000000");
		assertEq(token.balanceOf(account2), 0, "Balance should be 0");
	}

	function testAddingASession() public {
		uint256 sessionPrivateKey = 0x1234567890123456789012345678901234567890123456789012345678901236;
		address sessionOwner = vm.addr(sessionPrivateKey);

		OwnerManager ownerManager = OwnerManager(account1);
		assertEq(ownerManager.isOwner(sessionOwner), false, "Session owner should not be an owner");

		uint48 expiry = uint48(block.timestamp + 300);

		_addSession(sessionPrivateKey, providerPrivateKey, providerAccount, sessionSalt1, expiry);

		console.log("sessionOwner", sessionOwner);

		assertEq(ownerManager.isOwner(sessionOwner), true, "Session owner should be an owner");
	}

	function testTransfer() public {
		uint256 sessionPrivateKey = 0x1234567890123456789012345678901234567890123456789012345678901236;

		uint48 expiry = uint48(block.timestamp + 300);

		_addSession(sessionPrivateKey, providerPrivateKey, providerAccount, sessionSalt1, expiry);

		bytes memory initCode = bytes("");

		bytes memory transferData = abi.encodeWithSignature("transfer(address,uint256)", account2, 100000000);

		UserOperation memory userOp = createUserOperation(account1, initCode, address(token), transferData);

		(userOp.paymasterAndData, userOp.signature) = signUserOp(userOp, sessionPrivateKey);
		executeUserOp(userOp);

		assertEq(token.balanceOf(account1), 0, "Balance should be 0");
		assertEq(token.balanceOf(account2), 100000000, "Balance should be 100000000");
	}

	function testNoSessionTransfer() public {
		uint256 sessionPrivateKey = 0x1234567890123456789012345678901234567890123456789012345678901236;

		bytes memory initCode = bytes("");

		bytes memory transferData = abi.encodeWithSignature("transfer(address,uint256)", account2, 100000000);

		UserOperation memory userOp = createUserOperation(account1, initCode, address(token), transferData);

		(userOp.paymasterAndData, userOp.signature) = signUserOp(userOp, sessionPrivateKey);

		vm.expectRevert("AA24 signature error");
		executeUserOp(userOp);

		assertEq(token.balanceOf(account1), 100000000, "Balance should be 100000000");
		assertEq(token.balanceOf(account2), 0, "Balance should be 0");
	}

	function testExpiredSessionTransfer() public {
		uint256 sessionPrivateKey = 0x1234567890123456789012345678901234567890123456789012345678901236;

		uint48 expiry = uint48(block.timestamp + 2);

		_addSession(sessionPrivateKey, providerPrivateKey, providerAccount, sessionSalt1, expiry);

		vm.warp(block.timestamp + 3);

		bytes memory initCode = bytes("");

		bytes memory transferData = abi.encodeWithSignature("transfer(address,uint256)", account2, 100000000);

		UserOperation memory userOp = createUserOperation(account1, initCode, address(token), transferData);

		(userOp.paymasterAndData, userOp.signature) = signUserOp(userOp, sessionPrivateKey);
		vm.expectRevert("AA24 signature error");
		executeUserOp(userOp);

		assertEq(token.balanceOf(account1), 100000000, "Balance should be 100000000");
		assertEq(token.balanceOf(account2), 0, "Balance should be 0");
	}

	function testAddingSessionAsSigner() public {
		uint256 sessionPrivateKey = 0x1234567890123456789012345678901234567890123456789012345678901236;
		address sessionOwner = vm.addr(sessionPrivateKey);

		OwnerManager ownerManager = OwnerManager(account1);
		assertEq(ownerManager.isOwner(sessionOwner), false, "Session owner should not be an owner");

		uint48 expiry = uint48(block.timestamp + 300);

		_addSession(sessionPrivateKey, providerPrivateKey, providerAccount, sessionSalt1, expiry);

		assertEq(ownerManager.isOwner(sessionOwner), true, "Session owner should be an owner");

		uint256 session1PrivateKey = 0x1234567890123456789012345678901234567890123456789012345678901237;
		address session1Owner = vm.addr(session1PrivateKey);

		assertEq(ownerManager.isOwner(session1Owner), false, "Session1 owner should not be an owner");

		bytes memory initCode = bytes("");

		bytes memory data = abi.encodeWithSignature("addSigner(address)", session1Owner);

		UserOperation memory userOp = createUserOperation(account1, initCode, address(sessionManagerModule), data);

		(userOp.paymasterAndData, userOp.signature) = signUserOp(userOp, sessionPrivateKey);
		executeUserOp(userOp);

		assertEq(ownerManager.isOwner(session1Owner), true, "Session1 owner should be an owner");

		bytes memory initCode1 = bytes("");

		bytes memory data1 = abi.encodeWithSignature("revoke(address)", session1Owner);

		UserOperation memory userOp1 = createUserOperation(account1, initCode1, address(sessionManagerModule), data1);

		(userOp1.paymasterAndData, userOp1.signature) = signUserOp(userOp1, sessionPrivateKey);
		executeUserOp(userOp1);

		assertEq(ownerManager.isOwner(session1Owner), false, "Session1 owner should not be an owner");
	}

	function testRevokingMySession() public {
		uint256 sessionPrivateKey = 0x1234567890123456789012345678901234567890123456789012345678901236;
		address sessionOwner = vm.addr(sessionPrivateKey);

		OwnerManager ownerManager = OwnerManager(account1);
		assertEq(ownerManager.isOwner(sessionOwner), false, "Session owner should not be an owner");

		uint48 expiry = uint48(block.timestamp + 300);

		_addSession(sessionPrivateKey, providerPrivateKey, providerAccount, sessionSalt1, expiry);

		assertEq(ownerManager.isOwner(sessionOwner), true, "Session owner should be an owner");

		bytes memory initCode = bytes("");

		bytes memory data = abi.encodeWithSignature("revoke(address)", sessionOwner);

		UserOperation memory userOp = createUserOperation(account1, initCode, address(sessionManagerModule), data);

		(userOp.paymasterAndData, userOp.signature) = signUserOp(userOp, sessionPrivateKey);
		executeUserOp(userOp);

		assertEq(ownerManager.isOwner(sessionOwner), false, "Session owner should not be an owner");
	}

	function _addSession(
		uint256 _sessionPrivateKey,
		uint256 _providerPrivateKey,
		address _provider,
		bytes32 _sessionSalt,
		uint48 _expiry
	) private {
		address sessionOwner = vm.addr(_sessionPrivateKey);

		// Create session request hash and signature
		bytes32 sessionRequestHash = createSessionRequestHash(_provider, sessionOwner, _sessionSalt, _expiry);
		bytes memory signedSessionRequestHash = _signMessage(_sessionPrivateKey, sessionRequestHash);

		// Create session hash and signatures
		bytes32 challengeHash = keccak256(abi.encodePacked(uint256(123456)));
		bytes32 sessionHash = createSessionHash(sessionRequestHash, challengeHash);

		bytes memory providerSignedSessionHash = _signMessage(_providerPrivateKey, sessionHash);
		bytes memory sessionOwnerSignedSessionHash = _signMessage(_sessionPrivateKey, sessionHash);

		bytes memory initCode = bytes("");

		bytes memory data = abi.encodeWithSignature(
			"request(bytes32,bytes32,bytes,bytes,uint48)",
			_sessionSalt,
			sessionRequestHash,
			signedSessionRequestHash,
			providerSignedSessionHash,
			_expiry
		);

		userOp = createUserOperation(_provider, initCode, address(sessionManagerModule), data);

		userOp = prepareSignedUserOp(userOp, _providerPrivateKey);
		executeUserOp(userOp);

		bytes memory data1 = abi.encodeWithSignature(
			"confirm(bytes32,bytes32,bytes)",
			sessionRequestHash,
			sessionHash,
			sessionOwnerSignedSessionHash
		);

		userOp1 = createUserOperation(_provider, initCode, address(sessionManagerModule), data1);

		userOp1 = prepareSignedUserOp(userOp1, _providerPrivateKey);
		executeUserOp(userOp1);
	}

	// Helper function to sign a message and return the signature
	function _signMessage(uint256 privateKey, bytes32 messageHash) internal pure returns (bytes memory) {
		bytes32 ethSignedMessageHash = toEthSignedMessageHash(messageHash);
		(uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, ethSignedMessageHash);
		return abi.encodePacked(r, s, v);
	}

	function createSessionRequestHash(
		address provider,
		address sessionOwner,
		bytes32 sessionSalt,
		uint48 expiry
	) private pure returns (bytes32) {
		return keccak256(abi.encodePacked(provider, sessionOwner, sessionSalt, expiry));
	}

	function createSessionHash(bytes32 sessionRequestHash, bytes32 challengeHash) private pure returns (bytes32) {
		return keccak256(abi.encodePacked(sessionRequestHash, challengeHash));
	}

	function setupNewSafe() private returns (address, uint256) {
		uint256 newOwnerPrivateKey = uint256(keccak256(abi.encodePacked("deterministic_salt", block.number)));
		address newOwner = vm.addr(newOwnerPrivateKey);
		address newSafe = twoFAFactory.getAddress(newOwner, 0);
		upgradeableCommunityTokenScript.mint(newSafe, 100000000);
		return (newSafe, newOwnerPrivateKey);
	}

	function createUserOperation(
		address _safe,
		bytes memory initCode,
		address destination,
		bytes memory transferData
	) private view returns (UserOperation memory) {
		bytes memory callData = abi.encodeWithSelector(
			ModuleManager.execTransactionFromModule.selector,
			destination,
			0,
			transferData,
			Enum.Operation.Call
		);

		return
			UserOperation({
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

	function executeUserOp(UserOperation memory userOp) private {
		UserOperation[] memory userOperations = new UserOperation[](1);
		userOperations[0] = userOp;

		vm.startBroadcast(ownerPrivateKey);
		communityModule.handleOps(userOperations, payable(owner));
		vm.stopBroadcast();
	}

	function signUserOp(
		UserOperation memory userOp,
		uint256 newOwnerPrivateKey
	) private view returns (bytes memory, bytes memory) {
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

	function prepareSignedUserOp(
		UserOperation memory userOp,
		uint256 privateKey
	) internal returns (UserOperation memory) {
		(bytes memory paymasterData, bytes memory signature) = signUserOp(userOp, privateKey);
		userOp.paymasterAndData = paymasterData;
		userOp.signature = signature;
		return userOp;
	}
}
