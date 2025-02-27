// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Script} from "forge-std/Script.sol";
import {RequestMarket} from "../src/RequestMarket.sol";
import {VanityMarket} from "src/VanityMarket.sol";
import {console} from "forge-std/console.sol";

contract RequestMarketDeploy is Script {
    VanityMarket constant FACTORY = VanityMarket(payable(0x000000000000b361194cfe6312EE3210d53C15AA));

    function run() public {
        vm.broadcast();
        address miner = vm.envAddress("MINER_ADDR");
        RequestMarket market = new RequestMarket(miner);
        if (miner == msg.sender) {
            FACTORY.setApprovalForAll(address(market), true);
        } else {
            console.log("WARNING: Need to have miner `setApprovalForAll` on factory");
        }
    }
}
