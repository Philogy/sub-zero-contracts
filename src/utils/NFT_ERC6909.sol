// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @notice Simple EIP-6909 for IDs that are solely non-fungible.
/// @author Forked from Solady (https://github.com/vectorized/solady/blob/main/src/tokens/ERC6909.sol)
/// @author philogy <https://github.com/philogy>
///
/// @dev Note:
/// The ERC6909 standard allows minting and transferring to and from the zero address,
/// minting and transferring zero tokens, as well as self-approvals.
/// For performance, this implementation WILL NOT revert for such actions.
/// Please add any checks with overrides if desired.
///
/// If you are overriding:
/// - Make sure all variables written to storage are properly cleaned
//    (e.g. the bool value for `isOperator` MUST be either 1 or 0 under the hood).
/// - Check that the overridden function is actually used in the function you want to
///   change the behavior of. Much of the code has been manually inlined for performance.
abstract contract NFT_ERC6909 {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       CUSTOM ERRORS                        */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Insufficient balance.
    error InsufficientBalance();

    /// @dev Insufficient permission to perform the action.
    error InsufficientPermission();

    /// @dev The balance has overflowed.
    error BalanceOverflow();

    /// @dev Minting Preexisting Token.
    error MintingPreexisting();

    /// @dev Burning Nonexistant Token.
    error BurningNonexistant();

    /// @dev Attempting to transfer token from non-owner
    error NotOwner();

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                           EVENTS                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Emitted when `by` transfers `amount` of token `id` from `from` to `to`.
    event Transfer(address by, address indexed from, address indexed to, uint256 indexed id, uint256 amount);

    /// @dev Emitted when `owner` enables or disables `operator` to manage all of their tokens.
    event OperatorSet(address indexed owner, address indexed operator, bool approved);

    /// @dev Emitted when `owner` approves `spender` to use `amount` of `id` token.
    event Approval(address indexed owner, address indexed spender, uint256 indexed id, uint256 amount);

    /// @dev `keccak256(bytes("Transfer(address,address,address,uint256,uint256)"))`.
    uint256 private constant _TRANSFER_EVENT_SIGNATURE =
        0x1b3d7edb2e9c0b0e7c525b20aaaef0f5940d2ed71663c7d39266ecafac728859;

    /// @dev `keccak256(bytes("OperatorSet(address,address,bool)"))`.
    uint256 private constant _OPERATOR_SET_EVENT_SIGNATURE =
        0xceb576d9f15e4e200fdb5096d64d5dfd667e16def20c1eefd14256d8e3faa267;

    /// @dev `keccak256(bytes("Approval(address,address,uint256,uint256)"))`.
    uint256 private constant _APPROVAL_EVENT_SIGNATURE =
        0xb3fd5071835887567a0671151121894ddccc2842f1d10bedad13e0d17cace9a7;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                          STORAGE                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev The owner slot for `id` is given by
    /// ```
    ///     mstore(0x04, masterSlot)
    ///     mstore(0x00, id)
    ///     let ownerSlot := keccak256(0x00, 0x24)
    /// ```
    ///
    /// The `ownerSlotSeed` is given by.
    /// ```
    ///     let ownerSlotSeed := or(_NFT_ERC6909_MASTER_SLOT_SEED, shl(96, owner))
    /// ```
    ///
    /// The operator approval slot of `owner` is given by.
    /// ```
    ///     mstore(0x20, ownerSlotSeed)
    ///     mstore(0x00, operator)
    ///     let operatorApprovalSlot := keccak256(0x0c, 0x34)
    /// ```
    ///
    /// The allowance slot of (`owner`, `spender`, `id`) is given by:
    /// ```
    ///     mstore(0x34, ownerSlotSeed)
    ///     mstore(0x14, spender)
    ///     mstore(0x00, id)
    ///     let allowanceSlot := keccak256(0x00, 0x54)
    /// ```
    ///
    /// The master slot constant is derived by keccak256("nft-erc6909.master-slot")[24:32]
    uint256 private constant _NFT_ERC6909_MASTER_SLOT_SEED = 0xab9ca135e8ac258f;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                      ERC6909 METADATA                      */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Returns the name for token `id`.
    function name(uint256 id) public view virtual returns (string memory);

    /// @dev Returns the symbol for token `id`.
    function symbol(uint256 id) public view virtual returns (string memory);

    /// @dev Returns the number of decimals for token `id`.
    /// Returns 18 by default.
    /// Please override this function if you need to return a custom value.
    function decimals(uint256) public pure returns (uint8) {
        return 0;
    }

    /// @dev Returns the Uniform Resource Identifier (URI) for token `id`.
    function tokenURI(uint256 id) public view virtual returns (string memory);

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                          ERC6909                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Returns the amount of token `id` owned by `owner`.
    function balanceOf(address owner, uint256 id) public view virtual returns (uint256 amount) {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x04, _NFT_ERC6909_MASTER_SLOT_SEED)
            mstore(0x00, id)
            let tokenOwner := sload(keccak256(0x00, 0x24))
            // 1 if owner == tokenOwner && owner != address(0) else 0
            amount := gt(eq(tokenOwner, owner), iszero(owner))
        }
    }

    function ownerOf(uint256 id) public view virtual returns (address owner) {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x04, _NFT_ERC6909_MASTER_SLOT_SEED)
            mstore(0x00, id)
            owner := sload(keccak256(0x00, 0x24))
        }
    }

    /// @dev Returns the amount of token `id` that `spender` can spend on behalf of `owner`.
    function allowance(address owner, address spender, uint256 id) public view virtual returns (uint256 amount) {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x34, _NFT_ERC6909_MASTER_SLOT_SEED)
            mstore(0x28, owner)
            mstore(0x14, spender)
            mstore(0x00, id)
            amount := sload(keccak256(0x00, 0x54))
            // Restore the part of the free memory pointer that has been overwritten.
            mstore(0x34, 0x00)
        }
    }

    /// @dev Checks if a `spender` is approved by `owner` to manage all of their tokens.
    function isOperator(address owner, address spender) public view virtual returns (bool status) {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x20, _NFT_ERC6909_MASTER_SLOT_SEED)
            mstore(0x14, owner)
            mstore(0x00, spender)
            status := sload(keccak256(0x0c, 0x34))
        }
    }

    /// @dev Transfers `amount` of token `id` from the caller to `to`.
    ///
    /// Requirements:
    /// - caller must at least have `amount`.
    ///
    /// Emits a {Transfer} event.
    function transfer(address to, uint256 id, uint256 amount) public payable virtual returns (bool) {
        _beforeTokenTransfer(msg.sender, to, id);
        /// @solidity memory-safe-assembly
        assembly {
            // Retrieve the owner.
            mstore(0x04, _NFT_ERC6909_MASTER_SLOT_SEED)
            mstore(0x00, id)
            let ownerSlot := keccak256(0x00, 0x24)
            let owner := sload(ownerSlot)
            // Revert if not owner or amount too high.
            let fromBalance := eq(caller(), owner)
            if gt(amount, fromBalance) {
                mstore(0x00, 0xf4d678b8) // `InsufficientBalance()`.
                revert(0x1c, 0x04)
            }
            if amount {
                // Update the owner.
                sstore(ownerSlot, to)
            }
            // Emit the {Transfer} event.
            mstore(0x00, caller())
            mstore(0x20, amount)
            log4(0x00, 0x40, _TRANSFER_EVENT_SIGNATURE, caller(), shr(96, shl(96, to)), id)
        }
        _afterTokenTransfer(msg.sender, to, id);
        return true;
    }

    /// @dev Transfers `amount` of token `id` from `from` to `to`.
    ///
    /// Note: Does not update the allowance if it is the maximum uint256 value.
    ///
    /// Requirements:
    /// - `from` must at least have `amount` of token `id`.
    /// -  The caller must have at least `amount` of allowance to transfer the
    ///    tokens of `from` or approved as an operator.
    ///
    /// Emits a {Transfer} event.
    function transferFrom(address from, address to, uint256 id, uint256 amount) public payable virtual returns (bool) {
        _beforeTokenTransfer(from, to, id);
        /// @solidity memory-safe-assembly
        assembly {
            // Compute the operator slot and load its value.
            mstore(0x34, _NFT_ERC6909_MASTER_SLOT_SEED)
            mstore(0x28, from)
            mstore(0x14, caller())
            // Check if the caller is an operator.
            if iszero(sload(keccak256(0x20, 0x34))) {
                // Compute the allowance slot and load its value.
                mstore(0x00, id)
                let allowanceSlot := keccak256(0x00, 0x54)
                let allowance_ := sload(allowanceSlot)
                // If the allowance is not above the maximum uint248 value.
                if iszero(byte(0, allowance_)) {
                    // Revert if the amount to be transferred exceeds the allowance.
                    if gt(amount, allowance_) {
                        mstore(0x00, 0xdeda9030) // `InsufficientPermission()`.
                        revert(0x1c, 0x04)
                    }
                    // Subtract and store the updated allowance.
                    sstore(allowanceSlot, sub(allowance_, amount))
                }
            }

            // Retrieve the owner.
            mstore(0x04, _NFT_ERC6909_MASTER_SLOT_SEED)
            mstore(0x00, id)
            let ownerSlot := keccak256(0x00, 0x24)
            let owner := sload(ownerSlot)
            // Revert if not owner or amount too high.
            let cleanFrom := shr(96, shl(96, from))
            // 1 if from is owner, 0 otherwise.
            let fromBalance := eq(cleanFrom, owner)
            if gt(amount, fromBalance) {
                mstore(0x00, 0xf4d678b8 /* InsufficientBalance() */ )
                revert(0x1c, 0x04)
            }
            let cleanTo := shr(96, shl(96, to))
            if amount {
                // Update the owner.
                sstore(ownerSlot, cleanTo)
            }
            // Emit the {Transfer} event.
            mstore(0x00, caller())
            mstore(0x20, amount)
            // forgefmt: disable-next-line
            log4(0x00, 0x40, _TRANSFER_EVENT_SIGNATURE, cleanFrom, cleanTo, id)
            // Restore the part of the free memory pointer that has been overwritten.
            mstore(0x34, 0x00)
        }
        _afterTokenTransfer(from, to, id);
        return true;
    }

    /// @dev Sets `amount` as the allowance of `spender` for the caller for token `id`.
    ///
    /// Emits a {Approval} event.
    function approve(address spender, uint256 id, uint256 amount) public payable virtual returns (bool) {
        /// @solidity memory-safe-assembly
        assembly {
            // Compute the allowance slot and store the amount.
            mstore(0x34, _NFT_ERC6909_MASTER_SLOT_SEED)
            mstore(0x28, caller())
            mstore(0x14, spender)
            mstore(0x00, id)
            sstore(keccak256(0x00, 0x54), amount)
            // Emit the {Approval} event.
            mstore(0x00, amount)
            log4(0x00, 0x20, _APPROVAL_EVENT_SIGNATURE, caller(), shr(96, mload(0x20)), id)
            // Restore the part of the free memory pointer that has been overwritten.
            mstore(0x34, 0x00)
        }
        return true;
    }

    ///  @dev Sets whether `operator` is approved to manage the tokens of the caller.
    ///
    /// Emits {OperatorSet} event.
    function setOperator(address operator, bool approved) public payable virtual returns (bool) {
        /// @solidity memory-safe-assembly
        assembly {
            // Convert `approved` to `0` or `1`.
            let approvedCleaned := iszero(iszero(approved))
            // Compute the operator slot and store the approved.
            mstore(0x20, _NFT_ERC6909_MASTER_SLOT_SEED)
            mstore(0x14, caller())
            mstore(0x00, operator)
            sstore(keccak256(0x0c, 0x34), approvedCleaned)
            // Emit the {OperatorSet} event.
            mstore(0x20, approvedCleaned)
            log3(0x20, 0x20, _OPERATOR_SET_EVENT_SIGNATURE, caller(), shr(96, mload(0x0c)))
        }
        return true;
    }

    /// @dev Returns true if this contract implements the interface defined by `interfaceId`.
    function supportsInterface(bytes4 interfaceId) public view virtual returns (bool result) {
        /// @solidity memory-safe-assembly
        assembly {
            let s := shr(224, interfaceId)
            // ERC165: 0x01ffc9a7, ERC6909: 0x0f632fb3.
            result := or(eq(s, 0x01ffc9a7), eq(s, 0x0f632fb3))
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                     INTERNAL FUNCTIONS                     */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Mints `amount` of token `id` to `to`.
    ///
    /// Emits a {Transfer} event.
    function _mint(address to, uint256 id) internal virtual {
        _beforeTokenTransfer(address(0), to, id);
        /// @solidity memory-safe-assembly
        assembly {
            // Compute owner slot.
            mstore(0x04, _NFT_ERC6909_MASTER_SLOT_SEED)
            mstore(0x00, id)
            let ownerSlot := keccak256(0x00, 0x24)
            // Check for existing owner.
            if sload(ownerSlot) {
                mstore(0x00, 0xd991bf83 /* MintingPreexisting() */ )
                revert(0x1c, 0x04)
            }
            let cleanTo := shr(96, shl(96, to))
            sstore(ownerSlot, cleanTo)
            // Emit the {Transfer} event.
            mstore(0x00, caller())
            mstore(0x20, 1)
            log4(0x00, 0x40, _TRANSFER_EVENT_SIGNATURE, 0, cleanTo, id)
        }
        _afterTokenTransfer(address(0), to, id);
    }

    /// @dev Burns `amount` token `id` from `from`.
    ///
    /// Emits a {Transfer} event.
    function _burn(uint256 id) internal virtual {
        bytes32 ownerSlot;
        address from;
        /// @solidity memory-safe-assembly
        assembly {
            // Compute owner slot.
            mstore(0x04, _NFT_ERC6909_MASTER_SLOT_SEED)
            mstore(0x00, id)
            ownerSlot := keccak256(0x00, 0x24)
            // Check if token exists.
            from := sload(ownerSlot)
            if iszero(from) {
                mstore(0x00, 0xc3e5fe70 /* BurningNonexistant() */ )
                revert(0x1c, 0x04)
            }
        }
        _beforeTokenTransfer(from, address(0), id);
        /// @solidity memory-safe-assembly
        assembly {
            sstore(ownerSlot, 0)
            // Emit the {Transfer} event.
            mstore(0x00, caller())
            mstore(0x20, 1)
            log4(0x00, 0x40, _TRANSFER_EVENT_SIGNATURE, from, 0, id)
        }
        _afterTokenTransfer(from, address(0), id);
    }

    /// @dev Transfers `amount` of token `id` from `from` to `to`.
    ///
    /// Note: Does not update the allowance if it is the maximum uint256 value.
    ///
    /// Requirements:
    /// - `from` must at least have `amount` of token `id`.
    /// - If `by` is not the zero address,
    ///   it must have at least `amount` of allowance to transfer the
    ///   tokens of `from` or approved as an operator.
    ///
    /// Emits a {Transfer} event.
    function _transfer(address by, address from, address to, uint256 id) internal virtual {
        _beforeTokenTransfer(from, to, id);
        /// @solidity memory-safe-assembly
        assembly {
            let bitmaskAddress := 0xffffffffffffffffffffffffffffffffffffffff
            // Compute the operator slot and load its value.
            mstore(0x34, _NFT_ERC6909_MASTER_SLOT_SEED)
            mstore(0x28, from)
            // If `by` is not the zero address.
            let cleanBy := and(bitmaskAddress, by)
            if cleanBy {
                mstore(0x14, by)
                // Check if the `by` is an operator.
                if iszero(sload(keccak256(0x20, 0x34))) {
                    // Compute the allowance slot and load its value.
                    mstore(0x00, id)
                    let allowanceSlot := keccak256(0x00, 0x54)
                    let allowance_ := sload(allowanceSlot)
                    // If the allowance is not above the maximum uint248 value.
                    if iszero(byte(0, allowance_)) {
                        // Revert if the amount to be transferred exceeds the allowance.
                        if iszero(allowance_) {
                            mstore(0x00, 0xdeda9030) // `InsufficientPermission()`.
                            revert(0x1c, 0x04)
                        }
                        // Subtract and store the updated allowance.
                        sstore(allowanceSlot, sub(allowance_, 1))
                    }
                }
            }
            // Retrieve the owner.
            mstore(0x04, _NFT_ERC6909_MASTER_SLOT_SEED)
            mstore(0x00, id)
            let ownerSlot := keccak256(0x00, 0x24)
            let owner := sload(ownerSlot)
            // Revert if not owner or amount too high.
            let cleanFrom := and(bitmaskAddress, from)
            if iszero(eq(cleanFrom, owner)) {
                mstore(0x00, 0x30cd7471 /* NotOwner() */ )
                revert(0x1c, 0x04)
            }
            // Update the owner.
            let cleanTo := and(to, bitmaskAddress)
            sstore(ownerSlot, to)
            // Emit the {Transfer} event.
            mstore(0x00, cleanBy)
            mstore(0x20, 1)
            // forgefmt: disable-next-line
            log4(0x00, 0x40, _TRANSFER_EVENT_SIGNATURE, cleanFrom, cleanTo, id)
            // Restore the part of the free memory pointer that has been overwritten.
            mstore(0x34, 0x00)
        }
        _afterTokenTransfer(from, to, id);
    }

    /// @dev Sets `amount` as the allowance of `spender` for `owner` for token `id`.
    ///
    /// Emits a {Approval} event.
    function _approve(address owner, address spender, uint256 id, uint256 amount) internal virtual {
        /// @solidity memory-safe-assembly
        assembly {
            // Compute the allowance slot and store the amount.
            mstore(0x34, _NFT_ERC6909_MASTER_SLOT_SEED)
            mstore(0x28, owner)
            mstore(0x14, spender)
            mstore(0x00, id)
            sstore(keccak256(0x00, 0x54), amount)
            // Emit the {Approval} event.
            mstore(0x00, amount)
            // forgefmt: disable-next-line
            log4(0x00, 0x20, _APPROVAL_EVENT_SIGNATURE, shr(96, mload(0x34)), shr(96, mload(0x20)), id)
            // Restore the part of the free memory pointer that has been overwritten.
            mstore(0x34, 0x00)
        }
    }

    ///  @dev Sets whether `operator` is approved to manage the tokens of `owner`.
    ///
    /// Emits {OperatorSet} event.
    function _setOperator(address owner, address operator, bool approved) internal virtual {
        /// @solidity memory-safe-assembly
        assembly {
            // Convert `approved` to `0` or `1`.
            let approvedCleaned := iszero(iszero(approved))
            // Compute the operator slot and store the approved.
            mstore(0x20, _NFT_ERC6909_MASTER_SLOT_SEED)
            mstore(0x14, owner)
            mstore(0x00, operator)
            sstore(keccak256(0x0c, 0x34), approvedCleaned)
            // Emit the {OperatorSet} event.
            mstore(0x20, approvedCleaned)
            // forgefmt: disable-next-line
            log3(0x20, 0x20, _OPERATOR_SET_EVENT_SIGNATURE, shr(96, shl(96, owner)), shr(96, mload(0x0c)))
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                     HOOKS TO OVERRIDE                      */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Hook that is called before any transfer of tokens.
    /// This includes minting and burning.
    function _beforeTokenTransfer(address from, address to, uint256 id) internal virtual {}

    /// @dev Hook that is called after any transfer of tokens.
    /// This includes minting and burning.
    function _afterTokenTransfer(address from, address to, uint256 id) internal virtual {}
}
