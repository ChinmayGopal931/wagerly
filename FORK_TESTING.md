# Hyperliquid Fork Testing Guide

This guide explains how to test your PnL betting contracts against **live Hyperliquid mainnet data** using Foundry's fork testing capabilities.

## What is Fork Testing?

Fork testing creates a local simulation of the Hyperliquid blockchain that:
- **Read Operations**: Forwards requests to live Hyperliquid mainnet for real data
- **Write Operations**: Executes locally with unlimited fake funds
- **Result**: Realistic testing with live data, zero financial risk

## Prerequisites

- [Foundry installed](https://book.getfoundry.sh/getting-started/installation)
- This project cloned and set up

## Quick Start

### 1. Start Hyperliquid Fork

Open a terminal and start Anvil with Hyperliquid fork:

```bash
anvil --fork-url https://rpc.hyperliquid.xyz/evm
```

Keep this terminal open. Anvil will display 10 funded accounts with private keys.

### 2. Set Environment Variables

Copy one of the private keys from Anvil output:

```bash
export PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
```

### 3. Deploy Contracts to Fork

```bash
forge script script/ForkDeploy.s.sol --rpc-url http://127.0.0.1:8545 --broadcast
```

Copy the factory address from the output and set it:

```bash
export FACTORY_ADDRESS=0x5FbDB2315678afecb367f032d93F642f64180aa3
```

### 4. Find a Live Target

Visit [Hyperliquid](https://app.hyperliquid.xyz/) and find an active trader:

```bash
export TARGET_USER=0x1234567890123456789012345678901234567890  # Replace with real address
export PERP_ID=1  # BTC = 1, ETH = 2, etc.
export DURATION=3600  # 1 hour
```

### 5. Create and Place Bets

```bash
forge script script/ForkInteract.s.sol --rpc-url http://127.0.0.1:8545 --broadcast
```

This will:
- Create a new bet on the target trader's position
- Place a bet on the profitable outcome
- Show you the bet contract address

### 6. Fast-Forward Time

```bash
cast rpc anvil_increaseTime 3601 --rpc-url http://127.0.0.1:8545
```

### 7. Settle with Live Data

Set the bet address from step 5:

```bash
export BET_ADDRESS=0xYourBetAddress
forge script script/ForkSettle.s.sol --rpc-url http://127.0.0.1:8545 --broadcast
```

This calls **live Hyperliquid precompiles** to determine the real PnL!

### 8. Claim Winnings

```bash
cast send $BET_ADDRESS "claimWinnings()" --rpc-url http://127.0.0.1:8545 --private-key $PRIVATE_KEY
```

## Advanced Testing

### Run Integration Tests

Test the full workflow programmatically:

```bash
forge test --match-contract ForkTest --fork-url https://rpc.hyperliquid.xyz/evm -vvv
```

### Test Specific Scenarios

```bash
# Test only settlement logic
forge test --match-test testForkPrecompileReads --fork-url https://rpc.hyperliquid.xyz/evm -vvv

# Test multiple assets
forge test --match-test testForkMultipleAssets --fork-url https://rpc.hyperliquid.xyz/evm -vvv
```

## Manual Commands

### Deploy Individual Contracts

```bash
# Deploy logic contract
forge create src/PnlBet.sol:PnlBet \\
    --constructor-args "0x0000000000000000000000000000000000000000" "0x0000000000000000000000000000000000000000" \\
    --rpc-url http://127.0.0.1:8545 \\
    --private-key $PRIVATE_KEY

# Deploy factory (replace LOGIC_ADDRESS)
forge create src/BetFactory.sol:BetFactory \\
    --constructor-args "LOGIC_ADDRESS" \\
    --rpc-url http://127.0.0.1:8545 \\
    --private-key $PRIVATE_KEY
```

### Manual Interactions

```bash
# Create bet
cast send $FACTORY_ADDRESS "createBet(address,uint32,uint256)" $TARGET_USER $PERP_ID $DURATION \\
    --rpc-url http://127.0.0.1:8545 --private-key $PRIVATE_KEY

# Place bet (replace BET_ADDRESS)
cast send $BET_ADDRESS "placeBet(bool)" true --value 1ether \\
    --rpc-url http://127.0.0.1:8545 --private-key $PRIVATE_KEY

# Settle bet
cast send $BET_ADDRESS "settle()" \\
    --rpc-url http://127.0.0.1:8545 --private-key $PRIVATE_KEY

# Check outcome
cast call $BET_ADDRESS "outcome()" --rpc-url http://127.0.0.1:8545
```

### Query Live Data

```bash
# Check if position exists
cast call $BET_ADDRESS "positionReader()" --rpc-url http://127.0.0.1:8545

# Check bet details
cast call $BET_ADDRESS "targetUser()" --rpc-url http://127.0.0.1:8545
cast call $BET_ADDRESS "perpId()" --rpc-url http://127.0.0.1:8545
cast call $BET_ADDRESS "isSettled()" --rpc-url http://127.0.0.1:8545
```

## Understanding Results

### Outcome Values
- `0` = Undecided
- `1` = Profitable (position has positive PnL)
- `2` = Unprofitable (position has negative PnL or is closed)

### Settlement Logic
The contract calls these Hyperliquid precompiles:
1. **Position Precompile** (`0x800`): Gets position size and entry notional
2. **Mark Price Precompile** (`0x806`): Gets current mark price
3. **Calculates PnL**: `(currentPrice - entryPrice) * positionSize`

### Precompile Addresses
- Position Reader: `0x0000000000000000000000000000000000000800`
- Mark Price Reader: `0x0000000000000000000000000000000000000806`

## Common Issues

### "Position precompile call failed"
- The target address doesn't have a position on that perp
- Try a different `TARGET_USER` or `PERP_ID`

### "Bet is not over"
- Fast-forward time: `cast rpc anvil_increaseTime 3601`

### "No winnings"
- You bet on the wrong side, or need to use a different address

## Real Trading Example

1. Go to [Hyperliquid Leaderboard](https://app.hyperliquid.xyz/leaderboard)
2. Find a trader with an active BTC position
3. Copy their address
4. Set `TARGET_USER` to their address
5. Follow the testing steps above

The contract will read their **actual live position** and determine if they're currently profitable!

## Development Tips

- Use `console.log()` in contracts to debug during fork testing
- Check `block.timestamp` to understand timing issues
- Use different `PERP_ID` values for different assets (BTC=1, ETH=2, etc.)
- Test edge cases like closed positions or very small positions

## Production Deployment

When ready for Hyperliquid mainnet:

```bash
forge script script/Deploy.s.sol --rpc-url hyperliquid --broadcast
```

The contracts automatically use real Hyperliquid precompile addresses in production.

**Note**: Hyperliquid EVM doesn't have a block explorer like Etherscan yet, so contract verification isn't available.