// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { PackedUserOperation } from "account-abstraction/interfaces/PackedUserOperation.sol";

interface ITokenEntryPoint {
    function handleOps(
        PackedUserOperation[] calldata ops,
        address payable beneficiary
    ) external;
}
