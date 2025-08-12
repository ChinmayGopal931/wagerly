// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {MockERC20} from "../test/mocks/MockERC20.sol";

contract DeployMockUSDC is Script {
    function run() external returns (address) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        vm.startBroadcast(deployerPrivateKey);
        
        MockERC20 usdcToken = new MockERC20("USD Coin", "USDC", 6, 0);
        console.log("MockUSDC deployed at:", address(usdcToken));
        
        vm.stopBroadcast();
        
        return address(usdcToken);
    }
}