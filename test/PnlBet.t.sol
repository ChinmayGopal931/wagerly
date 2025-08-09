// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/PnlBet.sol";
import "../src/BetFactory.sol";
import "./mocks/MockL1Read.sol";

contract PnlBetTest is Test {
    PnlBet public pnlBetLogic;
    BetFactory public factory;
    MockL1Read public mockL1Read;
    address public betProxy;

    address public alice = address(0x1);
    address public bob = address(0x2);
    address public charlie = address(0x3);
    address public targetUser = address(0x4);

    uint32 public perpId = 1;
    uint256 public duration = 1 hours;

    event BetPlaced(address indexed bettor, bool isBettingOnProfit, uint256 amount);
    event BetSettled(PnlBet.Outcome outcome, uint256 totalPool);
    event WinningsClaimed(address indexed winner, uint256 amount);

    function setUp() public {
        // Deploy mock L1Read contract
        mockL1Read = new MockL1Read();

        // Deploy logic contract with mock addresses
        pnlBetLogic = new PnlBet(address(mockL1Read), address(mockL1Read));

        // Deploy factory
        factory = new BetFactory(address(pnlBetLogic));

        // Create a test bet
        betProxy = factory.createBet(targetUser, perpId, duration);

        // Fund test accounts
        vm.deal(alice, 10 ether);
        vm.deal(bob, 10 ether);
        vm.deal(charlie, 10 ether);
    }

    function testInitialization() public {
        PnlBet bet = PnlBet(betProxy);

        assertEq(bet.targetUser(), targetUser);
        assertEq(bet.perpId(), perpId);
        assertEq(bet.endTime(), block.timestamp + duration);
        assertEq(uint256(bet.outcome()), uint256(PnlBet.Outcome.Undecided));
        assertFalse(bet.isSettled());
    }

    function testPlaceBetOnProfit() public {
        PnlBet bet = PnlBet(betProxy);
        uint256 betAmount = 1 ether;

        vm.startPrank(alice);
        vm.expectEmit(true, false, false, true);
        emit BetPlaced(alice, true, betAmount);
        bet.placeBet{value: betAmount}(true);
        vm.stopPrank();

        assertEq(bet.profitableBets(alice), betAmount);
        assertEq(bet.profitablePoolBalance(), betAmount);
    }

    function testPlaceBetOnLoss() public {
        PnlBet bet = PnlBet(betProxy);
        uint256 betAmount = 2 ether;

        vm.startPrank(bob);
        vm.expectEmit(true, false, false, true);
        emit BetPlaced(bob, false, betAmount);
        bet.placeBet{value: betAmount}(false);
        vm.stopPrank();

        assertEq(bet.unprofitableBets(bob), betAmount);
        assertEq(bet.unprofitablePoolBalance(), betAmount);
    }

    function testCannotBetAfterEnd() public {
        PnlBet bet = PnlBet(betProxy);

        // Fast forward past end time
        vm.warp(block.timestamp + duration + 1);

        vm.startPrank(alice);
        vm.expectRevert(PnlBet.BettingClosed.selector);
        bet.placeBet{value: 1 ether}(true);
        vm.stopPrank();
    }

    function testCannotBetZeroAmount() public {
        PnlBet bet = PnlBet(betProxy);

        vm.startPrank(alice);
        vm.expectRevert("Must bet non-zero amount");
        bet.placeBet{value: 0}(true);
        vm.stopPrank();
    }

    function testCannotSettleBeforeEnd() public {
        PnlBet bet = PnlBet(betProxy);

        vm.expectRevert(PnlBet.BetNotOver.selector);
        bet.settle();
    }

    function testSettlement() public {
        PnlBet bet = PnlBet(betProxy);
        uint256 totalPool = 3 ether;

        // Place some bets
        vm.prank(alice);
        bet.placeBet{value: 1 ether}(true);

        vm.prank(bob);
        bet.placeBet{value: 2 ether}(false);

        // Fast forward past end time
        vm.warp(block.timestamp + duration + 1);

        // Settle the bet
        vm.expectEmit(false, false, false, true);
        emit BetSettled(PnlBet.Outcome.Profitable, totalPool); // This might vary due to mock randomness
        bet.settle();

        assertTrue(bet.isSettled());
        assertTrue(uint256(bet.outcome()) != uint256(PnlBet.Outcome.Undecided));
    }

    function testClaimWinnings() public {
        PnlBet bet = PnlBet(betProxy);

        // Place bets
        vm.prank(alice);
        bet.placeBet{value: 1 ether}(true);

        vm.prank(bob);
        bet.placeBet{value: 2 ether}(false);

        // Record initial balances
        uint256 aliceInitial = alice.balance;
        uint256 bobInitial = bob.balance;

        // Fast forward and settle
        vm.warp(block.timestamp + duration + 1);
        bet.settle();

        // Determine winner and claim
        PnlBet.Outcome outcome = bet.outcome();

        if (outcome == PnlBet.Outcome.Profitable) {
            // Alice wins
            vm.prank(alice);
            bet.claimWinnings();
            assertGt(alice.balance, aliceInitial);
        } else {
            // Bob wins
            vm.prank(bob);
            bet.claimWinnings();
            assertGt(bob.balance, bobInitial);
        }
    }

    function testCannotClaimBeforeSettlement() public {
        PnlBet bet = PnlBet(betProxy);

        vm.prank(alice);
        bet.placeBet{value: 1 ether}(true);

        vm.prank(alice);
        vm.expectRevert(PnlBet.BetNotSettled.selector);
        bet.claimWinnings();
    }

    function testMultipleBets() public {
        PnlBet bet = PnlBet(betProxy);

        // Multiple bets from same user
        vm.startPrank(alice);
        bet.placeBet{value: 1 ether}(true);
        bet.placeBet{value: 0.5 ether}(true);
        vm.stopPrank();

        assertEq(bet.profitableBets(alice), 1.5 ether);
        assertEq(bet.profitablePoolBalance(), 1.5 ether);
    }

    function testGetTotalPool() public {
        PnlBet bet = PnlBet(betProxy);

        vm.prank(alice);
        bet.placeBet{value: 1 ether}(true);

        vm.prank(bob);
        bet.placeBet{value: 2 ether}(false);

        assertEq(bet.getTotalPool(), 3 ether);
    }

    function testGetUserBet() public {
        PnlBet bet = PnlBet(betProxy);

        vm.prank(alice);
        bet.placeBet{value: 1 ether}(true);

        vm.prank(alice);
        bet.placeBet{value: 0.5 ether}(false);

        (uint256 profitBet, uint256 lossBet) = bet.getUserBet(alice);
        assertEq(profitBet, 1 ether);
        assertEq(lossBet, 0.5 ether);
    }
}
