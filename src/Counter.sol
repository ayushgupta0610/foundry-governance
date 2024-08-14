// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract Counter is Ownable {
    uint256 public number;

    event Set(uint256 oldNumber, uint256 newNumber);
    event Increment(uint256 incrementedNumber);

    constructor(address initialOwner) Ownable(initialOwner) {}

    function setNumber(uint256 newNumber) public {
        emit Set(number, newNumber);
        number = newNumber;
    }

    function increment() public onlyOwner {
        emit Increment(number + 1);
        number++;
    }
}
