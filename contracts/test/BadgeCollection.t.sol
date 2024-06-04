// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Test, console } from "forge-std/Test.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

import { Utils } from "./utils/Utils.sol";
import { BadgeCollection } from "../src/BadgeCollection.sol";

contract BadgeCollectionTest is Test {
	BadgeCollection public badgeCollection;
	address public proxy;

	Utils internal utils;

	address payable[] internal users;
	address internal owner;
	address internal admin;

	function setUp() public {
		utils = new Utils();
		users = utils.createUsers(2);
		owner = users[0];
		vm.label(owner, "Owner");
		admin = users[1];
		vm.label(admin, "Admin");

		address implementation = address(new BadgeCollection());

		bytes memory data = abi.encodeCall(BadgeCollection.initialize, owner);
		proxy = address(new ERC1967Proxy(implementation, data));

		badgeCollection = BadgeCollection(proxy);

		vm.startPrank(owner);
		badgeCollection.grantRole(badgeCollection.BADGE_COLLECTION_ADMIN_ROLE(), admin);
		badgeCollection.grantRole(badgeCollection.BADGE_ADMIN_ROLE(), admin);
		vm.stopPrank();
	}

	function testOwner() public view {
		assertEq(badgeCollection.owner(), owner);
	}

	function testRoleSetup() public {
		assertEq(badgeCollection.hasRole(badgeCollection.BADGE_COLLECTION_ADMIN_ROLE(), owner), true);
		assertEq(badgeCollection.hasRole(badgeCollection.BADGE_COLLECTION_ADMIN_ROLE(), admin), true);

		vm.startPrank(owner);
		badgeCollection.revokeRole(badgeCollection.BADGE_COLLECTION_ADMIN_ROLE(), admin);
		vm.stopPrank();

		assertEq(badgeCollection.hasRole(badgeCollection.BADGE_COLLECTION_ADMIN_ROLE(), admin), false);
	}

	function testCreateBadge() public {
		uint256 id = 1;
		uint48 claimFrom = uint48(block.timestamp);
		uint48 claimTo = uint48(block.timestamp + 7 days);
		uint256 maxClaim = 100;
		uint48 updateUntil = uint48(block.timestamp + 30 days);
		string memory _uri = "https://example.com/token-metadata.json";

		vm.startPrank(admin);
		badgeCollection.create(id, claimFrom, claimTo, maxClaim, updateUntil, _uri);
		vm.stopPrank();

		(
			uint48 returnedClaimFrom,
			uint48 returnedClaimTo,
			uint256 returnedMaxClaim,
			uint48 returnedUpdateUntil,
			string memory returnedUri
		) = badgeCollection.get(id);

		// check that they are equal
        assertEq(returnedClaimFrom, claimFrom);
        assertEq(returnedClaimTo, claimTo);
        assertEq(returnedMaxClaim, maxClaim);
        assertEq(returnedUpdateUntil, updateUntil);
        assertEq(returnedUri, _uri);

        // check that the uri is set
        assertEq(badgeCollection.uri(id), _uri);
	}
}
