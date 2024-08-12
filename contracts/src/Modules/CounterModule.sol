// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

error CountIsZero();

contract CounterModule {
    mapping(address => uint256) public count;

    function increment(address safeAddr) external {
        count[safeAddr] += 1;
    }

    function decrement(address safeAddr) external {
        if (count[safeAddr] == 0) revert CountIsZero();
        count[safeAddr] -= 1;
    }

    function setCount(uint256 _count, address safeAddr) external {
        count[safeAddr] = _count;
    }

    function getCount(address safeAddr) external view returns (uint256) {
        return count[safeAddr];
    }
}