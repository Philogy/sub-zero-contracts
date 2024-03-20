// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @author philogy <https://github.com/philogy>
library SaltLib {
    error InvalidSaltOwner();

    function owner(uint256 salt) internal pure returns (address saltOwner) {
        saltOwner = address(uint160(salt >> 96));
        if (saltOwner == address(0)) revert InvalidSaltOwner();
    }
}
