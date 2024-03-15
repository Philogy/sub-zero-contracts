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
        assembly ("memory-safe") {
            mstore(0x00, self.slot)
            let slot := keccak256(0x00, 0x20)
            len := shr(sub(256, mul(LENGTH_BYTES, 8)), sload(slot))
        }
    }

    function store(TransientBytes storage self, bytes calldata content) internal {
        assembly ("memory-safe") {
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
            for { let i := sub(0x20, LENGTH_BYTES) } lt(i, len) { i := add(i, 0x20) } {
                slot := add(slot, 1)
                sstore(slot, calldataload(add(content.offset, i)))
            }
        }
    }

    function reset(TransientBytes storage self) internal {
        uint256 len = self.length();
        uint256 slotsToWipe = 1 + (len - (32 - LENGTH_BYTES) + 31) / 32;
        self.wipeRange(0, slotsToWipe);
    }

    function wipeRange(TransientBytes storage self, uint256 startSlotOffset, uint256 endSlotOffset) internal {
        if (startSlotOffset > endSlotOffset) revert OutOfOrderSlots();
        if (endSlotOffset > LENGTH_MASK) revert RangeTooLarge();
        assembly ("memory-safe") {
            // Derive slot where data is actually stored.
            mstore(0x00, self.slot)
            let slot := keccak256(0x00, 0x20)
            // Wipe range.
            for {
                let currentSlot := add(slot, startSlotOffset)
                let endSlot := add(slot, endSlotOffset)
            } lt(currentSlot, endSlot) { currentSlot := add(currentSlot, 1) } { sstore(currentSlot, 1) }
        }
    }

    function load(TransientBytes storage self) internal view returns (bytes memory value) {
        assembly ("memory-safe") {
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
            for {} lt(offset, endOffset) { offset := add(offset, 0x20) } {
                slot := add(slot, 1)
                mstore(offset, sload(slot))
            }
        }
    }
}
