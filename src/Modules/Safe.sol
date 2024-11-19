// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Safe as SafeBase } from "safe-smart-account/contracts/Safe.sol";

contract Safe is SafeBase {
    constructor(address[] memory owners, uint256 threshold) SafeBase() {}
}