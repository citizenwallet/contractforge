// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { PackedUserOperation } from "account-abstraction/interfaces/PackedUserOperation.sol";

interface IUserOpValidator {
    function validateUserOp(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash
    ) external returns (bool);
}
