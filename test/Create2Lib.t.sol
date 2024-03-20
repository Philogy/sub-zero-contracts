// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {Create2Lib} from "../src/utils/Create2Lib.sol";
import {console2 as console} from "forge-std/console2.sol";

/// @author philogy <https://github.com/philogy>
contract Create2LibTest is Test {
    using Create2Lib for address;

    function test_leadingZerosBaseCases() public {
        assertEq(address(0).leadingZeros(), 20);
        assertEq(address(0xff).leadingZeros(), 19);
        assertEq(address(0x1000).leadingZeros(), 18);
        assertEq(address(0xFFfFfFffFFfffFFfFFfFFFFFffFFFffffFfFFFfF).leadingZeros(), 0);
        assertEq(address(0x00000000000000ADc04C56Bf30aC9d3c0aAF14dC).leadingZeros(), 7);
    }

    function test_leadingZeros(address addr) public {
        uint256 total = 0;
        bytes20 b = bytes20(addr);
        for (; total < 20; total++) {
            if (b[total] != 0) break;
        }
        assertEq(addr.leadingZeros(), total);
    }

    function test_totalZeros(address addr) public {
        uint256 total;
        bytes20 b = bytes20(addr);
        for (uint256 i = 0; i < 20; i++) {
            total += b[i] == 0x00 ? 1 : 0;
        }
        assertEq(addr.totalZeros(), total);
    }
}
