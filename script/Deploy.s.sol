// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {Test} from "forge-std/Test.sol";
import {console2 as console} from "forge-std/console2.sol";
import {VanityMarket} from "../src/VanityMarket.sol";
import {HuffTest} from "../test/base/HuffTest.sol";
import {CreationCodes} from "./utils/CreationCodes.sol";

interface ICreateX {
    function deployCreate2(bytes32 salt, bytes calldata initCode) external payable returns (address);
}

/// @author philogy <https://github.com/philogy>
contract DeployScript is Test, Script, HuffTest, CreationCodes {
    ICreateX constant CREATEX = ICreateX(0xba5Ed099633D3B313e4D5F7bdc1305d3c28ba5Ed);

    address constant MARKET_OWNER = 0xea57c1ef7eF1c88b456ADf0927ec0EAe3B17f1F5;
    bytes32 constant MARKET_SALT = 0x000000000000000000000000000000000000000094038e9be572f900652a472c;

    function deployMicroCreate2() public {
        address microCreate2 = CREATEX.deployCreate2(bytes32(0), MICRO_CREATE2_BYTECODE);
        console.log("MicroCreate2 deployed to: %s", microCreate2);
        require(microCreate2 == MICRO_CREATE2, "MicroCreate2 addresses mismatch");
    }

    function deployNonceIncreaser() public {
        (bool success, bytes memory ret) = MICRO_CREATE2.call(NONCE_INCREASER_BYTECODE);
        require(success && ret.length == 0x20, "NonceIncreaser deployment failed");

        address nonceIncreaser = abi.decode(ret, (address));
        console.log("NonceIncreaser deployed to: %s", nonceIncreaser);
        require(nonceIncreaser == NONCE_INCREASER, "NonceIncreaser addresses mismatch");
    }

    function deployVanityMarket() public {
        bytes memory bytecode = abi.encodePacked(VANITY_MARKET_BYTECODE, abi.encode(MARKET_OWNER));
        (bool success, bytes memory ret) = MICRO_CREATE2.call(abi.encodePacked(MARKET_SALT, bytecode));
        require(success && ret.length == 0x20, "VanityMarket deployment failed");

        address vanityMarket = abi.decode(ret, (address));
        console.log("VanityMarket deployed to: %s", vanityMarket);
        require(vanityMarket == VANITY_MARKET, "VanityMarket addresses mismatch");
    }

    function run() public {
        vm.startBroadcast();

        require(address(CREATEX).code.length > 0, "No CreateX deployed to your chain");

        if (address(MICRO_CREATE2).code.length == 0) {
            deployMicroCreate2();
        } else {
            console.log("MicroCreate2 already deployed");
        }

        if (address(NONCE_INCREASER).code.length == 0) {
            deployNonceIncreaser();
        } else {
            console.log("NonceIncreaser already deployed");
        }

        if (address(VANITY_MARKET).code.length == 0) {
            deployVanityMarket();
        } else {
            console.log("VanityMarket already deployed");
        }

        vm.stopBroadcast();
    }
}
