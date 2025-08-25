// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {MarketFactory} from "../src/MarketFactory.sol";
import {Market} from "../src/Market.sol";
import {MarketAMM} from "../src/MarketAMM.sol";
import {OutcomeToken} from "../src/OutcomeToken.sol";
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

contract DeployAndTest is Script {
    MarketFactory public factory;
    MockERC20 public usdc;
    USDCFaucet public faucet;
    Market public market;
    MarketAMM public amm;
    OutcomeToken public yesToken;
    OutcomeToken public noToken;
    
    address public constant POSITION_READER = 0x0000000000000000000000000000000000000800;
    address public constant MARK_PX_READER = 0x0000000000000000000000000000000000000806;
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        address targetUser = vm.envAddress("TARGET_USER");
        uint32 perpId = uint32(vm.envUint("PERP_ID"));
        uint256 endTime = vm.envUint("END_TIME");
        
        console.log("=== DEPLOYMENT PHASE ===");
        console.log("Deployer:", deployer);
        console.log("Target User:", targetUser);
        console.log("Perp ID:", perpId);
        console.log("End Time:", endTime);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // 1. Deploy USDC
        usdc = new MockERC20("USD Coin", "USDC", 6, 0);
        console.log("USDC deployed at:", address(usdc));
        
        // 2. Deploy Faucet
        faucet = new USDCFaucet(address(usdc));
        console.log("Faucet deployed at:", address(faucet));
        
        // 3. USDC can be minted by anyone now (no ownership needed)
        console.log("USDC deployed with unrestricted minting");
        
        // 4. Deploy MarketFactory
        factory = new MarketFactory(deployer);
        console.log("MarketFactory deployed at:", address(factory));
        
        // 5. Get USDC from faucet
        console.log("\n=== GETTING INITIAL USDC ===");
        uint256 initialBalance = usdc.balanceOf(deployer);
        console.log("Initial USDC balance:", initialBalance);
        
        faucet.drip();
        uint256 afterFaucetBalance = usdc.balanceOf(deployer);
        console.log("USDC balance after faucet:", afterFaucetBalance);
        console.log("Received from faucet:", afterFaucetBalance - initialBalance);
        
        // 6. Create Market
        console.log("\n=== CREATING MARKET ===");
        address marketAddress = factory.createMarket(
            targetUser,
            perpId,
            endTime,
            address(usdc),
            POSITION_READER,
            MARK_PX_READER,
            "YES Token",
            "YES",
            "NO Token", 
            "NO"
        );
        
        market = Market(marketAddress);
        console.log("Market created at:", marketAddress);
        
        // Get market components
        address yesTokenAddr = market.yesToken();
        address noTokenAddr = market.noToken();
        address ammAddr = market.amm();
        
        yesToken = OutcomeToken(yesTokenAddr);
        noToken = OutcomeToken(noTokenAddr);
        amm = MarketAMM(ammAddr);
        
        console.log("YES Token:", yesTokenAddr);
        console.log("NO Token:", noTokenAddr);
        console.log("AMM:", ammAddr);
        
        // 7. Mint complete sets for liquidity
        console.log("\n=== MINTING COMPLETE SETS ===");
        uint256 mintAmount = 100 * 10**6; // 100 USDC
        console.log("Minting", mintAmount / 10**6, "USDC worth of complete sets");
        
        usdc.approve(marketAddress, mintAmount);
        market.mintCompleteSet(mintAmount);
        
        uint256 yesBalance = yesToken.balanceOf(deployer);
        uint256 noBalance = noToken.balanceOf(deployer);
        console.log("YES tokens minted:", yesBalance / 10**18);
        console.log("NO tokens minted:", noBalance / 10**18);
        
        // 8. Add liquidity to AMM
        console.log("\n=== ADDING LIQUIDITY TO AMM ===");
        uint256 liquidityAmount = 50 * 10**18; // 50 tokens each
        
        yesToken.approve(ammAddr, liquidityAmount);
        noToken.approve(ammAddr, liquidityAmount);
        
        uint256 lpTokens = amm.addLiquidity(liquidityAmount, liquidityAmount);
        console.log("LP tokens received:", lpTokens / 10**18);
        
        // Check AMM reserves
        uint256 yesReserve = amm.reserveA();
        uint256 noReserve = amm.reserveB();
        console.log("AMM YES reserve:", yesReserve / 10**18);
        console.log("AMM NO reserve:", noReserve / 10**18);
        
        // 9. Make some trades to generate fees
        console.log("\n=== MAKING TRADES TO GENERATE FEES ===");
        uint256 tradeAmount = 10 * 10**6; // 10 USDC
        
        // Get more USDC for trading
        faucet.drip();
        uint256 beforeTradeBalance = usdc.balanceOf(deployer);
        console.log("USDC balance before trades:", beforeTradeBalance / 10**6);
        
        // Buy YES tokens
        console.log("Buying YES tokens...");
        usdc.approve(marketAddress, tradeAmount);
        market.buyYesTokens(tradeAmount, 0);
        
        uint256 afterBuyYes = usdc.balanceOf(deployer);
        uint256 yesBalanceAfterBuy = yesToken.balanceOf(deployer);
        console.log("USDC spent:", (beforeTradeBalance - afterBuyYes) / 10**6);
        console.log("YES tokens received:", yesBalanceAfterBuy / 10**18);
        
        // Buy NO tokens
        console.log("Buying NO tokens...");
        usdc.approve(marketAddress, tradeAmount);
        market.buyNoTokens(tradeAmount, 0);
        
        uint256 afterBuyNo = usdc.balanceOf(deployer);
        uint256 noBalanceAfterBuy = noToken.balanceOf(deployer);
        console.log("USDC spent:", (afterBuyYes - afterBuyNo) / 10**6);
        console.log("NO tokens received:", noBalanceAfterBuy / 10**18);
        
        // 10. Check fee collection
        console.log("\n=== CHECKING FEE REVENUE ===");
        address feeRecipient = factory.feeRecipient();
        console.log("Fee recipient:", feeRecipient);
        
        uint256 feeRecipientYesBalance = yesToken.balanceOf(feeRecipient);
        uint256 feeRecipientNoBalance = noToken.balanceOf(feeRecipient);
        console.log("Fee recipient YES balance:", feeRecipientYesBalance / 10**18);
        console.log("Fee recipient NO balance:", feeRecipientNoBalance / 10**18);
        
        // 11. Check current PnL
        console.log("\n=== CHECKING CURRENT PNL ===");
        try market.snapshotPnl() returns (int256 pnl) {
            console.log("Current PnL:", pnl);
            console.logString(pnl > 0 ? "Position is PROFITABLE" : "Position is UNPROFITABLE");
        } catch Error(string memory reason) {
            console.log("PnL check failed:", reason);
        }
        
        // 12. Fast forward to settlement time (if possible in testnet)
        console.log("\n=== PREPARING FOR SETTLEMENT ===");
        console.log("Current time:", block.timestamp);
        console.log("End time:", endTime);
        
        if (block.timestamp >= endTime) {
            console.log("Market can be settled now");
            
            // Settle the market
            try market.settle() {
                console.log("Market settled successfully");
                
                // Check outcome
                uint8 outcome = uint8(market.outcome());
                console.log("Settlement outcome:", outcome);
                console.logString(outcome == 1 ? "PROFITABLE" : outcome == 2 ? "UNPROFITABLE" : "UNDECIDED");
                
                // Try to claim winnings
                uint256 winningTokenBalance;
                if (outcome == 1) { // Profitable
                    winningTokenBalance = yesToken.balanceOf(deployer);
                    console.log("Can claim with YES tokens:", winningTokenBalance / 10**18);
                    
                    if (winningTokenBalance > 0) {
                        uint256 beforeClaimUSDC = usdc.balanceOf(deployer);
                        market.claimWinnings(winningTokenBalance);
                        uint256 afterClaimUSDC = usdc.balanceOf(deployer);
                        console.log("USDC claimed:", (afterClaimUSDC - beforeClaimUSDC) / 10**6);
                    }
                } else if (outcome == 2) { // Unprofitable
                    winningTokenBalance = noToken.balanceOf(deployer);
                    console.log("Can claim with NO tokens:", winningTokenBalance / 10**18);
                    
                    if (winningTokenBalance > 0) {
                        uint256 beforeClaimUSDC = usdc.balanceOf(deployer);
                        market.claimWinnings(winningTokenBalance);
                        uint256 afterClaimUSDC = usdc.balanceOf(deployer);
                        console.log("USDC claimed:", (afterClaimUSDC - beforeClaimUSDC) / 10**6);
                    }
                }
            } catch Error(string memory reason) {
                console.log("Settlement failed:", reason);
            }
        } else {
            console.log("Market cannot be settled yet - need to wait until:", endTime);
            console.log("Time remaining:", endTime - block.timestamp, "seconds");
        }
        
        // 13. Final balances
        console.log("\n=== FINAL BALANCES ===");
        console.log("Deployer USDC:", usdc.balanceOf(deployer) / 10**6);
        console.log("Deployer YES:", yesToken.balanceOf(deployer) / 10**18);
        console.log("Deployer NO:", noToken.balanceOf(deployer) / 10**18);
        console.log("Deployer LP:", amm.lpShares(deployer) / 10**18);
        
        console.log("\nFee recipient YES:", yesToken.balanceOf(feeRecipient) / 10**18);
        console.log("Fee recipient NO:", noToken.balanceOf(feeRecipient) / 10**18);
        
        vm.stopBroadcast();
        
        console.log("\n=== DEPLOYMENT COMPLETE ===");
        console.log("MarketFactory:", address(factory));
        console.log("USDC:", address(usdc));
        console.log("Faucet:", address(faucet));
        console.log("Market:", address(market));
        console.log("AMM:", address(amm));
    }
}