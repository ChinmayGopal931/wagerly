// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {Market} from "../src/Market.sol";
import {OutcomeToken} from "../src/OutcomeToken.sol";
import {MarketAMM} from "../src/MarketAMM.sol";

contract DeployTokensAndAMM is Script {
    function run() external returns (address, address, address) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address marketAddress = vm.envAddress("MARKET_ADDRESS");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy outcome tokens
        OutcomeToken yesToken = new OutcomeToken("Yes Token", "YES");
        OutcomeToken noToken = new OutcomeToken("No Token", "NO");
        console.log("YesToken deployed at:", address(yesToken));
        console.log("NoToken deployed at:", address(noToken));

        // Deploy AMM
        MarketAMM amm = new MarketAMM(address(yesToken), address(noToken));
        console.log("AMM deployed at:", address(amm));

        // Initialize Market contract
        Market(marketAddress).initialize(address(yesToken), address(noToken), address(amm));
        console.log("Market initialized");

        vm.stopBroadcast();

        return (address(yesToken), address(noToken), address(amm));
    }
}