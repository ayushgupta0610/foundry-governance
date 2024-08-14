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
    uint256 public constant VOTING_DELAY = 1 days; // 1 day after proposal is created
    uint256 public constant VOTING_PERIOD = 7 days; // 1 week to vote on a proposal

    address[] public proposers;
    address[] public executors;
    
    function setUp() public {

        vm.startPrank(USER);
        govToken = new GovToken(USER);
        console.log("GovToken Balance:", govToken.balanceOf(USER));
        govToken.delegate(USER); // Check this
        console.log("Delegated to USER");
        // vm.stopPrank();

        // Check votes after delegation
        console.log("User Votes after delegation:", govToken.getVotes(USER));
        
        // Deploy governor with timelock
        timelock = new Timelock(MIN_DELAY, proposers, executors, USER);
        governor = new MyGovernor(govToken, timelock);
        // uint256 userVotes = governor.getVotes(USER, block.number - 1);
        // console.log("User Votes:", userVotes);
        uint256 proposalThreshold = governor.proposalThreshold();
        console.log("Proposal Threshold:", proposalThreshold);

        bytes32 proposerRole = timelock.PROPOSER_ROLE();
        bytes32 executorRole = timelock.EXECUTOR_ROLE();

        // vm.startPrank(USER);
        timelock.grantRole(proposerRole, address(governor));
        timelock.grantRole(executorRole, address(0));
        vm.stopPrank();
        // TODO: Remove admin access from USER

        counter = new Counter(address(timelock));

    }

    function testVotingPower() public {
        uint256 balance = govToken.balanceOf(USER);
        uint256 votes = govToken.getVotes(USER);
        uint256 governorVotes = governor.getVotes(USER, block.number - 1);

        console.log("Final Balance:", balance);
        console.log("Final Votes in GovToken:", votes);
        console.log("Final Governor Votes:", governorVotes);

        assertEq(balance, votes, "Balance should equal votes in GovToken");
        assertEq(votes, governorVotes, "Votes in GovToken should equal governor votes");

        // Check if the governor recognizes the correct token
        assertEq(address(governor.token()), address(govToken), "Governor should recognize the correct token");

        // Check if the governor can query votes directly from the token
        uint256 directVotes = IVotes(address(govToken)).getVotes(USER);
        console.log("Direct Votes from IVotes interface:", directVotes);
        assertEq(directVotes, governorVotes, "Direct votes should equal governor votes");
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
        uint256 proposalId = governor.propose(addressesToCall, values, functionCalls, description);
        // 1.5 View the proposal state and simulate passing of 1 day
        console.log("Proposal State:", uint256(governor.state(proposalId)));
        vm.warp(block.timestamp + VOTING_DELAY + 1);
        vm.roll(block.number + VOTING_DELAY + 1);

        // 2. Vote on the proposal
        vm.prank(USER);
        // 0 = Against, 1 = For, 2 = Abstain for this example
        uint8 voteWay = 1;
        governor.castVote(proposalId, voteWay);
        // 2.5 simulate passing of 1 week
        vm.warp(block.timestamp + VOTING_PERIOD + 1);
        vm.roll(block.number + VOTING_PERIOD + 1);
        console.log("Proposal State:", uint256(governor.state(proposalId)));

        // 3. Queue the proposal
        bytes32 descriptionHash = keccak256(abi.encodePacked("Setting a number"));
        console.logBytes32(descriptionHash);
        bytes32 descriptionHashWithEncode = keccak256(abi.encode("Setting a number"));
        console.logBytes32(descriptionHashWithEncode);
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