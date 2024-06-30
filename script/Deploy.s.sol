// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {Test} from "forge-std/Test.sol";
import {console2 as console} from "forge-std/console2.sol";
import {VanityMarket} from "../src/VanityMarket.sol";
import {HuffTest} from "../test/base/HuffTest.sol";

interface ICreateX {
    function deployCreate2(bytes32 salt, bytes calldata initCode) external payable returns (address);
}

/// @author philogy <https://github.com/philogy>
contract DeployScript is Test, Script, HuffTest {
    ICreateX constant CREATEX = ICreateX(0xba5Ed099633D3B313e4D5F7bdc1305d3c28ba5Ed);

    address constant MARKET_OWNER = 0xea57c1ef7eF1c88b456ADf0927ec0EAe3B17f1F5;
    bytes32 constant MARKET_SALT = 0x000000000000000000000000000000000000000094038e9be572f900652a472c;

    function run() public {
        vm.startBroadcast();

        require(address(CREATEX).code.length > 0, "No CreateX deployed to your chain");

        address microCreateOut =
            CREATEX.deployCreate2(bytes32(0), hex"7160203d3581360380833d373d34f53d523df33d526012600ef3");
        require(microCreateOut == MICRO_CREATE2, "Failed MICRO_CREATE2 deployment");

        bytes memory payload =
            hex"0000000000000000000000000000000000000000b07f6240b4f3c700ed9c26556104d980600a3d393df33d353d1a8060101161031357806080161561019f578060801161019f573d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df0505b806040161561026b573d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df0505b80602016156102d7573d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df0505b8060101615610313573d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df0505b7f03420372039f03c903f0041404350453046e0486049b04ad04bc04c804d104d790600f1660041b1c61ffff16565b3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3df03df03df03df03df03df03df03df03df03df03df03df03df03df03df0005b3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3df03df03df03df03df03df03df03df03df03df03df03df03df03df0005b3d3d3d3d3d3d3d3d3d3d3d3d3d3d3df03df03df03df03df03df03df03df03df03df03df03df03df0005b3d3d3d3d3d3d3d3d3d3d3d3d3d3df03df03df03df03df03df03df03df03df03df03df03df0005b3d3d3d3d3d3d3d3d3d3d3d3d3df03df03df03df03df03df03df03df03df03df03df0005b3d3d3d3d3d3d3d3d3d3d3d3df03df03df03df03df03df03df03df03df03df0005b3d3d3d3d3d3d3d3d3d3d3df03df03df03df03df03df03df03df03df0005b3d3d3d3d3d3d3d3d3d3df03df03df03df03df03df03df03df0005b3d3d3d3d3d3d3d3d3df03df03df03df03df03df03df0005b3d3d3d3d3d3d3d3df03df03df03df03df03df0005b3d3d3d3d3d3d3df03df03df03df03df0005b3d3d3d3d3d3df03df03df03df0005b3d3d3d3d3df03df03df0005b3d3d3d3df03df0005b3d3d3df0005b00";

        (bool success, bytes memory ret) = MICRO_CREATE2.call(payload);
        require(success && ret.length == 0x20, "Creation failed");
        address increaser = abi.decode(ret, (address));
        require(increaser == NONCE_INCREASER, "Constructor failed");

        bytes memory bytecode = abi.encodePacked(type(VanityMarket).creationCode, abi.encode(MARKET_OWNER));
        console.log("initcode hash: %x", uint256(keccak256(bytecode)));

        (success, ret) = MICRO_CREATE2.call(abi.encodePacked(MARKET_SALT, bytecode));
        if (!success || ret.length < 0x20) revert("Creation failed");
        address marketAddr = abi.decode(ret, (address));
        if (marketAddr == address(0)) revert("Constructor failed");

        console.log("marketAddr: %s", marketAddr);

        vm.stopBroadcast();
    }
}
