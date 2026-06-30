// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "forge-std/Test.sol";
import "../src/StakedAIBounty.sol";

contract StakedAIBountyTest is Test {
    StakedAIBounty public bounty;
    address owner = address(0x1);
    address alice = address(0x2);
    address bob = address(0x3);
    uint256 challengeId;
    bytes32 aliceCommitment;
    bytes32 bobCommitment;
    bytes32 aliceSalt = keccak256("alice_salt");
    bytes32 bobSalt = keccak256("bob_salt");
    string aliceAnswer = "Alice's solution";
    string bobAnswer = "Bob's solution";
    uint256 minStake = 0.01 ether;
    uint256 reward = 1 ether;

    function setUp() public {
        vm.deal(owner, 10 ether);
        vm.deal(alice, 1 ether);
        vm.deal(bob, 1 ether);
        bounty = new StakedAIBounty();
        vm.startPrank(owner);
        uint256 commitDeadline = block.timestamp + 1 days;
        bounty.createChallenge{value: reward}("Test", commitDeadline, 2 days, minStake);
        challengeId = 0;
        vm.stopPrank();
        aliceCommitment = keccak256(abi.encodePacked(aliceAnswer, aliceSalt, alice, challengeId));
        bobCommitment = keccak256(abi.encodePacked(bobAnswer, bobSalt, bob, challengeId));
    }

    function testFullFlow() public {
        // Record initial balances
        uint256 aliceInitial = alice.balance;
        uint256 bobInitial = bob.balance;

        // Alice commits with stake
        vm.startPrank(alice);
        bounty.commitSolution{value: minStake}(challengeId, aliceCommitment);
        vm.stopPrank();
        assertEq(alice.balance, aliceInitial - minStake);

        // Bob commits with stake
        vm.startPrank(bob);
        bounty.commitSolution{value: minStake}(challengeId, bobCommitment);
        vm.stopPrank();
        assertEq(bob.balance, bobInitial - minStake);

        // Move to reveal phase
        vm.warp(block.timestamp + 1 days + 1);

        // Alice reveals, gets stake refunded
        vm.startPrank(alice);
        bounty.revealSolution(challengeId, aliceAnswer, aliceSalt);
        vm.stopPrank();
        assertEq(alice.balance, aliceInitial);

        // Bob reveals, gets stake refunded
        vm.startPrank(bob);
        bounty.revealSolution(challengeId, bobAnswer, bobSalt);
        vm.stopPrank();
        assertEq(bob.balance, bobInitial);

        // Move to after reveal phase
        vm.warp(block.timestamp + 2 days + 1);

        // Owner judges and finalizes
        vm.startPrank(owner);
        bounty.judgeAll(challengeId, bytes(""));
        bounty.finalizeWinner(challengeId, 1); // Bob wins
        vm.stopPrank();

        // Verify winner
        StakedAIBounty.ChallengeInfo memory info = bounty.getChallengeInfo(challengeId);
        assertEq(info.winner, bob);

        // Bob should have initial + reward (stake already refunded)
        assertEq(bob.balance, bobInitial + reward);

        // Alice should have initial (no reward, no stake lost because she revealed)
        assertEq(alice.balance, aliceInitial);

        // Check that contract balance is 0 (all funds distributed)
        assertEq(address(bounty).balance, 0);
    }

    function testWinnerGetsReward() public {
        // Use a fresh setup with only Alice
        // We need to record the initial balance *after* the contract is deployed
        // but *before* any transactions from Alice
        uint256 aliceInitial = alice.balance;

        // Alice commits with stake
        vm.startPrank(alice);
        bounty.commitSolution{value: minStake}(challengeId, aliceCommitment);
        vm.stopPrank();

        // Move to reveal phase
        vm.warp(block.timestamp + 1 days + 1);

        // Alice reveals, gets stake refunded
        vm.startPrank(alice);
        bounty.revealSolution(challengeId, aliceAnswer, aliceSalt);
        vm.stopPrank();

        // Move to after reveal phase
        vm.warp(block.timestamp + 2 days + 1);

        // Owner judges and finalizes
        vm.startPrank(owner);
        bounty.judgeAll(challengeId, bytes(""));
        bounty.finalizeWinner(challengeId, 0); // Alice wins
        vm.stopPrank();

        // Alice should have initial + reward
        // (stake was refunded on reveal, so no net change from stake)
        assertEq(alice.balance, aliceInitial + reward);

        // Check that contract balance is 0
        assertEq(address(bounty).balance, 0);
    }

    function testCannotRevealBeforeDeadline() public {
        vm.startPrank(alice);
        bounty.commitSolution{value: minStake}(challengeId, aliceCommitment);
        vm.expectRevert("Not reveal phase");
        bounty.revealSolution(challengeId, aliceAnswer, aliceSalt);
        vm.stopPrank();
    }

    function testInsufficientStake() public {
        vm.startPrank(alice);
        vm.expectRevert("Stake too low");
        bounty.commitSolution{value: minStake - 1 wei}(challengeId, aliceCommitment);
        vm.stopPrank();
    }

    function testOnlyOwnerCanJudge() public {
        vm.startPrank(alice);
        vm.expectRevert("Not challenge owner");
        bounty.judgeAll(challengeId, bytes(""));
        vm.stopPrank();
    }
}
