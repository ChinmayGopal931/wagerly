#!/bin/bash

# Quick Fork Testing Script for PnL Betting Contract
# Usage: ./fork-test.sh

set -e

echo "🚀 Starting Hyperliquid Fork Testing..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if foundry is installed
if ! command -v forge &> /dev/null; then
    echo -e "${RED}Error: Foundry not installed. Install with: curl -L https://foundry.paradigm.xyz | bash${NC}"
    exit 1
fi

# Check if anvil is running
if ! curl -s http://127.0.0.1:8545 > /dev/null; then
    echo -e "${YELLOW}Starting Anvil with Hyperliquid fork...${NC}"
    echo "Run this in another terminal:"
    echo -e "${BLUE}anvil --fork-url https://rpc.hyperliquid.xyz/evm${NC}"
    echo ""
    read -p "Press enter when Anvil is running..."
fi

# Default environment variables
export PRIVATE_KEY=${PRIVATE_KEY:-"0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"}
export TARGET_USER=${TARGET_USER:-"0x0000000000000000000000000000000000000001"}
export PERP_ID=${PERP_ID:-"1"}
export DURATION=${DURATION:-"3600"}

echo -e "${GREEN}Step 1: Deploying contracts...${NC}"
forge script script/ForkDeploy.s.sol --rpc-url http://127.0.0.1:8545 --broadcast

# Extract factory address from deployment (this is simplified - in practice you'd parse the logs)
echo ""
echo -e "${YELLOW}Copy the FACTORY_ADDRESS from above and run:${NC}"
echo -e "${BLUE}export FACTORY_ADDRESS=0xYourFactoryAddress${NC}"
echo ""
read -p "Press enter when you've set FACTORY_ADDRESS..."

if [ -z "$FACTORY_ADDRESS" ]; then
    echo -e "${RED}Error: FACTORY_ADDRESS not set${NC}"
    exit 1
fi

echo -e "${GREEN}Step 2: Creating bet and placing wagers...${NC}"
forge script script/ForkInteract.s.sol --rpc-url http://127.0.0.1:8545 --broadcast

echo ""
echo -e "${YELLOW}Copy the BET_ADDRESS from above and run:${NC}"
echo -e "${BLUE}export BET_ADDRESS=0xYourBetAddress${NC}"
echo ""
read -p "Press enter when you've set BET_ADDRESS..."

if [ -z "$BET_ADDRESS" ]; then
    echo -e "${RED}Error: BET_ADDRESS not set${NC}"
    exit 1
fi

echo -e "${GREEN}Step 3: Fast-forwarding time...${NC}"
cast rpc anvil_increaseTime 3601 --rpc-url http://127.0.0.1:8545

echo -e "${GREEN}Step 4: Settling bet with live Hyperliquid data...${NC}"
forge script script/ForkSettle.s.sol --rpc-url http://127.0.0.1:8545 --broadcast

echo -e "${GREEN}Step 5: Claiming winnings...${NC}"
cast send $BET_ADDRESS "claimWinnings()" --rpc-url http://127.0.0.1:8545 --private-key $PRIVATE_KEY

echo ""
echo -e "${GREEN}✅ Fork testing complete!${NC}"
echo ""
echo -e "${BLUE}Advanced testing:${NC}"
echo "forge test --match-contract ForkTest --fork-url https://rpc.hyperliquid.xyz/evm -vvv"
echo ""
echo -e "${BLUE}Check results:${NC}"
echo "cast call $BET_ADDRESS \"outcome()\" --rpc-url http://127.0.0.1:8545"
echo "cast call $BET_ADDRESS \"getTotalPool()\" --rpc-url http://127.0.0.1:8545"