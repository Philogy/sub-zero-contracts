// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/**
 * @notice Contract for ERC-712 typed structured data hashing and signing.
 * @author Modified from Solady (https://github.com/vectorized/solady/blob/main/src/utils/EIP712.sol)
 *
 * @dev Note, this implementation:
 * - Uses `address(this)` for the `verifyingContract` field.
 * - Does NOT use the optional ERC-712 salt.
 * - Does NOT use any ERC-712 extensions.
 * - Will revert if the chain ID changes or is DELEGATECALL-ed to.
 * - Has secondary chain ID agnostic domain.
 * This is for simplicity and to save gas.
 */
abstract contract ERC712 {
    error DomainSeparatorsInvalidated();

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                  CONSTANTS AND IMMUTABLES                  */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev `keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)")`.
    bytes32 internal constant _FULL_DOMAIN_TYPEHASH = 0x8b73c3c69bb8fe3d512ecc4cf759cc79239f7b179b0ffacaa9a75d522b39400f;

    /// @dev `keccak256("EIP712Domain(string name,string version,address verifyingContract)")`.
    bytes32 internal constant _AGNOSTIC_DOMAIN_TYPEHASH =
        0x91ab3d17e3a50a9d89e63fd30b92be7f5336b03b287bb946787a83a9d62a2766;

    uint256 private immutable _cachedThis;
    uint256 private immutable _cachedChainId;
    bytes32 private immutable _cachedNameHash;
    bytes32 private immutable _cachedVersionHash;
    bytes32 public immutable FULL_DOMAIN_SEPARATOR;
    bytes32 public immutable CROSS_CHAIN_DOMAIN_SEPARATOR;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                        CONSTRUCTOR                         */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Cache the hashes for cheaper runtime gas costs.
    /// In the case of upgradeable contracts (i.e. proxies),
    /// or if the chain id changes due to a hard fork,
    /// the domain separator will be seamlessly calculated on-the-fly.
    constructor() {
        _cachedThis = uint256(uint160(address(this)));
        _cachedChainId = block.chainid;

        (string memory name, string memory version) = _domainNameAndVersion();
        bytes32 nameHash = keccak256(bytes(name));
        bytes32 versionHash = keccak256(bytes(version));
        _cachedNameHash = nameHash;
        _cachedVersionHash = versionHash;

        bytes32 fullSeparator;
        bytes32 agnosticSeparator;
        assembly ("memory-safe") {
            let m := mload(0x40) // Load the free memory pointer.
            mstore(m, _AGNOSTIC_DOMAIN_TYPEHASH)
            mstore(add(m, 0x20), nameHash)
            mstore(add(m, 0x40), versionHash)
            mstore(add(m, 0x60), address())
            agnosticSeparator := keccak256(m, 0x80)

            // The agnostic and full domain share the first 2 fields so we can reuse some memory.
            mstore(m, _FULL_DOMAIN_TYPEHASH)
            mstore(add(m, 0x60), chainid())
            mstore(add(m, 0x80), address())
            fullSeparator := keccak256(m, 0xa0)
        }
        FULL_DOMAIN_SEPARATOR = fullSeparator;
        CROSS_CHAIN_DOMAIN_SEPARATOR = agnosticSeparator;
    }

    /// @dev Override to return unchanging `name` and `version ` string.
    function _domainNameAndVersion() internal pure virtual returns (string memory name, string memory version);

    /**
     * @dev Returns the hash of the fully encoded ERC-712 message for this domain,
     * given `structHash`, as defined in https://eips.ethereum.org/EIPS/eip-712#definition-of-hashstruct.
     * Includes cross-chain replay protection by using the chain-specific domain separator.
     */
    function _hashTypedData(bytes32 structHash) internal view virtual returns (bytes32) {
        if (!_domainSeparatorsValid()) revert DomainSeparatorsInvalidated();
        return _computeDigest(FULL_DOMAIN_SEPARATOR, structHash);
    }

    /**
     * @dev Returns the hash of the encoded ERC-712 message, **excluding** chain ID from the domain,
     * meaning messages signed this way *can* be replayed across deployed contracts, make sure this
     * is desirable.
     */
    function _hashCrossChainData(bytes32 structHash) internal view virtual returns (bytes32) {
        if (!_domainSeparatorsValid()) revert DomainSeparatorsInvalidated();
        return _computeDigest(CROSS_CHAIN_DOMAIN_SEPARATOR, structHash);
    }

    /// @dev Returns if the cached domain separator has been invalidated.
    function _domainSeparatorsValid() internal view returns (bool result) {
        uint256 cachedChainId = _cachedChainId;
        uint256 cachedThis = _cachedThis;
        assembly ("memory-safe") {
            result := and(eq(chainid(), cachedChainId), eq(address(), cachedThis))
        }
    }

    function _computeDigest(bytes32 separator, bytes32 structHash) internal pure returns (bytes32 digest) {
        assembly ("memory-safe") {
            // Compute the digest.
            mstore(0x00, 0x1901000000000000) // Store "\x19\x01".
            mstore(0x1a, separator) // Store the domain separator.
            mstore(0x3a, structHash) // Store the struct hash.
            digest := keccak256(0x18, 0x42)
            // Restore the part of the free memory slot that was overwritten.
            mstore(0x3a, 0)
        }
    }
}
