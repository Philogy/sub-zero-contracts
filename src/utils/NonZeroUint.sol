// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

type NonZeroUint is uint256;

using NonZeroUintLib for NonZeroUint global;

NonZeroUint constant ZERO = NonZeroUint.wrap(1);

/// @author philogy <https://github.com/philogy>
library NonZeroUintLib {
    error ArithmeticOverflow();

    function into(NonZeroUint value) internal pure returns (uint256) {
        return NonZeroUint.unwrap(value) >> 1;
    }

    function checked_add(NonZeroUint self, uint256 x) internal pure returns (NonZeroUint result) {
        assembly ("memory-safe") {
            result := add(self, shl(1, x))
            if or(gt(self, result), slt(x, 0)) {
                mstore(0x00, 0xe47ec074 /* ArithmeticOverflow() */ )
                revert(0x1c, 0x04)
            }
        }
    }
}
