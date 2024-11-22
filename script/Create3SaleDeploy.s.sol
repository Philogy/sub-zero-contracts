// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Script} from "forge-std/Script.sol";

contract Create3SaleDeployScript is Script {
    function run() public {
        vm.broadcast();
        deployCode(
            "src/Create3RequestMarket.vy", abi.encode(vm.envAddress("VANITY_MARKET"), vm.envAddress("MINER_ADDR"))
        );
    }
}
