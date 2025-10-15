# Wagerly - A Prediction Market built entirely on HyperEVM 

Finalist for the Hyperliquid Community Hackaton - https://x.com/hl_hackathon/status/1965085820798591198


Link to submission : https://taikai.network/hl-hackathon-organizers/hackathons/hl-hackathon/projects/cmeks4n6d02odw40igiffkw7g/idea


## Architecture

### Core Contracts

- **PnlBet.sol**: Logic contract containing all betting functionality
- **BetFactory.sol**: Factory contract that deploys minimal proxies using EIP-1167

### Key Features

- **Gas Efficient**: Uses minimal proxy pattern to deploy lightweight bet contracts
- **Factory Pattern**: Centralized registry for discovering all bets
- **Flexible Betting**: Support for both profit and loss predictions
- **Automated Settlement**: Mock PnL calculation (ready for Hyperliquid precompile integration)
- **Comprehensive Testing**: Full test coverage for both contracts

## Getting Started

### Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- Git

### Installation

```bash
# Clone the repository
git clone <repository-url>
cd project-mosiac

# Install dependencies
forge install

# Copy environment file
cp .env.example .env
```

### Configuration

Edit `.env` file with your configuration:

```bash
PRIVATE_KEY=your-private-key
ETHEREUM_RPC_URL=your-rpc-url
# ... other configuration
```

## Usage

### Build

```bash
forge build
```

### Test

```bash
# Run all tests
forge test

# Run tests with gas reporting
forge test --gas-report

# Run specific test file
forge test --match-path test/PnlBet.t.sol -vvv
```

### Deploy

```bash
# Deploy to local fork
forge script script/Deploy.s.sol --rpc-url local --broadcast

# Deploy to Hyperliquid mainnet
forge script script/Deploy.s.sol --rpc-url hyperliquid --broadcast
```

### Create a Bet

After deployment, update your `.env` file with the factory address and run:

```bash
forge script script/CreateBet.s.sol --rpc-url hyperliquid --broadcast
```

## Contract Interaction

### Creating a Bet

```solidity
// Create a bet on user's PnL for perp ID 1, lasting 1 hour
address betAddress = factory.createBet(
    targetUser,  // Address to track
    1,           // Perp ID
    3600         // Duration in seconds
);
```

### Placing Bets

```solidity
PnlBet bet = PnlBet(betAddress);

// Bet 1 ETH that the position will be profitable
bet.placeBet{value: 1 ether}(true);

// Bet 2 ETH that the position will be unprofitable
bet.placeBet{value: 2 ether}(false);
```

### Settlement and Claims

```solidity
// After the bet period ends, anyone can settle
bet.settle();

// Winners can claim their proportional share
bet.claimWinnings();
```

## Gas Optimization

The system is optimized for minimal gas usage:

- **Proxy Deployment**: ~45,000 gas per new bet (vs ~500,000 for full contract)
- **Factory Registry**: O(1) bet creation and discovery
- **Batch Operations**: Factory supports batch settlement for keeper bots

## Testing

The project includes comprehensive tests covering:

- Contract deployment and initialization
- Bet creation and placement
- Settlement mechanics
- Winnings calculation and distribution
- Edge cases and error conditions

Run tests with:

```bash
forge test -vvv
```

### Fork Testing with Live Hyperliquid Data

Test against real Hyperliquid mainnet positions:

```bash
# Start Hyperliquid fork
anvil --fork-url https://rpc.hyperliquid.xyz/evm

# Run fork tests
forge test --match-contract ForkTest --fork-url https://rpc.hyperliquid.xyz/evm -vvv

# Or use the quick start script
./fork-test.sh
```

See [FORK_TESTING.md](./FORK_TESTING.md) for detailed instructions.

## Mock Implementation Note

The current implementation uses a mock PnL calculation for testing. In production, this would be replaced with calls to Hyperliquid precompiles:

```solidity
// Replace _getMockPnl() with actual Hyperliquid integration:
// 1. Call position precompile for target user and perp ID
// 2. Call markPx precompile for current mark price
// 3. Calculate actual PnL based on position data
```

## Security Considerations

- Uses OpenZeppelin's battle-tested proxy and reentrancy protection
- All external calls are protected with proper checks
- Comprehensive test coverage includes edge cases
- Ready for audit and mainnet deployment

## License

MIT License
# mosaic
