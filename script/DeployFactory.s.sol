// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {MarketFactory} from "../src/MarketFactory.sol";
import {MockERC20} from "../test/mocks/MockERC20.sol";

contract USDCFaucet {
    MockERC20 public immutable usdc;
    uint256 public constant FAUCET_AMOUNT = 1000 * 10**6; // 1000 USDC (6 decimals)
    
    mapping(address => uint256) public lastClaim;
    
    event FaucetDrip(address indexed user, uint256 amount);
    
    constructor(address _usdc) {
        usdc = MockERC20(_usdc);
    }
    
    function drip() external {
    
        lastClaim[msg.sender] = block.timestamp;
        usdc.mint(msg.sender, FAUCET_AMOUNT);
        
        emit FaucetDrip(msg.sender, FAUCET_AMOUNT);
    }
}

contract DeployFactory is Script {
    function run() external returns (
        address marketFactory,
        address usdc,
        address faucet
    ) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
    
        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy USDC with faucet capability
        MockERC20 usdcToken = new MockERC20("USD Coin", "USDC", 6, 0);
        usdc = address(usdcToken);
        console.log("USDC deployed at:", usdc);
        
        // 2. Deploy USDC Faucet
        USDCFaucet usdcFaucet = new USDCFaucet(usdc);
        faucet = address(usdcFaucet);
        console.log("USDC Faucet deployed at:", faucet);
        
        // 2.1. USDC now allows unrestricted minting (no ownership needed)
        console.log("USDC deployed with unrestricted minting");

        // 3. Deploy MarketFactory with feeRecipient and USDC address
        MarketFactory factory = new MarketFactory(msg.sender, usdc);
        marketFactory = address(factory);
        console.log("MarketFactory deployed at:", marketFactory);

        vm.stopBroadcast();
        
        console.log("\n=== Frontend Integration ===");
        console.log("MarketFactory Address:", marketFactory);
        console.log("USDC Address:", usdc);
        console.log("Faucet Address:", faucet);
        console.log("\nCall drip() on faucet to get 1000 USDC");

        return (marketFactory, usdc, faucet);
    }
}