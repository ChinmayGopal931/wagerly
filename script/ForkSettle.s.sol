// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/PnlBet.sol";

contract ForkSettleScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address betAddress = vm.envAddress("BET_ADDRESS");
        
        console.log("=== SETTLING BET ===");
        console.log("Bet Address:", betAddress);
        
        PnlBet bet = PnlBet(betAddress);
        
        // Check if bet can be settled
        console.log("Current Time:", block.timestamp);
        console.log("End Time:", bet.endTime());
        console.log("Is Settled:", bet.isSettled());
        console.log("Can Settle:", block.timestamp >= bet.endTime() && !bet.isSettled());
        
        if (block.timestamp < bet.endTime()) {
            console.log("ERROR: Cannot settle yet. End time not reached.");
            console.log("Fast-forward time with: cast rpc anvil_increaseTime", bet.endTime() - block.timestamp + 1);
            return;
        }
        
        if (bet.isSettled()) {
            console.log("ERROR: Bet is already settled.");
            _displaySettledInfo(bet);
            return;
        }
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Settle the bet - this will call live Hyperliquid precompiles!
        console.log("Settling bet with live Hyperliquid data...");
        bet.settle();
        
        vm.stopBroadcast();
        
        // Display results
        _displaySettledInfo(bet);
        
        console.log("\n=== CLAIM WINNINGS ===");
        console.log("Use this command to claim:");
        console.log("cast send", betAddress, '"claimWinnings()" --rpc-url http://127.0.0.1:8545 --private-key', vm.envUint("PRIVATE_KEY"));
    }
    
    function _displaySettledInfo(PnlBet bet) internal view {
        console.log("\n=== SETTLEMENT RESULTS ===");
        console.log("Target User:", bet.targetUser());
        console.log("Perp ID:", bet.perpId());
        console.log("Outcome:", _outcomeToString(bet.outcome()));
        console.log("Profitable Pool:", bet.profitablePoolBalance());
        console.log("Unprofitable Pool:", bet.unprofitablePoolBalance());
        console.log("Total Pool:", bet.getTotalPool());
        console.log("Is Settled:", bet.isSettled());
    }
    
    function _outcomeToString(PnlBet.Outcome outcome) internal pure returns (string memory) {
        if (outcome == PnlBet.Outcome.Undecided) return "Undecided";
        if (outcome == PnlBet.Outcome.Profitable) return "Profitable";
        if (outcome == PnlBet.Outcome.Unprofitable) return "Unprofitable";
        return "Unknown";
    }
}