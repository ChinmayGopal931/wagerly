// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/PnlBet.sol";
import "../src/BetFactory.sol";
import "./mocks/MockL1Read.sol";

contract BetFactoryTest is Test {
    PnlBet public pnlBetLogic;
    BetFactory public factory;
    MockL1Read public mockL1Read;
    
    address public alice = address(0x1);
    address public bob = address(0x2);
    address public targetUser1 = address(0x3);
    address public targetUser2 = address(0x4);
    
    uint32 public perpId = 1;
    uint256 public duration = 1 hours;
    
    event BetCreated(
        address indexed newBetAddress,
        address indexed creator,
        address indexed targetUser,
        uint32 perpId,
        uint256 endTime
    );

    function setUp() public {
        // Deploy mock L1Read contract
        mockL1Read = new MockL1Read();
        
        // Deploy logic contract with mock addresses
        pnlBetLogic = new PnlBet(address(mockL1Read), address(mockL1Read));
        factory = new BetFactory(address(pnlBetLogic));
        
        vm.deal(alice, 10 ether);
        vm.deal(bob, 10 ether);
    }

    function testCreateBet() public {
        vm.startPrank(alice);
        
        uint256 expectedEndTime = block.timestamp + duration;
        
        vm.expectEmit(false, true, true, true);
        emit BetCreated(address(0), alice, targetUser1, perpId, expectedEndTime);
        
        address betAddress = factory.createBet(targetUser1, perpId, duration);
        vm.stopPrank();
        
        // Verify bet was created correctly
        PnlBet bet = PnlBet(betAddress);
        assertEq(bet.targetUser(), targetUser1);
        assertEq(bet.perpId(), perpId);
        assertEq(bet.endTime(), expectedEndTime);
        
        // Verify bet was added to registries
        address[] memory allBets = factory.getAllBets();
        assertEq(allBets.length, 1);
        assertEq(allBets[0], betAddress);
        
        address[] memory userBets = factory.getUserCreatedBets(alice);
        assertEq(userBets.length, 1);
        assertEq(userBets[0], betAddress);
        
        address[] memory targetBets = factory.getTargetUserBets(targetUser1);
        assertEq(targetBets.length, 1);
        assertEq(targetBets[0], betAddress);
    }

    function testCannotCreateBetWithZeroAddress() public {
        vm.startPrank(alice);
        vm.expectRevert(BetFactory.InvalidTargetUser.selector);
        factory.createBet(address(0), perpId, duration);
        vm.stopPrank();
    }

    function testCannotCreateBetWithInvalidDuration() public {
        vm.startPrank(alice);
        
        // Zero duration
        vm.expectRevert(BetFactory.InvalidDuration.selector);
        factory.createBet(targetUser1, perpId, 0);
        
        // Duration too long (> 365 days)
        vm.expectRevert(BetFactory.InvalidDuration.selector);
        factory.createBet(targetUser1, perpId, 366 days);
        
        vm.stopPrank();
    }

    function testMultipleBets() public {
        // Alice creates a bet
        vm.prank(alice);
        address bet1 = factory.createBet(targetUser1, perpId, duration);
        
        // Bob creates a bet
        vm.prank(bob);
        address bet2 = factory.createBet(targetUser2, perpId + 1, duration);
        
        // Alice creates another bet
        vm.prank(alice);
        address bet3 = factory.createBet(targetUser1, perpId + 2, duration);
        
        // Check total bets
        assertEq(factory.getBetCount(), 3);
        
        // Check all bets
        address[] memory allBets = factory.getAllBets();
        assertEq(allBets.length, 3);
        assertEq(allBets[0], bet1);
        assertEq(allBets[1], bet2);
        assertEq(allBets[2], bet3);
        
        // Check user-created bets
        address[] memory aliceBets = factory.getUserCreatedBets(alice);
        assertEq(aliceBets.length, 2);
        assertEq(aliceBets[0], bet1);
        assertEq(aliceBets[1], bet3);
        
        address[] memory bobBets = factory.getUserCreatedBets(bob);
        assertEq(bobBets.length, 1);
        assertEq(bobBets[0], bet2);
        
        // Check target user bets
        address[] memory target1Bets = factory.getTargetUserBets(targetUser1);
        assertEq(target1Bets.length, 2);
        assertEq(target1Bets[0], bet1);
        assertEq(target1Bets[1], bet3);
    }

    function testGetActiveBets() public {
        // Create some bets
        vm.prank(alice);
        address bet1 = factory.createBet(targetUser1, perpId, duration);
        
        vm.prank(bob);
        address bet2 = factory.createBet(targetUser2, perpId + 1, duration / 2);
        
        // All bets should be active initially
        address[] memory activeBets = factory.getActiveBets();
        assertEq(activeBets.length, 2);
        
        // Fast forward past bet2's end time but not bet1's
        vm.warp(block.timestamp + (duration / 2) + 1);
        
        activeBets = factory.getActiveBets();
        assertEq(activeBets.length, 1);
        assertEq(activeBets[0], bet1);
        
        // Fast forward past all bets
        vm.warp(block.timestamp + duration);
        
        activeBets = factory.getActiveBets();
        assertEq(activeBets.length, 0);
    }

    function testGetSettlableBets() public {
        // Create some bets
        vm.prank(alice);
        address bet1 = factory.createBet(targetUser1, perpId, duration);
        
        vm.prank(bob);
        address bet2 = factory.createBet(targetUser2, perpId + 1, duration / 2);
        
        // No bets should be settlable initially
        address[] memory settlableBets = factory.getSettlableBets();
        assertEq(settlableBets.length, 0);
        
        // Fast forward past bet2's end time but not bet1's
        vm.warp(block.timestamp + (duration / 2) + 1);
        
        settlableBets = factory.getSettlableBets();
        assertEq(settlableBets.length, 1);
        assertEq(settlableBets[0], bet2);
        
        // Fast forward past all bets
        vm.warp(block.timestamp + duration);
        
        settlableBets = factory.getSettlableBets();
        assertEq(settlableBets.length, 2);
    }

    function testBatchSettle() public {
        // Create some bets with different durations
        vm.prank(alice);
        address bet1 = factory.createBet(targetUser1, perpId, duration / 2);
        
        vm.prank(bob);
        address bet2 = factory.createBet(targetUser2, perpId + 1, duration);
        
        // Add some bets to them
        vm.prank(alice);
        PnlBet(bet1).placeBet{value: 1 ether}(true);
        
        vm.prank(bob);
        PnlBet(bet2).placeBet{value: 1 ether}(false);
        
        // Fast forward past first bet's end time
        vm.warp(block.timestamp + (duration / 2) + 1);
        
        // Create array for batch settle
        address[] memory betsToSettle = new address[](2);
        betsToSettle[0] = bet1;
        betsToSettle[1] = bet2;
        
        // Batch settle
        factory.batchSettle(betsToSettle);
        
        // Only bet1 should be settled (bet2 hasn't ended yet)
        assertTrue(PnlBet(bet1).isSettled());
        assertFalse(PnlBet(bet2).isSettled());
    }

    function testProxyIndependence() public {
        // Create two bets
        vm.prank(alice);
        address bet1 = factory.createBet(targetUser1, perpId, duration);
        
        vm.prank(alice);
        address bet2 = factory.createBet(targetUser2, perpId + 1, duration);
        
        // Place different bets in each
        vm.prank(alice);
        PnlBet(bet1).placeBet{value: 1 ether}(true);
        
        vm.prank(alice);
        PnlBet(bet2).placeBet{value: 2 ether}(false);
        
        // Verify they have independent state
        assertEq(PnlBet(bet1).profitablePoolBalance(), 1 ether);
        assertEq(PnlBet(bet1).unprofitablePoolBalance(), 0);
        
        assertEq(PnlBet(bet2).profitablePoolBalance(), 0);
        assertEq(PnlBet(bet2).unprofitablePoolBalance(), 2 ether);
        
        assertEq(PnlBet(bet1).targetUser(), targetUser1);
        assertEq(PnlBet(bet2).targetUser(), targetUser2);
    }

    function testOwnershipFunctionality() public {
        // Only owner should be able to call owner functions (if any are added)
        assertEq(factory.owner(), address(this));
    }
}