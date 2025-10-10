// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {console2 as console} from "forge-std/console2.sol";

/// @author philogy <https://github.com/philogy>
contract HuffTest is Test {
    address internal constant MICRO_CREATE2 = 0x6D9FB3C412a269Df566a5c92b85a8dc334F0A797;
    address internal constant NONCE_INCREASER = 0x00000000000001E4A82b33373DE1334E7d8F4879;
    address internal constant VANITY_MARKET = 0x000000000000b361194cfe6312EE3210d53C15AA;

    function setupBase_ffi() internal {
        string[] memory empty = new string[](1);
        empty[0] = "ls";
        try vm.ffi(empty) {
            vm.etch(MICRO_CREATE2, _huff("src/micro-create2/MicroCreate2.huff", new string[](0), false));
            vm.etch(NONCE_INCREASER, _huff("src/deploy-proxy/NonceIncreaser.huff", new string[](0), false));
        } catch {
            if (MICRO_CREATE2.code.length != 0 && NONCE_INCREASER.code.length != 0) return;
            console.log(
                "WARNING: ffi seems to be disabled and not in a fork test, reverting to hardcoded base contracts"
            );
            vm.etch(MICRO_CREATE2, hex"60203d3581360380833d373d34f53d523df3");
            vm.etch(
                NONCE_INCREASER,
                hex"3d353d1a8060101161031357806080161561019f578060801161019f573d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df0505b806040161561026b573d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df0505b80602016156102d7573d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df0505b8060101615610313573d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3df03df03df03df03df03df03df03df03df03df03df03df03df03df03df03df0505b7f03420372039f03c903f0041404350453046e0486049b04ad04bc04c804d104d790600f1660041b1c61ffff16565b3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3df03df03df03df03df03df03df03df03df03df03df03df03df03df03df0005b3d3d3d3d3d3d3d3d3d3d3d3d3d3d3d3df03df03df03df03df03df03df03df03df03df03df03df03df03df0005b3d3d3d3d3d3d3d3d3d3d3d3d3d3d3df03df03df03df03df03df03df03df03df03df03df03df03df0005b3d3d3d3d3d3d3d3d3d3d3d3d3d3df03df03df03df03df03df03df03df03df03df03df03df0005b3d3d3d3d3d3d3d3d3d3d3d3d3df03df03df03df03df03df03df03df03df03df03df0005b3d3d3d3d3d3d3d3d3d3d3d3df03df03df03df03df03df03df03df03df03df0005b3d3d3d3d3d3d3d3d3d3d3df03df03df03df03df03df03df03df03df0005b3d3d3d3d3d3d3d3d3d3df03df03df03df03df03df03df03df0005b3d3d3d3d3d3d3d3d3df03df03df03df03df03df03df0005b3d3d3d3d3d3d3d3df03df03df03df03df03df0005b3d3d3d3d3d3d3df03df03df03df03df0005b3d3d3d3d3d3df03df03df03df0005b3d3d3d3d3df03df03df0005b3d3d3d3df03df0005b3d3d3df0005b00"
            );
        }
    }

    function deployRaw(bytes memory initcode) internal returns (address) {
        return deployRaw(initcode, 0);
    }

    function deployRaw(bytes memory initcode, uint256 value) internal returns (address addr) {
        assembly ("memory-safe") {
            addr := create(value, add(initcode, 0x20), mload(initcode))
        }
    }

    function _huffInitcode(string memory path) internal returns (bytes memory) {
        return _huffInitcode(path, new string[](0));
    }

    function _huffInitcode(string memory path, string[] memory constants) internal returns (bytes memory) {
        return _huff(path, constants, true);
    }

    function _huff(string memory path, string[] memory constants, bool initcode) internal returns (bytes memory) {
        uint256 totalConsts = constants.length;
        string[] memory args = new string[](4 + totalConsts * 2);
        args[0] = "huffy";
        args[1] = initcode ? "-b" : "-r";
        args[2] = path;
        args[3] = "--avoid-push0";
        for (uint256 i = 0; i < totalConsts; i++) {
            args[4 + i * 2] = "-c";
            args[5 + i * 2] = constants[i];
        }
        return vm.ffi(args);
    }
}
