// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { PackedUserOperation } from "account-abstraction/interfaces/PackedUserOperation.sol";

interface IPaymaster {
    function validatePaymasterUserOp(
        PackedUserOperation calldata userOp
    ) external view returns (bool);
}
