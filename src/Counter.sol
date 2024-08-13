// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract Counter {
    uint256 public number;

    event Set(uint256 oldNumber, uint256 newNumber);
    event Increment(uint256 incrementedNumber);

    function setNumber(uint256 newNumber) public {
        emit Set(number, newNumber);
        number = newNumber;
    }

    function increment() public {
        emit Increment(number + 1);
        number++;
    }
}
