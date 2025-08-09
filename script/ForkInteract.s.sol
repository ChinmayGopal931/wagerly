// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/BetFactory.sol";
import "../src/PnlBet.sol";

contract ForkInteractScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address factoryAddress = vm.envAddress("FACTORY_ADDRESS");
        
        // Example target user and perp ID - replace with real values
        address targetUser = vm.envOr("TARGET_USER", address(0x1234567890123456789012345678901234567890));
        uint32 perpId = uint32(vm.envOr("PERP_ID", uint256(1))); // BTC = 1
        uint256 duration = vm.envOr("DURATION", uint256(3600)); // 1 hour
        
        console.log("=== FORK TESTING INTERACTION ===");
        console.log("Factory Address:", factoryAddress);
        console.log("Target User:", targetUser);
        console.log("Perp ID:", perpId);
        console.log("Duration:", duration, "seconds");
        console.log("");
        
        vm.startBroadcast(deployerPrivateKey);
        
        BetFactory factory = BetFactory(factoryAddress);
        
        // Create a new bet
        console.log("Creating bet...");
        address newBetAddress = factory.createBet(targetUser, perpId, duration);
        console.log("New bet created at:", newBetAddress);
        
        // Place a bet on profitable outcome
        PnlBet bet = PnlBet(newBetAddress);
        uint256 betAmount = 1 ether;
        console.log("Placing bet of", betAmount, "wei on PROFITABLE outcome...");
        bet.placeBet{value: betAmount}(true);
        
        vm.stopBroadcast();
        
        // Display bet info
        console.log("\n=== BET DETAILS ===");
        console.log("Bet Contract:", newBetAddress);
        console.log("Target User:", bet.targetUser());
        console.log("Perp ID:", bet.perpId());
        console.log("End Time:", bet.endTime());
        console.log("Current Time:", block.timestamp);
        console.log("Profitable Pool:", bet.profitablePoolBalance());
        console.log("Unprofitable Pool:", bet.unprofitablePoolBalance());
        console.log("Is Settled:", bet.isSettled());
        
        console.log("\n=== NEXT STEPS ===");
        console.log("1. Wait for end time or fast-forward with:");
        console.log("   cast rpc anvil_increaseTime", duration + 1);
        console.log("2. Settle the bet:");
        console.log("   cast send", newBetAddress, '"settle()" --rpc-url http://127.0.0.1:8545 --private-key', vm.envUint("PRIVATE_KEY"));
        console.log("3. Claim winnings:");
        console.log("   cast send", newBetAddress, '"claimWinnings()" --rpc-url http://127.0.0.1:8545 --private-key', vm.envUint("PRIVATE_KEY"));
    }
}