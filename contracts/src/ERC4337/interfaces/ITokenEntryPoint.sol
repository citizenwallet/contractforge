// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { UserOperation } from "account-abstraction/interfaces/UserOperation.sol";

interface ITokenEntryPoint {
    function handleOps(
        UserOperation[] calldata ops,
        address payable beneficiary
    ) external;
}
