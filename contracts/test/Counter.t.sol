// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/Create2/Counter.sol";

contract CounterTest is Test {
    Counter public counter;

    function setUp() public {
        counter = new Counter();
    }

    function testInitialCount() public {
        uint256 initialCount = counter.getCount();
        assertEq(initialCount, 0);
    }

    function testIncrement() public {
        counter.increment();
        uint256 newCount = counter.getCount();
        assertEq(newCount, 1);
    }

    function testDecrement() public {
        counter.increment(); // increment first to avoid underflow
        counter.decrement();
        uint256 newCount = counter.getCount();
        assertEq(newCount, 0);
    }

    function testDecrementBelowZero() public {
        vm.expectRevert("Counter: cannot decrement below zero");
        counter.decrement();
    }
}