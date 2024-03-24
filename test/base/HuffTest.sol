// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";

/// @author philogy <https://github.com/philogy>
contract HuffTest is Test {
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
        uint256 totalConsts = constants.length;
        string[] memory args = new string[](4 + totalConsts * 2);
        args[0] = "huffy";
        args[1] = "-b";
        args[2] = path;
        args[3] = "--avoid-push0";
        for (uint256 i = 0; i < totalConsts; i++) {
            args[4 + i * 2] = "-c";
            args[5 + i * 2] = constants[i];
        }
        return vm.ffi(args);
    }
}
