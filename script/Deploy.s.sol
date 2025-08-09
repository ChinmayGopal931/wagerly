// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/PnlBet.sol";
import "../src/BetFactory.sol";

contract DeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy the logic contract first (with real Hyperliquid precompile addresses)
        PnlBet pnlBetLogic = new PnlBet(address(0), address(0));
        console.log("PnlBet Logic deployed at:", address(pnlBetLogic));
        
        // Deploy the factory with the logic contract address
        BetFactory factory = new BetFactory(address(pnlBetLogic));
        console.log("BetFactory deployed at:", address(factory));
        
        vm.stopBroadcast();
        
        // Log deployment info
        console.log("=== Hyperliquid Deployment Summary ===");
        console.log("PnlBet Logic:", address(pnlBetLogic));
        console.log("BetFactory:", address(factory));
        console.log("Deployer:", vm.addr(deployerPrivateKey));
        console.log("Network: Hyperliquid EVM");
    }
}