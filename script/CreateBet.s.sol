// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/BetFactory.sol";
import "../src/PnlBet.sol";

contract CreateBetScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address factoryAddress = vm.envAddress("FACTORY_ADDRESS");
        address targetUser = vm.envAddress("TARGET_USER");
        uint32 perpId = uint32(vm.envUint("PERP_ID"));
        uint256 duration = vm.envUint("DURATION"); // in seconds
        
        vm.startBroadcast(deployerPrivateKey);
        
        BetFactory factory = BetFactory(factoryAddress);
        
        // Create a new bet
        address newBetAddress = factory.createBet(targetUser, perpId, duration);
        
        vm.stopBroadcast();
        
        console.log("=== New Bet Created ===");
        console.log("Bet Address:", newBetAddress);
        console.log("Target User:", targetUser);
        console.log("Perp ID:", perpId);
        console.log("Duration:", duration, "seconds");
        console.log("End Time:", block.timestamp + duration);
        
        // Display bet info
        PnlBet bet = PnlBet(newBetAddress);
        console.log("\n=== Bet Details ===");
        console.log("Target User:", bet.targetUser());
        console.log("Perp ID:", bet.perpId());
        console.log("End Time:", bet.endTime());
        console.log("Is Settled:", bet.isSettled());
    }
}