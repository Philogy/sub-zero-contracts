// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @author philogy <https://github.com/philogy>
library BytesLib {
    function directReturn(bytes memory data) internal pure {
        /// @solidity memory-safe-assembly
        assembly {
            return(add(data, 0x20), mload(data))
        }
    }

    /**
     * @dev Decodes an ABI-encoded (bytes) e.g. the result of `abi.encode(data: bytes)`.
     */
    function decodeBytes(bytes memory encodedBytes) internal pure returns (bytes memory decoded) {
        /// @solidity memory-safe-assembly
        assembly {
            let dataOffset := add(encodedBytes, 0x20)
            let decodedRelativeOffseet := mload(dataOffset)
            decoded := add(dataOffset, decodedRelativeOffseet)
        }
    }
}
