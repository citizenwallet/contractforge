// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { UserOperation } from "account-abstraction/interfaces/UserOperation.sol";

interface IUserOpValidator {
    function validateUserOp(
        UserOperation calldata userOp,
        bytes32 userOpHash
    ) external returns (bool);
}
