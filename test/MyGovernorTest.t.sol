// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {MyGovernor} from "../src/MyGovernor.sol";
import {Counter} from "../src/Counter.sol";
import {Timelock} from "../src/Timelock.sol";
import {GovToken} from "../src/GovToken.sol";
import {IVotes} from "@openzeppelin/contracts/governance/extensions/GovernorVotes.sol";

contract MyGovernorTest is Test {

    MyGovernor governor;
    Counter counter;
    Timelock timelock;
    GovToken govToken;

    address public USER = makeAddr("user");
    uint256 public constant INITIAL_SUPPLY = 100 ether;

    uint256 public constant MIN_DELAY = 3600; // 1 hour after a vote passes
    uint256 public constant VOTING_DELAY = 1; // 1 block after proposal is created
    uint256 public constant VOTING_PERIOD = 50400; // 1 week to vote on a proposal

    address[] public proposers;
    address[] public executors;
    
    function setUp() public {

        vm.startPrank(USER);
        govToken = new GovToken(USER);
        console.log("Initial GovToken Balance:", govToken.balanceOf(USER));
        console.log("Initial block number:", block.number);

        govToken.delegate(USER);
        console.log("Delegated to USER at block:", block.number);

        vm.roll(block.number + 1);
        console.log("Rolled to block:", block.number);
        console.log("User Votes after delegation:", govToken.getVotes(USER));
        // vm.stopPrank();

        // Deploy governor with timelock
        timelock = new Timelock(MIN_DELAY, proposers, executors, USER);
        governor = new MyGovernor(govToken, timelock);
        console.log("Governor deployed at block:", block.number);
        console.log("Governor's token address:", address(governor.token()));
        console.log("GovToken address:", address(govToken));

        bytes32 proposerRole = timelock.PROPOSER_ROLE();
        bytes32 executorRole = timelock.EXECUTOR_ROLE();

        // vm.startPrank(USER);
        timelock.grantRole(proposerRole, address(governor));
        timelock.grantRole(executorRole, address(0));
        // Remove admin access from USER
        timelock.revokeRole(timelock.DEFAULT_ADMIN_ROLE(), USER);
        vm.stopPrank();


        // Note: this is not the address of the governor, but the address of the timelock
        counter = new Counter(address(timelock));

    }

    function testCantUpdateCounterWithoutGovernance() public {
        vm.startPrank(USER);
        vm.expectRevert();
        counter.setNumber(5);
        vm.stopPrank();
    }

    function testGovernanceUpdatesCounter() public {
        // 1. Propose to the DAO
        address[] memory addressesToCall = new address[](1);
        addressesToCall[0] = address(counter);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory functionCalls = new bytes[](1);
        functionCalls[0] = abi.encode("setNumber(uint256)", 5);
        string memory description = "Setting a number";
        vm.prank(USER);
        uint256 proposalId = governor.propose(addressesToCall, values, functionCalls, description);
        // 1.5 View the proposal state and simulate passing of 1 block
        // console.log("Proposal State:", uint256(governor.state(proposalId)));
        vm.warp(block.timestamp + VOTING_DELAY + 1);
        vm.roll(block.number + VOTING_DELAY + 1);
        console.log("Proposal State:", uint256(governor.state(proposalId)));

        // 2. Vote on the proposal
        // 0 = Against, 1 = For, 2 = Abstain for this example
        uint8 voteWay = 1;
        string memory reason = "I want to set the number to 5";
        vm.prank(USER);
        governor.castVoteWithReason(proposalId, voteWay, reason);
        // 2.5 simulate passing of 1 week
        vm.warp(block.timestamp + VOTING_PERIOD + 1);
        vm.roll(block.number + VOTING_PERIOD + 1);
        console.log("Proposal State:", uint256(governor.state(proposalId)));

        // 3. Queue the proposal
        bytes32 descriptionHash = keccak256(abi.encodePacked("Setting a number"));
        governor.queue(addressesToCall, values, functionCalls, descriptionHash);
        // 3.5 simulate passing of 1 hour
        vm.roll(block.number + MIN_DELAY + 1);
        vm.warp(block.timestamp + MIN_DELAY + 1);
        console.log("Proposal State:", uint256(governor.state(proposalId)));

        // 4. Execute the proposal
        governor.execute(addressesToCall, values, functionCalls, descriptionHash);

        assertEq(counter.number(), 5);
    }

}