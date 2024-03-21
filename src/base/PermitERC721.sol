// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.4;

import {ERC721} from "solady/src/tokens/ERC721.sol";
import {EIP712} from "solady/src/utils/EIP712.sol";
import {LibBitmap} from "solady/src/utils/LibBitmap.sol";

/// @author philogy <https://github.com/philogy>
abstract contract PermitERC721 is ERC721, EIP712 {
    using LibBitmap for LibBitmap.Bitmap;

    error NonceAlreadyUsed();

    mapping(address => LibBitmap.Bitmap) internal _nonces;

    function nonceSet(address user, uint256 nonce) external view returns (bool) {
        return _nonces[user].get(nonce);
    }

    function _useNonce(address user, uint256 nonce) internal {
        if (!_nonces[user].toggle(nonce)) revert NonceAlreadyUsed();
    }

    function _domainNameAndVersion() internal view override returns (string memory, string memory) {
        return (name(), _version());
    }

    function _version() internal view virtual returns (string memory) {
        return "1.0";
    }
}
