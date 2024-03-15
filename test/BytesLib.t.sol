// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {BytesLib} from "../src/utils/BytesLib.sol";

/// @author philogy <https://github.com/philogy>
contract BytesLibTest is Test {
    using BytesLib for bytes;

    function giveBytes(bytes calldata data) external pure returns (bytes memory) {
        return data;
    }

    function directReturner(bytes memory data) external {
        data.directReturn();
    }

    function test_fuzzing_decodeBytes(bytes calldata data) public {
        (, bytes memory rawReturn) = address(this).staticcall(abi.encodeCall(this.giveBytes, (data)));
        assertEq(rawReturn.decodeBytes(), data);
    }

    function test_fuzzing_directReturn(bytes calldata data) public {
        (bool success, bytes memory rawReturn) = address(this).staticcall(abi.encodeCall(this.directReturner, (data)));
        assertTrue(success);
        assertEq(rawReturn, data);
    }
}
