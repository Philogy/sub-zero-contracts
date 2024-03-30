// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.4;

import {ERC721} from "solady/src/tokens/ERC721.sol";
import {EIP712} from "solady/src/utils/EIP712.sol";
import {LibBitmap} from "solady/src/utils/LibBitmap.sol";
import {SignatureCheckerLib} from "solady/src/utils/SignatureCheckerLib.sol";

/// @author philogy <https://github.com/philogy>
abstract contract PermitERC721 is ERC721, EIP712 {
    using LibBitmap for LibBitmap.Bitmap;

    error NonceAlreadyUsed();
    error PastDeadline();
    error InvalidSignature();

    /// @dev Copied from Solady as it's private.
    uint256 private constant _ERC721_MASTER_SLOT_SEED_MASKED = 0x0a5a2e7a00000000;
    /// @dev `keccak256(bytes("ApprovalForAll(address,address,bool)"))`.
    uint256 private constant _APPROVAL_FOR_ALL_EVENT_SIGNATURE =
        0x17307eab39ab6107e8899845ad3d59bd9653f200f220920489ca2b5937696c31;

    bytes32 internal immutable PERMIT_FOR_ALL_TYPEHASH =
        keccak256("PermitForAll(address owner,address operator,uint256 nonce,uint256 deadline)");

    mapping(address => LibBitmap.Bitmap) internal _nonces;

    function permitForAll(address owner, address operator, uint256 nonce, uint256 deadline, bytes calldata signature)
        external
    {
        _checkDeadline(deadline);
        _checkAndUseNonce(owner, nonce);
        bytes32 hash = _hashTypedData(keccak256(abi.encode(PERMIT_FOR_ALL_TYPEHASH, owner, operator, nonce, deadline)));
        _checkSignature(owner, hash, signature);
        _setIsApprovedForAll(owner, operator, true);
    }

    function invalidateNonce(uint256 nonce) external {
        _checkAndUseNonce(msg.sender, nonce);
    }

    function getNonceIsSet(address user, uint256 nonce) external view returns (bool) {
        return _nonces[user].get(nonce);
    }

    function _checkAndUseNonce(address user, uint256 nonce) internal {
        if (!_nonces[user].toggle(nonce)) revert NonceAlreadyUsed();
    }

    function _domainNameAndVersion() internal view override returns (string memory, string memory) {
        return (name(), _version());
    }

    function _version() internal view virtual returns (string memory) {
        return "1.0";
    }

    function _checkDeadline(uint256 deadline) internal view {
        if (block.timestamp > deadline) revert PastDeadline();
    }

    function _checkSignature(address signer, bytes32 hash, bytes calldata signature) internal view {
        if (!SignatureCheckerLib.isValidSignatureNowCalldata(signer, hash, signature)) revert InvalidSignature();
    }

    /// @dev Reference: Solady's `ERC721.setApprovalForAll`.
    function _setIsApprovedForAll(address owner, address operator, bool approved) internal {
        // Set `isApprovedForAll(owner, operator) == approved`.
        assembly ("memory-safe") {
            // Update the `isApproved` for (`msg.sender`, `operator`).
            mstore(0x1c, operator)
            mstore(0x08, _ERC721_MASTER_SLOT_SEED_MASKED)
            mstore(0x00, owner)
            sstore(keccak256(0x0c, 0x30), iszero(iszero(approved)))
            // Emit the {ApprovalForAll} event.
            mstore(0x00, true)
            // forgefmt: disable-next-item
            log3(0x00, 0x20, _APPROVAL_FOR_ALL_EVENT_SIGNATURE, caller(), shr(96, shl(96, operator)))
        }
    }
}
