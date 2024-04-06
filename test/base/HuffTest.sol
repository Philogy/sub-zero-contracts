// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";

/// @author philogy <https://github.com/philogy>
contract HuffTest is Test {
    address internal constant MICRO_CREATE2 = 0x6D9FB3C412a269Df566a5c92b85a8dc334F0A797;
    address internal constant NONCE_INCREASER = 0x00000000000001E4A82b33373DE1334E7d8F4879;

    function setupBase() internal {
        vm.etch(MICRO_CREATE2, _huff("src/micro-create2/MicroCreate2.huff", new string[](0), false));
        vm.etch(NONCE_INCREASER, _huff("src/deploy-proxy/NonceIncreaser.huff", new string[](0), false));
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
