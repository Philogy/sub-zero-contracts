// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Script} from "forge-std/Script.sol";
import {RequestMarket} from "../src/RequestMarket.sol";

contract RequestMarketDeploy is Script {
    function run() public {
        vm.broadcast();
        new RequestMarket(vm.envAddress("MINER_ADDR"));
    }
}
