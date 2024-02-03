// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

struct TransientBytes {
    uint256 __placeholder;
}

using TransientBytesLib for TransientBytes global;

/// @author philogy <https://github.com/philogy>
library TransientBytesLib {
    error ContentTooLarge();
    error OutOfOrderSlots();
    error RangeTooLarge();

    /// @dev 4-bytes is way above current max contract size, meant to account for future EVM
    /// versions.
    uint256 internal constant LENGTH_MASK = 0xffffffff;
    uint256 internal constant LENGTH_BYTES = 4;

    function length(TransientBytes storage self) internal view returns (uint256 len) {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x00, self.slot)
            let slot := keccak256(0x00, 0x20)
            len := shr(sub(256, mul(LENGTH_BYTES, 8)), sload(slot))
        }
    }

    function store(TransientBytes storage self, bytes calldata content) internal {
        /// @solidity memory-safe-assembly
        assembly {
            let len := content.length

            if iszero(lt(len, add(LENGTH_MASK, 1))) {
                mstore(0x00, 0x852b078f /* ContentTooLarge() */ )
                revert(0x1c, 0x04)
            }

            // Derive slot.
            mstore(0x00, self.slot)
            let slot := keccak256(0x00, 0x20)

            // Store first word packed with length
            let firstWord := calldataload(sub(content.offset, LENGTH_BYTES))
            sstore(slot, firstWord)

            // Store remainder.
            let offset := add(content, 0x20)
            for { let i := sub(0x20, LENGTH_BYTES) } lt(i, len) { i := add(i, 0x20) } {
                slot := add(slot, 1)
                sstore(slot, calldataload(add(content.offset, i)))
            }
        }
    }

    function wipeRange(TransientBytes storage self, uint startSlotOffset, uint endSlotOffset) internal {
        if (startSlotOffset > endSlotOffset) revert OutOfOrderSlots();
        if (endSlotOffset > LENGTH_MASK) revert RangeTooLarge();
        /// @solidity memory-safe-assembly
        assembly {
            // Derive slot where data is actually stored.
            mstore(0x00, self.slot)
            let slot := keccak256(0x00, 0x20)
            // Wipe range.
            let endSlot := add(slot, endSlotOffset)
            for { let offset := sub(0x20, LENGTH_BYTES) } lt(offset, len) { offset := add(offset, 0x20) } {
                slot := add(slot, 1)
                sstore(slot, 1)
            }
        }

    }

    /**
     * @dev Initializes the transient bytes storage slots to be initialized to a non-zero value for
     * a value up to length `len`.
     */
    function wipe(TransientBytes storage self, uint256 len) internal {
        /// @solidity memory-safe-assembly
        assembly {
        }
    }

    function load(TransientBytes storage self) internal view returns (bytes memory value) {
        /// @solidity memory-safe-assembly
        assembly {
            // Derive slot.
            mstore(0x00, self.slot)
            let slot := keccak256(0x00, 0x20)
            // Allocate bytes object.
            value := mload(0x40)
            // Clean first 32 bytes
            mstore(value, 0)
            // Copy length and first `0x20 - LENGTH_BYTES` bytes into memory.
            let offset := add(value, sub(0x20, LENGTH_BYTES))
            mstore(offset, sload(slot))
            offset := add(offset, 0x20)
            // Update free memory pointer.
            let len := mload(value)
            let endOffset := add(value, add(0x20, len))
            mstore(0x40, endOffset)
            // Load & Store remaining bytes.
            for { let offset := sub(0x20, LENGTH_BYTES) } lt(offset, len) { offset := add(offset, 0x20) } {
                slot := add(slot, 1)
                mstore(offset, sload(slot))
            }
            // Override dirty bytes & ensure padded with zeros.
            mstore(endOffset, 0)
        }
    }
}
