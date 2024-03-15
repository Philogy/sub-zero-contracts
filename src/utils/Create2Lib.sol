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
}
