// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @author philogy <https://github.com/philogy>
library Create2Lib {
    function predict(bytes32 initCodeHash, bytes32 salt, address deployer) internal pure returns (address predicted) {
        assembly ("memory-safe") {
            // https://eips.ethereum.org/EIPS/eip-1014
            let ptr := mload(0x40)
            mstore(0x40, initCodeHash)
            mstore(0x20, salt)
            mstore(0x00, deployer)
            mstore8(0x0b, 0xff) // Write the leading create2 byte.
            predicted := keccak256(0x0b, 0x55)
            // Restore the free memory pointer
            mstore(0x40, ptr)
        }
    }

    function leadingZeros(address addr) internal pure returns (uint256 total) {
        assembly ("memory-safe") {
            let r := mul(80, gt(addr, 0xffffffffffffffffffff))
            r := add(r, mul(40, gt(shr(r, addr), 0xffffffffff)))
            r := add(r, mul(24, gt(shr(r, addr), 0xffffff)))
            let s := shr(r, addr)
            let b := add(add(iszero(iszero(s)), gt(s, 0xff)), gt(s, 0xffff))
            total := sub(20, add(b, shr(3, r)))
        }
    }

    function totalZeros(address addr) internal pure returns (uint256 total) {
        assembly ("memory-safe") {
            total := iszero(byte(12, addr))
            total := add(total, iszero(byte(13, addr)))
            total := add(total, iszero(byte(14, addr)))
            total := add(total, iszero(byte(15, addr)))
            total := add(total, iszero(byte(16, addr)))
            total := add(total, iszero(byte(17, addr)))
            total := add(total, iszero(byte(18, addr)))
            total := add(total, iszero(byte(19, addr)))
            total := add(total, iszero(byte(20, addr)))
            total := add(total, iszero(byte(21, addr)))
            total := add(total, iszero(byte(22, addr)))
            total := add(total, iszero(byte(23, addr)))
            total := add(total, iszero(byte(24, addr)))
            total := add(total, iszero(byte(25, addr)))
            total := add(total, iszero(byte(26, addr)))
            total := add(total, iszero(byte(27, addr)))
            total := add(total, iszero(byte(28, addr)))
            total := add(total, iszero(byte(29, addr)))
            total := add(total, iszero(byte(30, addr)))
            total := add(total, iszero(byte(31, addr)))
        }
    }
}
