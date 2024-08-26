// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { UserOperation } from "account-abstraction/interfaces/UserOperation.sol";

interface IPaymaster {
    function validatePaymasterUserOp(
        UserOperation calldata userOp
    ) external view returns (bool);
}
