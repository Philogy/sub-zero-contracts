// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.4;

import {ERC721} from "solady/src/tokens/ERC721.sol";
import {EIP712} from "solady/src/utils/EIP712.sol";
import {LibBitmap} from "solady/src/utils/LibBitmap.sol";
import {SignatureCheckerLib} from "solady/src/utils/SignatureCheckerLib.sol";

/**
 * @author philogy <https://github.com/philogy>
 * @dev Base extension of ERC721 that adds EIP712, nonce checking and gasless permits.
 */
abstract contract PermitERC721 is ERC721, EIP712 {
    using LibBitmap for LibBitmap.Bitmap;

    error NonceAlreadyInvalidated();
    error PastDeadline();
    error InvalidSignature();

    bytes32 internal immutable PERMIT_FOR_ALL_TYPEHASH =
        keccak256("PermitForAll(address operator,uint256 nonce,uint256 deadline)");

    mapping(address => LibBitmap.Bitmap) internal _nonces;

    /**
     * @dev Allows setting the ERC721 universal operator permission (`isApprovedForAll`) via
     * a separately provided signature.
     * @param owner The permission granter and expected signer.
     * @param operator The grantee to become a new universal ERC721 operator.
     */
    function permitForAll(address owner, address operator, uint256 nonce, uint256 deadline, bytes calldata signature)
        external
    {
        _checkDeadline(deadline);
        bytes32 hash = _hashTypedData(keccak256(abi.encode(PERMIT_FOR_ALL_TYPEHASH, operator, nonce, deadline)));
        _checkSignature(owner, hash, signature);
        _checkAndUseNonce(owner, nonce);
        _setApprovalForAll(owner, operator, true);
    }

    function invalidateNonce(uint256 nonce) external {
        _nonces[msg.sender].set(nonce);
    }

    function getNonceIsSet(address user, uint256 nonce) external view returns (bool) {
        return _nonces[user].get(nonce);
    }

    function _checkAndUseNonce(address user, uint256 nonce) internal {
        if (!_nonces[user].toggle(nonce)) revert NonceAlreadyInvalidated();
    }

    function DOMAIN_SEPARATOR() external view returns (bytes32) {
        return _domainSeparator();
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
}
