// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {BytesLib} from "../src/utils/BytesLib.sol";

/// @author philogy <https://github.com/philogy>
contract BytesLibTest is Test {
    function giveBytes(bytes calldata data) external pure returns (bytes memory) {
        return data;
    }

    function test_fuzzing_decodesCorrectly(bytes calldata data) public {
        (, bytes memory rawReturn) = address(this).staticcall(abi.encodeCall(this.giveBytes, (data)));
        assertEq(BytesLib.decodeBytes(rawReturn), data);
    }
}
