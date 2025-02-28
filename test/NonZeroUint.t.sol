// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {NonZeroUint, ZERO, NonZeroUintLib} from "src/utils/NonZeroUint.sol";

/// @author philogy <https://github.com/philogy>
contract NonZeroUintTest is Test {
    uint256 internal MAX_NON_ZERO_UINT = (1 << 255) - 1;

    function test_zero() public pure {
        assertEq(ZERO.into(), 0);
    }

    /// forge-config: default.allow_internal_expect_revert = true
    function test_fuzzing_checked_add(NonZeroUint x, uint256 y) public {
        uint256 max_y = MAX_NON_ZERO_UINT - x.into();
        if (y > max_y) {
            vm.expectRevert(NonZeroUintLib.ArithmeticOverflow.selector);
            x.checked_add(y);
        } else {
            NonZeroUint out = x.checked_add(y);
            assertEq(out.into(), x.into() + y);
        }
    }
}
