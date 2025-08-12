// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../test/mocks/MockPrecompiles.sol";
import "../src/interface/L1Read.sol";

contract TestMarketPrecompile is Script {
    address private constant POSITION_PRECOMPILE_ADDRESS = 0x0000000000000000000000000000000000000800;
    address private constant MARK_PX_PRECOMPILE_ADDRESS = 0x0000000000000000000000000000000000000806;
    
    function run() external {
        // Deploy and etch the mock precompiles for testing
        vm.etch(POSITION_PRECOMPILE_ADDRESS, address(new MockPositionPrecompile()).code);
        vm.etch(MARK_PX_PRECOMPILE_ADDRESS, address(new MockMarkPxPrecompile()).code);
        
        // Set up some mock data
        address targetUser = 0xD89091e7F5cE9f179B62604f658a5DD0E726e600;
        uint16 perpId = 3;
        
        // Set a mock position
        L1Read.Position memory pos = L1Read.Position({
            szi: 100,
            entryNtl: 500000000000, // 5000 * 100 * 1e8
            isolatedRawUsd: 0,
            leverage: 10,
            isIsolated: false
        });
        MockPositionPrecompile(payable(POSITION_PRECOMPILE_ADDRESS)).setPosition(targetUser, perpId, pos);
        
        // Set a mock mark price
        MockMarkPxPrecompile(payable(MARK_PX_PRECOMPILE_ADDRESS)).setPrice(600000000000); // 6000 * 1e8
        
        console.log("Mock precompiles set up successfully");
        console.log("Position precompile address:", POSITION_PRECOMPILE_ADDRESS);
        console.log("Mark price precompile address:", MARK_PX_PRECOMPILE_ADDRESS);
        
        // Test position call directly
        (bool posSuccess, bytes memory posData) = POSITION_PRECOMPILE_ADDRESS.staticcall(
            abi.encode(targetUser, perpId)
        );
        console.log("Position call success:", posSuccess);
        
        if (posSuccess && posData.length > 0) {
            (int64 szi, uint64 entryNtl,,,) = abi.decode(posData, (int64, uint64, int64, uint32, bool));
            console.log("Position szi:", uint256(uint64(szi)));
            console.log("Position entryNtl:", entryNtl);
        }
        
        // Test mark price call directly  
        (bool priceSuccess, bytes memory priceData) = MARK_PX_PRECOMPILE_ADDRESS.staticcall(
            abi.encode(uint32(perpId))
        );
        console.log("Mark price call success:", priceSuccess);
        
        if (priceSuccess && priceData.length > 0) {
            uint64 price = abi.decode(priceData, (uint64));
            console.log("Mark price:", price);
        }
    }
}

contract TestHelper {
    address private constant POSITION_PRECOMPILE_ADDRESS = 0x0000000000000000000000000000000000000800;
    address private constant MARK_PX_PRECOMPILE_ADDRESS = 0x0000000000000000000000000000000000000806;
    
    function testPositionCall() external view returns (bool) {
        address targetUser = 0xD89091e7F5cE9f179B62604f658a5DD0E726e600;
        uint16 perpId = 3;
        
        (bool success, bytes memory data) = POSITION_PRECOMPILE_ADDRESS.staticcall(
            abi.encode(targetUser, perpId)
        );
        
        return success && data.length > 0;
    }
    
    function testMarkPriceCall() external view returns (uint64) {
        uint32 perpId = 3;
        
        (bool success, bytes memory data) = MARK_PX_PRECOMPILE_ADDRESS.staticcall(
            abi.encode(perpId)
        );
        
        if (!success || data.length == 0) {
            return 0; // Return 0 instead of reverting for testing
        }
        return abi.decode(data, (uint64));
    }
}