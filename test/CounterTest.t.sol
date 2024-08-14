// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {Counter} from "../src/Counter.sol";

contract CounterTest is Test {
    Counter public counter;
    address public owner = address(1);

    function setUp() public {
        vm.startPrank(owner);
        counter = new Counter(owner);
        vm.stopPrank();
    }

    function testIncrement() public {
        vm.startPrank(owner);
        uint256 initialValue = counter.number();
        counter.increment();
        assertEq(counter.number(), initialValue + 1, "Counter should increment by 1");
        vm.stopPrank();
    }

    function testIncrementFailsForNonOwner() public {
        address nonOwner = address(2);
        vm.startPrank(nonOwner);
        vm.expectRevert("Ownable: caller is not the owner");
        counter.increment();
        vm.stopPrank();
    }
}