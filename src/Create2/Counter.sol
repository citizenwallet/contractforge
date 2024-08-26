// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract Counter {
    uint256 public count;

    // Function to get the current count
    function getCount() public view returns (uint256) {
        return count;
    }

    // Function to increment count
    function increment() public {
        count += 1;
    }

    // Function to decrement count
    function decrement() public {
        require(count > 0, "Counter: cannot decrement below zero");
        count -= 1;
    }
}