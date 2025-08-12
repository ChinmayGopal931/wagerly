// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {Market} from "../src/Market.sol";
import {OutcomeToken} from "../src/OutcomeToken.sol";
import {MarketAMM} from "../src/MarketAMM.sol";

contract DeployOptimized is Script {
    function run() external returns (address, address, address, address) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address targetUser = vm.envAddress("TARGET_USER");
        uint32 perpId = uint32(vm.envUint("PERP_ID"));
        uint256 endTime = vm.envUint("END_TIME");
        address usdcToken = 0x56bBe49B9dAF9d4f11463285deBBe49631C12a40; // Deployed MockUSDC
        address positionReader = vm.envAddress("POSITION_READER");
        address markPxReader = vm.envAddress("MARK_PX_READER");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy Market contract (lightweight)
        Market market = new Market(targetUser, perpId, endTime, usdcToken, positionReader, markPxReader);
        console.log("Market contract deployed at:", address(market));

        vm.stopBroadcast();

        return (address(market), usdcToken, address(0), address(0));
    }
}