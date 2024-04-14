// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {Test} from "forge-std/Test.sol";
import {console2 as console} from "forge-std/console2.sol";
import {VanityMarket} from "../src/VanityMarket.sol";
import {HuffTest} from "../test/base/HuffTest.sol";

/// @author philogy <https://github.com/philogy>
contract VanityMarketScript is Test, Script, HuffTest {
    function run() public {
        vm.startBroadcast();

        address owner = vm.envAddress("MARKET_OWNER");
        bytes memory bytecode = abi.encodePacked(type(VanityMarket).creationCode, abi.encode(owner));
        console.log("initcode hash: %x", uint256(keccak256(bytecode)));

        bytes32 salt = vm.envBytes32("MARKET_SALT");

        (bool success, bytes memory ret) = MICRO_CREATE2.call(abi.encodePacked(salt, bytecode));
        if (!success || ret.length < 0x20) revert("Creation failed");
        address marketAddr = abi.decode(ret, (address));
        if (marketAddr == address(0)) revert("Constructor failed");

        console.log("marketAddr: %s", marketAddr);

        vm.stopBroadcast();
    }
}
