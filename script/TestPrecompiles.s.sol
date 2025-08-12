// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {L1Read} from "../src/interface/L1Read.sol";

contract TestPrecompiles is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address targetUser = vm.envAddress("TARGET_USER");
        uint32 perpId = uint32(vm.envUint("PERP_ID"));
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Test position reader
        address positionReader = 0x0000000000000000000000000000000000000800;
        L1Read reader = L1Read(positionReader);
        L1Read.Position memory pos = reader.position(targetUser, uint16(perpId));
        
        console.log("Position szi:", uint256(int256(pos.szi)));
        console.log("Position entryNtl:", pos.entryNtl);
        console.log("Position isolatedRawUsd:", uint256(int256(pos.isolatedRawUsd)));
        console.log("Position leverage:", pos.leverage);
        console.log("Position isIsolated:", pos.isIsolated);
        
        // Test mark price
        address markPxReader = 0x0000000000000000000000000000000000000806;
        uint64 markPrice = L1Read(markPxReader).markPx(perpId);
        console.log("Mark price:", markPrice);
        
        vm.stopBroadcast();
    }
}