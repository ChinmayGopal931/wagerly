// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../../src/PnlBet.sol";
import "../../src/BetFactory.sol";

/// @title Fork Integration Tests
/// @notice Tests that run against live Hyperliquid mainnet data via forking
/// @dev Run with: forge test --match-contract ForkTest --fork-url https://rpc.hyperliquid.xyz/evm
contract ForkTest is Test {
    BetFactory public factory;
    PnlBet public pnlBetLogic;
    
    address public alice = address(0x1);
    address public bob = address(0x2);
    
    // Example addresses - replace with real active traders
    address public constant EXAMPLE_TRADER = 0x0000000000000000000000000000000000000001;
    uint32 public constant BTC_PERP_ID = 1;
    uint32 public constant ETH_PERP_ID = 2;
    
    uint256 public constant TEST_DURATION = 1 hours;
    
    function setUp() public {
        // Deploy with real precompile addresses (address(0) = use defaults)
        pnlBetLogic = new PnlBet(address(0), address(0));
        factory = new BetFactory(address(pnlBetLogic));
        
        // Fund test accounts
        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);
    }
    
    function testForkBetCreation() public {
        vm.startPrank(alice);
        
        // Create a bet on a live trader's BTC position
        address betAddress = factory.createBet(EXAMPLE_TRADER, BTC_PERP_ID, TEST_DURATION);
        
        PnlBet bet = PnlBet(betAddress);
        
        // Verify bet was created correctly
        assertEq(bet.targetUser(), EXAMPLE_TRADER);
        assertEq(bet.perpId(), BTC_PERP_ID);
        assertEq(bet.endTime(), block.timestamp + TEST_DURATION);
        assertEq(uint(bet.outcome()), uint(PnlBet.Outcome.Undecided));
        assertFalse(bet.isSettled());
        
        vm.stopPrank();
    }
    
    function testForkBettingAndSettlement() public {
        // Create bet
        vm.startPrank(alice);
        address betAddress = factory.createBet(EXAMPLE_TRADER, BTC_PERP_ID, TEST_DURATION);
        PnlBet bet = PnlBet(betAddress);
        
        // Alice bets on profitable outcome
        bet.placeBet{value: 2 ether}(true);
        vm.stopPrank();
        
        // Bob bets on unprofitable outcome  
        vm.startPrank(bob);
        bet.placeBet{value: 3 ether}(false);
        vm.stopPrank();
        
        // Verify pool balances
        assertEq(bet.profitablePoolBalance(), 2 ether);
        assertEq(bet.unprofitablePoolBalance(), 3 ether);
        assertEq(bet.getTotalPool(), 5 ether);
        
        // Fast forward time
        vm.warp(block.timestamp + TEST_DURATION + 1);
        
        // Settle bet - this calls LIVE Hyperliquid precompiles!
        bet.settle();
        
        // Verify settlement occurred
        assertTrue(bet.isSettled());
        assertTrue(uint(bet.outcome()) != uint(PnlBet.Outcome.Undecided));
        
        // Test claiming (outcome depends on live data)
        PnlBet.Outcome outcome = bet.outcome();
        
        if (outcome == PnlBet.Outcome.Profitable) {
            // Alice should be able to claim
            uint256 aliceBalanceBefore = alice.balance;
            vm.prank(alice);
            bet.claimWinnings();
            assertGt(alice.balance, aliceBalanceBefore);
        } else {
            // Bob should be able to claim
            uint256 bobBalanceBefore = bob.balance;
            vm.prank(bob);
            bet.claimWinnings();
            assertGt(bob.balance, bobBalanceBefore);
        }
    }
    
    function testForkMultipleAssets() public {
        vm.startPrank(alice);
        
        // Create bets on different assets
        address btcBet = factory.createBet(EXAMPLE_TRADER, BTC_PERP_ID, TEST_DURATION);
        address ethBet = factory.createBet(EXAMPLE_TRADER, ETH_PERP_ID, TEST_DURATION);
        
        // Verify they're different contracts
        assertTrue(btcBet != ethBet);
        
        PnlBet btcContract = PnlBet(btcBet);
        PnlBet ethContract = PnlBet(ethBet);
        
        // Verify they track different assets
        assertEq(btcContract.perpId(), BTC_PERP_ID);
        assertEq(ethContract.perpId(), ETH_PERP_ID);
        assertEq(btcContract.targetUser(), EXAMPLE_TRADER);
        assertEq(ethContract.targetUser(), EXAMPLE_TRADER);
        
        vm.stopPrank();
    }
    
    function testForkPrecompileReads() public {
        // This test verifies we can actually read from Hyperliquid precompiles
        vm.startPrank(alice);
        
        address betAddress = factory.createBet(EXAMPLE_TRADER, BTC_PERP_ID, TEST_DURATION);
        PnlBet bet = PnlBet(betAddress);
        
        // Place a bet to create some state
        bet.placeBet{value: 1 ether}(true);
        
        vm.stopPrank();
        
        // Fast forward and settle
        vm.warp(block.timestamp + TEST_DURATION + 1);
        
        // This will call the precompiles - should not revert on a proper fork
        bet.settle();
        
        // If we get here without reverting, precompile calls worked!
        assertTrue(bet.isSettled());
        
        // Log the outcome for inspection
        PnlBet.Outcome outcome = bet.outcome();
        if (outcome == PnlBet.Outcome.Profitable) {
            console.log("Live position shows PROFIT");
        } else {
            console.log("Live position shows LOSS");
        }
    }
    
    /// @dev Helper function to log fork test results
    function logForkTestResults(address betAddress) internal view {
        PnlBet bet = PnlBet(betAddress);
        
        console.log("=== FORK TEST RESULTS ===");
        console.log("Bet Address:", betAddress);
        console.log("Target User:", bet.targetUser());
        console.log("Perp ID:", bet.perpId());
        console.log("Is Settled:", bet.isSettled());
        console.log("Outcome:", uint(bet.outcome()));
        console.log("Total Pool:", bet.getTotalPool());
        console.log("Block Time:", block.timestamp);
    }
}