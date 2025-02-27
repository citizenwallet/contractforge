// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

struct SessionRequest {
	uint48 expiry;
	bytes signedSessionHash;
	address owner;
    address account;
}

struct ActiveSession {
	uint48 expiry;
	address owner;
	address account;
}