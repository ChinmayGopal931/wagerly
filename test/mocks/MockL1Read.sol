// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../../src/interface/L1Read.sol";

contract MockL1Read is L1Read {
    // Mock data storage
    mapping(address => mapping(uint16 => Position)) private positions;
    mapping(uint32 => uint64) private markPrices;
    
    // Default mock data
    constructor() {
        // Set some default mock data for testing
        setMockMarkPrice(1, 50000); // Default mark price for perpId 1
    }
    
    function setMockPosition(address user, uint16 perp, int64 szi, uint64 entryNtl) external {
        positions[user][perp] = Position({
            szi: szi,
            entryNtl: entryNtl,
            isolatedRawUsd: 0,
            leverage: 10,
            isIsolated: false
        });
    }
    
    function setMockMarkPrice(uint32 index, uint64 price) public {
        markPrices[index] = price;
    }
    
    // Override the L1Read functions with mock implementations
    function position(address user, uint16 perp) external view override returns (Position memory) {
        Position memory pos = positions[user][perp];
        
        // If no mock data set, return a default profitable position
        if (pos.szi == 0 && pos.entryNtl == 0) {
            // Create deterministic but pseudo-random outcome based on user address
            uint256 seed = uint256(keccak256(abi.encodePacked(user, perp, block.timestamp))) % 100;
            
            if (seed >= 50) {
                // Profitable position: current price > entry price
                return Position({
                    szi: 1000, // Long position
                    entryNtl: 45000, // Entry price lower than mark price
                    isolatedRawUsd: 0,
                    leverage: 10,
                    isIsolated: false
                });
            } else {
                // Unprofitable position: current price < entry price  
                return Position({
                    szi: 1000, // Long position
                    entryNtl: 55000, // Entry price higher than mark price
                    isolatedRawUsd: 0,
                    leverage: 10,
                    isIsolated: false
                });
            }
        }
        
        return pos;
    }
    
    function markPx(uint32 index) external view override returns (uint64) {
        uint64 price = markPrices[index];
        return price != 0 ? price : 50000; // Default price if not set
    }
    
    // Implement other required functions (can be empty for our tests)
    function spotBalance(address, uint64) external pure override returns (SpotBalance memory) {
        return SpotBalance(0, 0, 0);
    }
    
    function userVaultEquity(address, address) external pure override returns (UserVaultEquity memory) {
        return UserVaultEquity(0, 0);
    }
    
    function withdrawable(address) external pure override returns (Withdrawable memory) {
        return Withdrawable(0);
    }
    
    function delegations(address) external pure override returns (Delegation[] memory) {
        return new Delegation[](0);
    }
    
    function delegatorSummary(address) external pure override returns (DelegatorSummary memory) {
        return DelegatorSummary(0, 0, 0, 0);
    }
    
    function oraclePx(uint32) external pure override returns (uint64) {
        return 50000;
    }
    
    function spotPx(uint32) external pure override returns (uint64) {
        return 50000;
    }
    
    function l1BlockNumber() external view override returns (uint64) {
        return uint64(block.number);
    }
    
    function perpAssetInfo(uint32) external pure override returns (PerpAssetInfo memory) {
        return PerpAssetInfo("BTC", 1, 8, 50, false);
    }
    
    function spotInfo(uint32) external pure override returns (SpotInfo memory) {
        uint64[2] memory tokens = [uint64(0), uint64(1)];
        return SpotInfo("BTC/USD", tokens);
    }
    
    function tokenInfo(uint32) external pure override returns (TokenInfo memory) {
        return TokenInfo("BTC", new uint64[](0), 0, address(0), address(0), 8, 18, 0);
    }
    
    function tokenSupply(uint32) external pure override returns (TokenSupply memory) {
        return TokenSupply(0, 0, 0, 0, new UserBalance[](0));
    }
    
    function bbo(uint32) external pure override returns (Bbo memory) {
        return Bbo(49900, 50100);
    }
    
    function accountMarginSummary(uint32, address) external pure override returns (AccountMarginSummary memory) {
        return AccountMarginSummary(100000, 50000, 75000, 0);
    }
    
    function coreUserExists(address) external pure override returns (CoreUserExists memory) {
        return CoreUserExists(true);
    }
}