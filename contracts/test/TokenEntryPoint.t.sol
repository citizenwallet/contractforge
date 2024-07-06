// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import { Test, console } from "forge-std/Test.sol";
import { Utils } from "./utils/Utils.sol";

import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { INonceManager } from "account-abstraction/interfaces/INonceManager.sol";

// Safe
import { Safe } from "safe-smart-account/contracts/Safe.sol";
import { SafeProxy } from "safe-smart-account/contracts/proxies/SafeProxy.sol";
import { TokenCallbackHandler } from "safe-smart-account/contracts/handler/TokenCallbackHandler.sol";

// Safe 4337 Module
import { Safe4337Module } from "../src/Modules/Safe4337Module.sol";
import { SafeTxConfig } from "../script/utils/SafeTxConfig.s.sol";

// 4337
import { EntryPoint } from "@cloned/Entrypoint/src/core/EntryPoint.sol";
import { TokenEntryPoint } from "../src/ERC4337/TokenEntryPoint.sol";
import { Paymaster } from "../src/ERC4337/Paymaster.sol";

import { BadgeCollection } from "../src/BadgeCollection.sol";

contract TokenEntryPointTest is Test {
	error SafeTxFailure(bytes reason);

	Safe public singleton;
	Safe public safe;
	SafeProxy public safeProxy;
	TokenCallbackHandler public handler;

	Safe4337Module public module;

	BadgeCollection public badgeCollection;
	EntryPoint public entryPoint;
	TokenEntryPoint public tokenEntryPoint;
	Paymaster public paymaster;
	address public proxy;

	Utils internal utils;

	address payable[] internal users;
	address internal sponsor;
	address internal owner;
	address internal admin;
	address internal safeDeployer;

	SafeTxConfig safeTxConfig = new SafeTxConfig();
	SafeTxConfig.Config config;

	function getTransactionHash(address _to, bytes memory _data) public view returns (bytes32) {
		return
			safe.getTransactionHash(
				_to,
				config.value,
				_data,
				config.operation,
				config.safeTxGas,
				config.baseGas,
				config.gasPrice,
				config.gasToken,
				config.refundReceiver,
				safe.nonce()
			);
	}

	function sendSafeTx(address _to, bytes memory _data, bytes memory sig) public {
		try
			safe.execTransaction(
				_to,
				config.value,
				_data,
				config.operation,
				config.safeTxGas,
				config.baseGas,
				config.gasPrice,
				config.gasToken,
				config.refundReceiver,
				sig //sig
			)
		{} catch (bytes memory reason) {
			revert SafeTxFailure(reason);
		}
	}

	function setUp() public {
		utils = new Utils();
		users = utils.createUsers(4);
		sponsor = users[0];
		vm.label(sponsor, "Sponsor");
		owner = users[1];
		vm.label(owner, "Owner");
		admin = users[2];
		vm.label(admin, "Admin");

		uint256 safeDeployerPK = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
		safeDeployer = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
		vm.label(safeDeployer, "Safe Deployer");

		vm.startPrank(owner);

		// deploy base 4337
		entryPoint = new EntryPoint();

		// plugin = new Plugin();
		singleton = new Safe();
		safeProxy = new SafeProxy(address(singleton));
		handler = new TokenCallbackHandler();
		safe = Safe(payable(address(safeProxy)));
		module = new Safe4337Module(address(entryPoint));

		console.log("hello");
		console.log(address(singleton));
		console.log(address(safeProxy));
		console.log(address(safe));
		console.log(address(module));

		address[] memory owners = new address[](1);
		owners[0] = owner;
		safe.setup(owners, 1, address(0), bytes(""), address(handler), address(0), 0, payable(address(owner)));

		console.log("1");

		config = safeTxConfig.run(owner);

		bytes32 txHash = getTransactionHash(
			address(safe),
			abi.encodeWithSignature("enableModule(address)", address(module))
		);
		console.log("1 1");
		(uint8 v, bytes32 r, bytes32 s) = vm.sign(safeDeployerPK, txHash);
		console.log("1 2");
		sendSafeTx(
			address(safe),
			abi.encodeWithSignature("enableModule(address)", address(module)),
			abi.encodePacked(r, s, v)
		);


		console.log("2");

		// deploy BadgeCollection
		address implementation = address(new BadgeCollection());
		bytes memory data = abi.encodeCall(BadgeCollection.initialize, owner);

		proxy = address(new ERC1967Proxy(implementation, data));

		badgeCollection = BadgeCollection(proxy);

		// deploy 4337
		entryPoint = new EntryPoint();

		implementation = address(new Paymaster());
		data = abi.encodeCall(Paymaster.initialize, (owner, sponsor));

		proxy = address(new ERC1967Proxy(implementation, data));

		paymaster = Paymaster(proxy);

		implementation = address(new TokenEntryPoint(INonceManager(address(entryPoint))));
		address[] memory whitelisted = new address[](1);
		whitelisted[0] = address(badgeCollection);

		data = abi.encodeCall(TokenEntryPoint.initialize, (owner, address(paymaster), whitelisted));
		proxy = address(new ERC1967Proxy(implementation, data));

		tokenEntryPoint = TokenEntryPoint(proxy);

		badgeCollection.grantRole(badgeCollection.BADGE_COLLECTION_ADMIN_ROLE(), admin);
		badgeCollection.grantRole(badgeCollection.BADGE_ADMIN_ROLE(), admin);
		vm.stopPrank();

		console.log("3");
	}

	function testOwner() public view {
		assertEq(badgeCollection.owner(), owner);
	}

	// function testRoleSetup() public {
	// 	assertEq(badgeCollection.hasRole(badgeCollection.BADGE_COLLECTION_ADMIN_ROLE(), owner), true);
	// 	assertEq(badgeCollection.hasRole(badgeCollection.BADGE_COLLECTION_ADMIN_ROLE(), admin), true);

	// 	vm.startPrank(owner);
	// 	badgeCollection.revokeRole(badgeCollection.BADGE_COLLECTION_ADMIN_ROLE(), admin);
	// 	vm.stopPrank();

	// 	assertEq(badgeCollection.hasRole(badgeCollection.BADGE_COLLECTION_ADMIN_ROLE(), admin), false);
	// }

	// function testCreateBadge() public {
	// 	uint256 id = 1;
	// 	uint48 claimFrom = uint48(block.timestamp);
	// 	uint48 claimTo = uint48(block.timestamp + 7 days);
	// 	uint256 maxClaim = 100;
	// 	uint48 updateUntil = uint48(block.timestamp + 30 days);
	// 	string memory _uri = "https://example.com/token-metadata.json";

	// 	vm.startPrank(admin);
	// 	badgeCollection.create(id, claimFrom, claimTo, maxClaim, updateUntil, _uri);
	// 	vm.stopPrank();

	// 	(
	// 		uint48 returnedClaimFrom,
	// 		uint48 returnedClaimTo,
	// 		uint256 returnedMaxClaim,
	// 		uint48 returnedUpdateUntil,
	// 		string memory returnedUri
	// 	) = badgeCollection.get(id);

	// 	// check that they are equal
	// 	assertEq(returnedClaimFrom, claimFrom);
	// 	assertEq(returnedClaimTo, claimTo);
	// 	assertEq(returnedMaxClaim, maxClaim);
	// 	assertEq(returnedUpdateUntil, updateUntil);
	// 	assertEq(returnedUri, _uri);

	// 	// check that the uri is set
	// 	assertEq(badgeCollection.uri(id), _uri);
	// }
}
