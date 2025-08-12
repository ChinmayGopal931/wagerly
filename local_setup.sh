#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

# --- Configuration ---
DEPLOYER_PK="0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
DEPLOYER_ADDRESS="0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"
RECIPIENT_ADDRESS="0x582d14BdDDC7F1418bfA258cc8754548b1ECF408"
RPC_URL="http://127.0.0.1:8545"

# --- Script Start ---
echo "🚀 Starting local development environment setup..."

# 0. Check for dependencies
if ! command -v jq &> /dev/null
then
    echo "Error: jq is not installed. Please install it to run this script."
    echo "On macOS: brew install jq"
    exit 1
fi

# 1. Start Anvil in the background
echo "    - Starting Anvil, forking Hyperliquid mainnet..."
anvil --fork-url https://rpc.hyperliquid.xyz/evm --chain-id 999 --base-fee 0 --block-gas-limit 100000000 > /tmp/anvil.log 2>&1 &
ANVIL_PID=$!
# Ensure anvil is killed when the script exits, even if it fails
trap "echo '...Stopping Anvil'; kill $ANVIL_PID" EXIT
# Give anvil a few seconds to start up
sleep 5
echo "    - Anvil started in the background (PID: $ANVIL_PID)"

# 2. Deploy the L1Read contract to act as a wrapper for precompile calls
echo "    - Deploying L1Read wrapper contract..."
# Add --broadcast to actually deploy and --json for reliable address parsing
L1READ_JSON=$(forge create src/interface/L1Read.sol:L1Read --rpc-url $RPC_URL --private-key $DEPLOYER_PK --broadcast --json)
L1READ_ADDRESS=$(echo "$L1READ_JSON" | jq -r '.deployedTo')
echo "    - L1Read contract deployed to: $L1READ_ADDRESS"

# 3. Deploy contracts using the universal script
echo "    - Deploying Market contract..."
export PRIVATE_KEY="$DEPLOYER_PK"
export TARGET_USER="0x70997970C51812dc3A010C7d01b50e0d17dc79C8"
export PERP_ID=1
export END_TIME=1767225600
export POSITION_READER="$L1READ_ADDRESS"
export MARK_PX_READER="$L1READ_ADDRESS"

# Add --json flag for reliable parsing and capture the entire stream
DEPLOY_STREAM=$(forge script script/Deploy.s.sol:Deploy --rpc-url $RPC_URL --broadcast --legacy --json)

# Find the specific JSON object in the stream that contains the return values
RETURNS_JSON=$(echo "$DEPLOY_STREAM" | grep '"returns":' | tail -n 1)

# Extract addresses using jq from the isolated JSON object
MARKET_ADDRESS=$(echo "$RETURNS_JSON" | jq -r '.returns."0".value')
USDC_ADDRESS=$(echo "$RETURNS_JSON" | jq -r '.returns."1".value')

echo "    - Market contract deployed to: $MARKET_ADDRESS"
echo "    - MockUSDC deployed to: $USDC_ADDRESS"

# 3. Fund your wallet
echo "    - Funding your wallet ($RECIPIENT_ADDRESS)..."
# Send 100 native HYPE
cast send "$RECIPIENT_ADDRESS" --value 100ether --rpc-url $RPC_URL --private-key $DEPLOYER_PK > /dev/null
# Mint 1,000,000 MockUSDC
cast send "$USDC_ADDRESS" "mint(address,uint256)" "$RECIPIENT_ADDRESS" 1000000000000 --rpc-url $RPC_URL --private-key $DEPLOYER_PK > /dev/null
echo "    - Sent 100 HYPE and 1,000,000 MockUSDC."

# 4. Fund the deployer wallet (for easy interaction)
echo "    - Funding the deployer wallet ($DEPLOYER_ADDRESS) with MockUSDC..."
cast send "$USDC_ADDRESS" "mint(address,uint256)" "$DEPLOYER_ADDRESS" 1000000000000 --rpc-url $RPC_URL --private-key $DEPLOYER_PK > /dev/null
echo "    - Sent 1,000,000 MockUSDC."

# --- Script End ---
echo ""
echo "------------------------------------------------------"
echo "✅ Local Environment Setup Complete!"
echo "------------------------------------------------------"
echo ""
echo "Anvil is running in the background. Press Ctrl+C to stop."
echo ""
echo "🔗 RPC URL: $RPC_URL"
echo ""
echo "📜 Deployed Contracts:"
echo "   - L1Read:   $L1READ_ADDRESS"
echo "   - MockUSDC: $USDC_ADDRESS"
echo "   - Market:   $MARKET_ADDRESS"
echo ""
echo "💰 Funded Wallet: $RECIPIENT_ADDRESS"
echo "   - Balance: 100 HYPE, 1,000,000 MockUSDC"
echo ""
echo "You can now connect your front-end and MetaMask to the RPC URL."
echo ""

# Wait for the user to kill the script (which will also kill anvil via the trap)
wait $ANVIL_PID
