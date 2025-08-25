# Frontend Integration Guide

## Overview

This document provides a complete guide for integrating the prediction market protocol on Hyperliquid testnet with your frontend application.

## Contract Addresses

### Shared Infrastructure (Deploy Once, Use Forever)
- **USDC Token**: `0x8ebb1ff334892c2cbe65c78aaeb574371e102186` 
- **USDC Faucet**: `0x0f2290efd37505a17572e288728c3137199aa557`
- **MarketFactory**: `0xf83ff2dee93c0131901f5d102657f903e37c6856`

> **Note**: These addresses are shared across ALL markets. Only deploy new Market contracts for each prediction market, not new USDC/Faucet contracts.

### Network Details
- **Network**: Hyperliquid Testnet
- **RPC URL**: `https://rpc.hyperliquid-testnet.xyz/evm`
- **Chain ID**: 998

### Hyperliquid Precompiles
- **Position Reader**: `0x0000000000000000000000000000000000000800`
- **Mark Price Reader**: `0x0000000000000000000000000000000000000806`

## Contract ABIs

### 1. MarketFactory ABI

```json
{
  "abi": [
    {
      "type": "constructor",
      "inputs": [{"name": "_feeRecipient", "type": "address", "internalType": "address"}],
      "stateMutability": "nonpayable"
    },
    {
      "type": "function",
      "name": "createMarket",
      "inputs": [
        {"name": "_targetUser", "type": "address", "internalType": "address"},
        {"name": "_perpId", "type": "uint32", "internalType": "uint32"},
        {"name": "_endTime", "type": "uint256", "internalType": "uint256"},
        {"name": "_usdcTokenAddress", "type": "address", "internalType": "address"},
        {"name": "_positionReader", "type": "address", "internalType": "address"},
        {"name": "_markPxReader", "type": "address", "internalType": "address"},
        {"name": "_yesTokenName", "type": "string", "internalType": "string"},
        {"name": "_yesTokenSymbol", "type": "string", "internalType": "string"},
        {"name": "_noTokenName", "type": "string", "internalType": "string"},
        {"name": "_noTokenSymbol", "type": "string", "internalType": "string"}
      ],
      "outputs": [{"name": "", "type": "address", "internalType": "address"}],
      "stateMutability": "nonpayable"
    },
    {
      "type": "function",
      "name": "allMarkets",
      "inputs": [{"name": "", "type": "uint256", "internalType": "uint256"}],
      "outputs": [{"name": "", "type": "address", "internalType": "address"}],
      "stateMutability": "view"
    },
    {
      "type": "function",
      "name": "feeRecipient",
      "inputs": [],
      "outputs": [{"name": "", "type": "address", "internalType": "address"}],
      "stateMutability": "view"
    },
    {
      "type": "event",
      "name": "MarketCreated",
      "inputs": [
        {"name": "marketAddress", "type": "address", "indexed": true},
        {"name": "creator", "type": "address", "indexed": true},
        {"name": "targetUser", "type": "address", "indexed": false},
        {"name": "perpId", "type": "uint32", "indexed": false},
        {"name": "yesToken", "type": "address", "indexed": false},
        {"name": "noToken", "type": "address", "indexed": false},
        {"name": "amm", "type": "address", "indexed": false}
      ]
    }
  ]
}
```

### 2. Market ABI

```json
{
  "abi": [
    {
      "type": "function",
      "name": "mintCompleteSet",
      "inputs": [{"name": "usdcAmount", "type": "uint256", "internalType": "uint256"}],
      "outputs": [],
      "stateMutability": "nonpayable"
    },
    {
      "type": "function",
      "name": "redeemCompleteSet",
      "inputs": [{"name": "amount", "type": "uint256", "internalType": "uint256"}],
      "outputs": [],
      "stateMutability": "nonpayable"
    },
    {
      "type": "function",
      "name": "buyYesTokens",
      "inputs": [
        {"name": "usdcAmountToSpend", "type": "uint256", "internalType": "uint256"},
        {"name": "minYesTokensToReceive", "type": "uint256", "internalType": "uint256"}
      ],
      "outputs": [],
      "stateMutability": "nonpayable"
    },
    {
      "type": "function",
      "name": "buyNoTokens",
      "inputs": [
        {"name": "usdcAmountToSpend", "type": "uint256", "internalType": "uint256"},
        {"name": "minNoTokensToReceive", "type": "uint256", "internalType": "uint256"}
      ],
      "outputs": [],
      "stateMutability": "nonpayable"
    },
    {
      "type": "function",
      "name": "snapshotPnl",
      "inputs": [],
      "outputs": [{"name": "", "type": "int256", "internalType": "int256"}],
      "stateMutability": "nonpayable"
    },
    {
      "type": "function",
      "name": "settle",
      "inputs": [],
      "outputs": [],
      "stateMutability": "nonpayable"
    },
    {
      "type": "function",
      "name": "claimWinnings",
      "inputs": [{"name": "amount", "type": "uint256", "internalType": "uint256"}],
      "outputs": [],
      "stateMutability": "nonpayable"
    },
    {
      "type": "function",
      "name": "yesToken",
      "inputs": [],
      "outputs": [{"name": "", "type": "address", "internalType": "address"}],
      "stateMutability": "view"
    },
    {
      "type": "function",
      "name": "noToken",
      "inputs": [],
      "outputs": [{"name": "", "type": "address", "internalType": "address"}],
      "stateMutability": "view"
    },
    {
      "type": "function",
      "name": "amm",
      "inputs": [],
      "outputs": [{"name": "", "type": "address", "internalType": "address"}],
      "stateMutability": "view"
    },
    {
      "type": "function",
      "name": "outcome",
      "inputs": [],
      "outputs": [{"name": "", "type": "uint8", "internalType": "enum Market.Outcome"}],
      "stateMutability": "view"
    },
    {
      "type": "function",
      "name": "isSettled",
      "inputs": [],
      "outputs": [{"name": "", "type": "bool", "internalType": "bool"}],
      "stateMutability": "view"
    },
    {
      "type": "function",
      "name": "endTime",
      "inputs": [],
      "outputs": [{"name": "", "type": "uint256", "internalType": "uint256"}],
      "stateMutability": "view"
    }
  ]
}
```

### 3. MarketAMM ABI

```json
{
  "abi": [
    {
      "type": "function",
      "name": "addLiquidity",
      "inputs": [
        {"name": "amountA", "type": "uint256", "internalType": "uint256"},
        {"name": "amountB", "type": "uint256", "internalType": "uint256"}
      ],
      "outputs": [{"name": "", "type": "uint256", "internalType": "uint256"}],
      "stateMutability": "nonpayable"
    },
    {
      "type": "function",
      "name": "swap",
      "inputs": [
        {"name": "tokenIn", "type": "address", "internalType": "address"},
        {"name": "amountIn", "type": "uint256", "internalType": "uint256"},
        {"name": "minAmountOut", "type": "uint256", "internalType": "uint256"},
        {"name": "recipient", "type": "address", "internalType": "address"}
      ],
      "outputs": [{"name": "", "type": "uint256", "internalType": "uint256"}],
      "stateMutability": "nonpayable"
    },
    {
      "type": "function",
      "name": "reserveA",
      "inputs": [],
      "outputs": [{"name": "", "type": "uint256", "internalType": "uint256"}],
      "stateMutability": "view"
    },
    {
      "type": "function",
      "name": "reserveB",
      "inputs": [],
      "outputs": [{"name": "", "type": "uint256", "internalType": "uint256"}],
      "stateMutability": "view"
    },
    {
      "type": "function",
      "name": "lpShares",
      "inputs": [{"name": "user", "type": "address", "internalType": "address"}],
      "outputs": [{"name": "", "type": "uint256", "internalType": "uint256"}],
      "stateMutability": "view"
    },
    {
      "type": "function",
      "name": "totalLpShares",
      "inputs": [],
      "outputs": [{"name": "", "type": "uint256", "internalType": "uint256"}],
      "stateMutability": "view"
    }
  ]
}
```

### 4. USDC Token ABI

```json
{
  "abi": [
    {
      "type": "function",
      "name": "balanceOf",
      "inputs": [{"name": "account", "type": "address", "internalType": "address"}],
      "outputs": [{"name": "", "type": "uint256", "internalType": "uint256"}],
      "stateMutability": "view"
    },
    {
      "type": "function",
      "name": "approve",
      "inputs": [
        {"name": "spender", "type": "address", "internalType": "address"},
        {"name": "amount", "type": "uint256", "internalType": "uint256"}
      ],
      "outputs": [{"name": "", "type": "bool", "internalType": "bool"}],
      "stateMutability": "nonpayable"
    },
    {
      "type": "function",
      "name": "allowance",
      "inputs": [
        {"name": "owner", "type": "address", "internalType": "address"},
        {"name": "spender", "type": "address", "internalType": "address"}
      ],
      "outputs": [{"name": "", "type": "uint256", "internalType": "uint256"}],
      "stateMutability": "view"
    },
    {
      "type": "function",
      "name": "decimals",
      "inputs": [],
      "outputs": [{"name": "", "type": "uint8", "internalType": "uint8"}],
      "stateMutability": "view"
    }
  ]
}
```

### 5. USDC Faucet ABI

```json
{
  "abi": [
    {
      "type": "function",
      "name": "drip",
      "inputs": [],
      "outputs": [],
      "stateMutability": "nonpayable"
    },
    {
      "type": "function",
      "name": "lastClaim",
      "inputs": [{"name": "user", "type": "address", "internalType": "address"}],
      "outputs": [{"name": "", "type": "uint256", "internalType": "uint256"}],
      "stateMutability": "view"
    },
    {
      "type": "function",
      "name": "FAUCET_AMOUNT",
      "inputs": [],
      "outputs": [{"name": "", "type": "uint256", "internalType": "uint256"}],
      "stateMutability": "view"
    }
  ]
}
```

## Integration Flows

### 1. Getting USDC from Faucet

```javascript
// Get 1000 USDC from faucet (no cooldown in current implementation)
// This is the SAME faucet used by ALL markets - no need to deploy new ones
async function getFaucetUSDC(signer) {
  const faucetAddress = "0x0f2290efd37505a17572e288728c3137199aa557"; // Shared faucet
  const faucet = new ethers.Contract(faucetAddress, faucetAbi, signer);
  
  const tx = await faucet.drip();
  await tx.wait();
  
  console.log("Received 1000 USDC from shared faucet");
}
```

### 2. Creating a New Market

```javascript
async function createMarket(signer, targetUser, perpId, endTime) {
  const factoryAddress = "0xf83ff2dee93c0131901f5d102657f903e37c6856";
  const usdcAddress = "0x8ebb1ff334892c2cbe65c78aaeb574371e102186"; // Shared USDC token
  const positionReader = "0x0000000000000000000000000000000000000800";
  const markPxReader = "0x0000000000000000000000000000000000000806";
  
  const factory = new ethers.Contract(factoryAddress, marketFactoryAbi, signer);
  
  const tx = await factory.createMarket(
    targetUser,           // Address with the position to track
    perpId,              // Perpetual ID (e.g., 3 for BTC)
    endTime,             // Unix timestamp when market expires
    usdcAddress,         // USDC token address
    positionReader,      // Hyperliquid position precompile
    markPxReader,        // Hyperliquid mark price precompile
    "Will be Profitable", // YES token name
    "PROFIT",            // YES token symbol
    "Will be Unprofitable", // NO token name
    "LOSS"               // NO token symbol
  );
  
  const receipt = await tx.wait();
  
  // Get market address from event
  const marketCreatedEvent = receipt.events?.find(e => e.event === 'MarketCreated');
  const marketAddress = marketCreatedEvent.args.marketAddress;
  
  return {
    marketAddress,
    yesToken: marketCreatedEvent.args.yesToken,
    noToken: marketCreatedEvent.args.noToken,
    amm: marketCreatedEvent.args.amm
  };
}
```

### 3. Minting Complete Sets (Adding Liquidity Base)

```javascript
async function mintCompleteSet(signer, marketAddress, usdcAmount) {
  const market = new ethers.Contract(marketAddress, marketAbi, signer);
  const usdcAddress = "0x8ebb1ff334892c2cbe65c78aaeb574371e102186"; // Shared USDC
  const usdc = new ethers.Contract(usdcAddress, usdcAbi, signer);
  
  // First approve USDC spending
  const approveTx = await usdc.approve(marketAddress, usdcAmount);
  await approveTx.wait();
  
  // Mint complete set (equal YES and NO tokens)
  const mintTx = await market.mintCompleteSet(usdcAmount);
  await mintTx.wait();
  
  console.log(`Minted ${usdcAmount / 1e6} USDC worth of YES/NO token pairs`);
}
```

### 4. Adding Liquidity to AMM

```javascript
async function addLiquidity(signer, marketAddress, yesAmount, noAmount) {
  const market = new ethers.Contract(marketAddress, marketAbi, signer);
  const ammAddress = await market.amm();
  const yesTokenAddress = await market.yesToken();
  const noTokenAddress = await market.noToken();
  
  const amm = new ethers.Contract(ammAddress, ammAbi, signer);
  const yesToken = new ethers.Contract(yesTokenAddress, usdcAbi, signer); // ERC20 ABI
  const noToken = new ethers.Contract(noTokenAddress, usdcAbi, signer);
  
  // Approve tokens
  await yesToken.approve(ammAddress, yesAmount);
  await noToken.approve(ammAddress, noAmount);
  
  // Add liquidity
  const tx = await amm.addLiquidity(yesAmount, noAmount);
  const receipt = await tx.wait();
  
  console.log("Liquidity added successfully");
  return receipt;
}
```

### 5. Buying YES Tokens

```javascript
async function buyYesTokens(signer, marketAddress, usdcAmount, minYesTokens = 0) {
  const market = new ethers.Contract(marketAddress, marketAbi, signer);
  const usdcAddress = "0x8ebb1ff334892c2cbe65c78aaeb574371e102186"; // Shared USDC
  const usdc = new ethers.Contract(usdcAddress, usdcAbi, signer);
  
  // Approve USDC
  await usdc.approve(marketAddress, usdcAmount);
  
  // Buy YES tokens
  const tx = await market.buyYesTokens(usdcAmount, minYesTokens);
  await tx.wait();
  
  console.log(`Bought YES tokens with ${usdcAmount / 1e6} USDC`);
}
```

### 6. Buying NO Tokens

```javascript
async function buyNoTokens(signer, marketAddress, usdcAmount, minNoTokens = 0) {
  const market = new ethers.Contract(marketAddress, marketAbi, signer);
  const usdcAddress = "0x8ebb1ff334892c2cbe65c78aaeb574371e102186"; // Shared USDC
  const usdc = new ethers.Contract(usdcAddress, usdcAbi, signer);
  
  // Approve USDC
  await usdc.approve(marketAddress, usdcAmount);
  
  // Buy NO tokens
  const tx = await market.buyNoTokens(usdcAmount, minNoTokens);
  await tx.wait();
  
  console.log(`Bought NO tokens with ${usdcAmount / 1e6} USDC`);
}
```

### 7. Checking Current PnL

```javascript
async function getCurrentPnL(provider, marketAddress) {
  const market = new ethers.Contract(marketAddress, marketAbi, provider);
  
  try {
    const pnl = await market.snapshotPnl();
    const pnlValue = ethers.BigNumber.from(pnl).toNumber();
    
    // Convert from 8-decimal format to readable number
    const readablePnL = pnlValue / 1e8;
    
    return {
      rawPnL: pnl,
      readablePnL: readablePnL,
      isProfitable: pnlValue > 0
    };
  } catch (error) {
    console.error("Error getting PnL:", error);
    throw error;
  }
}
```

### 8. Market Settlement

```javascript
async function settleMarket(signer, marketAddress) {
  const market = new ethers.Contract(marketAddress, marketAbi, signer);
  
  // Check if market can be settled
  const endTime = await market.endTime();
  const currentTime = Math.floor(Date.now() / 1000);
  
  if (currentTime < endTime) {
    throw new Error(`Market can only be settled after ${new Date(endTime * 1000)}`);
  }
  
  // Settle the market
  const tx = await market.settle();
  await tx.wait();
  
  // Get the outcome
  const outcome = await market.outcome();
  const outcomeText = outcome === 1 ? "PROFITABLE" : outcome === 2 ? "UNPROFITABLE" : "UNDECIDED";
  
  return {
    outcome: outcome,
    outcomeText: outcomeText,
    isSettled: true
  };
}
```

### 9. Claiming Winnings

```javascript
async function claimWinnings(signer, marketAddress, tokenAmount) {
  const market = new ethers.Contract(marketAddress, marketAbi, signer);
  
  // Check if market is settled
  const isSettled = await market.isSettled();
  if (!isSettled) {
    throw new Error("Market must be settled before claiming winnings");
  }
  
  const outcome = await market.outcome();
  
  // Claim winnings with the appropriate tokens
  const tx = await market.claimWinnings(tokenAmount);
  await tx.wait();
  
  const outcomeText = outcome === 1 ? "YES" : "NO";
  console.log(`Claimed winnings with ${outcomeText} tokens`);
}
```

## Helper Functions

### Get Market Details

```javascript
async function getMarketDetails(provider, marketAddress) {
  const market = new ethers.Contract(marketAddress, marketAbi, provider);
  
  const [yesToken, noToken, amm, endTime, isSettled, outcome] = await Promise.all([
    market.yesToken(),
    market.noToken(),
    market.amm(),
    market.endTime(),
    market.isSettled(),
    market.outcome()
  ]);
  
  return {
    marketAddress,
    yesToken,
    noToken,
    amm,
    endTime: new Date(endTime * 1000),
    isSettled,
    outcome,
    outcomeText: outcome === 1 ? "PROFITABLE" : outcome === 2 ? "UNPROFITABLE" : "UNDECIDED"
  };
}
```

### Get User Balances

```javascript
async function getUserBalances(provider, userAddress, marketAddress) {
  const market = new ethers.Contract(marketAddress, marketAbi, provider);
  const yesTokenAddress = await market.yesToken();
  const noTokenAddress = await market.noToken();
  const ammAddress = await market.amm();
  
  const yesToken = new ethers.Contract(yesTokenAddress, usdcAbi, provider);
  const noToken = new ethers.Contract(noTokenAddress, usdcAbi, provider);
  const amm = new ethers.Contract(ammAddress, ammAbi, provider);
  
  const [yesBalance, noBalance, lpBalance] = await Promise.all([
    yesToken.balanceOf(userAddress),
    noToken.balanceOf(userAddress),
    amm.lpShares(userAddress)
  ]);
  
  return {
    yesTokens: ethers.utils.formatEther(yesBalance),
    noTokens: ethers.utils.formatEther(noBalance),
    lpTokens: ethers.utils.formatEther(lpBalance)
  };
}
```

### Get AMM Reserves

```javascript
async function getAMMReserves(provider, ammAddress) {
  const amm = new ethers.Contract(ammAddress, ammAbi, provider);
  
  const [reserveA, reserveB, totalShares] = await Promise.all([
    amm.reserveA(),
    amm.reserveB(),
    amm.totalLpShares()
  ]);
  
  return {
    yesReserve: ethers.utils.formatEther(reserveA),
    noReserve: ethers.utils.formatEther(reserveB),
    totalLPShares: ethers.utils.formatEther(totalShares)
  };
}
```

## Deployment Guide

### Shared Infrastructure (Already Deployed)

The following contracts are **already deployed** and should be used by all markets:

- **USDC Token**: `0x8ebb1ff334892c2cbe65c78aaeb574371e102186`
- **USDC Faucet**: `0x0f2290efd37505a17572e288728c3137199aa557`  
- **MarketFactory**: `0xf83ff2dee93c0131901f5d102657f903e37c6856`

### Creating New Markets (Recommended Approach)

**Just use the existing factory to create new markets:**

```javascript
// Frontend approach - recommended
const marketAddress = await createMarket(
  signer,
  "0xTargetUserAddress",  // User whose position to track
  3,                      // PerpId (e.g., 3 for BTC)
  Math.floor(Date.now() / 1000) + 86400  // End time (24 hours from now)
);
```

### Manual Market Creation (Via Cast)

```bash
# Create a new market using the existing factory
export PRIVATE_KEY=0xyourkey
export RPC_URL=https://rpc.hyperliquid-testnet.xyz/evm

cast send 0xf83ff2dee93c0131901f5d102657f903e37c6856 \
  "createMarket(address,uint32,uint256,address,address,address,string,string,string,string)" \
  0xTargetUserAddress \
  3 \
  1767225600 \
  0x8ebb1ff334892c2cbe65c78aaeb574371e102186 \
  0x0000000000000000000000000000000000000800 \
  0x0000000000000000000000000000000000000806 \
  "Will be Profitable" \
  "PROFIT" \
  "Will be Unprofitable" \
  "LOSS" \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY
```

### Only Deploy New Infrastructure If Needed

**Only deploy new USDC/Faucet/Factory if you want a separate instance:**

```bash
# Deploy new factory (fee recipient will be deployer address)
forge create src/MarketFactory.sol:MarketFactory \
  --constructor-args $(cast wallet address --private-key $PRIVATE_KEY) \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY

# Deploy new USDC (optional)
forge create test/mocks/MockERC20.sol:MockERC20 \
  --constructor-args "USD Coin" "USDC" 6 0 \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY

# Deploy new Faucet (optional)
forge create script/DeployFactory.s.sol:USDCFaucet \
  --constructor-args USDC_ADDRESS \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY
```

## Important Constants

```javascript
const USDC_DECIMALS = 6;
const OUTCOME_TOKEN_DECIMALS = 18;
const PROTOCOL_FEE_BPS = 50; // 0.5%
const LP_FEE_BPS = 30; // 0.3%
const FAUCET_AMOUNT = 1000 * 1e6; // 1000 USDC

// Outcome enum values
const OUTCOME = {
  UNDECIDED: 0,
  PROFITABLE: 1,
  UNPROFITABLE: 2
};
```

## Error Handling

Common errors to handle:

- `"No position to commit to"` - Target user has no position on the specified perpId
- `"Position call failed"` - Hyperliquid precompile call failed
- `"InsufficientOutput"` - Slippage protection triggered during swaps
- `"NotSettled"` - Trying to claim winnings before settlement
- `"AlreadySettled"` - Trying to settle an already settled market

## Testing on Hyperliquid Testnet

1. Get testnet tokens from the faucet
2. Make sure the target user has an active position on the specified perpId
3. Set appropriate end times (future timestamps)
4. Test with small amounts first
5. Monitor gas usage (transactions are more expensive due to precompile calls)

This integration guide provides everything needed to build a frontend for the prediction market protocol on Hyperliquid testnet.