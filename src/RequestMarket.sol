// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ISubZeroVanityMarket} from "./interfaces/ISubZeroVanityMarket.sol";
import {Create2Lib} from "./utils/Create2Lib.sol";
import {LibRLP} from "solady/src/utils/LibRLP.sol";
import {LibString} from "solady/src/utils/LibString.sol";
import {Ownable} from "solady/src/auth/Ownable.sol";
import {SafeTransferLib} from "solady/src/utils/SafeTransferLib.sol";

import {console} from "forge-std/console.sol";

/// @author philogy <https://github.com/philogy>
contract RequestMarket is Ownable {
    using SafeTransferLib for address;

    struct RequestState {
        uint64 initiated_refund_at;
        uint128 reward;
    }

    event NewRequest();

    ISubZeroVanityMarket internal constant VANITY_MARKET =
        ISubZeroVanityMarket(0x000000000000b361194cfe6312EE3210d53C15AA);
    bytes32 internal constant DEPLOY_PROXY_INITHASH = 0x1decbcf04b355d500cbc3bd83c892545b4df34bd5b2c9d91b9f7f8165e2095c3;
    uint256 internal constant MAX_UNLOCK_DELAY = 365 days;
    uint64 internal constant REQUEST_LOCKED = type(uint64).max;
    uint256 internal constant _REQUEST_STATE_SLOT = 0x1407025b;

    error UnlockDelayAboveMax();
    error EmptyRequest();
    error RequestNotSatisfied();
    error RequestMissingOrNotLocked();
    error RefundStillInProgress();

    uint256 internal claimable_eth;

    constructor(address initialOwner) {
        _initializeOwner(initialOwner);
    }

    function claim_eth() external {
        uint256 amount = claimable_eth;
        claimable_eth = 0;
        msg.sender.safeTransferETH(amount);
    }

    function request(uint32 unlock_delay, uint160 address_mask, uint160 address_target, uint80 capitalization_map)
        external
        payable
    {
        if (unlock_delay > MAX_UNLOCK_DELAY) revert UnlockDelayAboveMax();
        RequestState storage state =
            _request_state(msg.sender, unlock_delay, address_mask, address_target, capitalization_map);
        state.reward += uint128(msg.value);
        state.initiated_refund_at = REQUEST_LOCKED;

        // TODO: event
    }

    function fulfill(
        address owner,
        uint32 unlock_delay,
        uint160 address_mask,
        uint160 address_target,
        uint80 capitalization_map,
        uint256 id,
        uint8 nonce
    ) external {
        RequestState storage state =
            _request_state(owner, unlock_delay, address_mask, address_target, capitalization_map);
        uint256 reward = state.reward;
        if (reward == 0) revert EmptyRequest();
        address addr = _compute_address(bytes32(id), nonce);
        if (!_satisfies_request(addr, address_mask, address_target, capitalization_map)) revert RequestNotSatisfied();
        unchecked {
            claimable_eth += reward;
        }
        _delete(state);

        // TODO: event

        VANITY_MARKET.mint(owner, id, nonce);
    }

    function initiate_refund(
        uint32 unlock_delay,
        uint160 address_mask,
        uint160 address_target,
        uint80 capitalization_map
    ) external {
        RequestState storage state =
            _request_state(msg.sender, unlock_delay, address_mask, address_target, capitalization_map);
        if (state.initiated_refund_at != REQUEST_LOCKED) revert RequestMissingOrNotLocked();
        state.initiated_refund_at = uint64(block.timestamp);

        // TODO: event
    }

    function complete_refund(
        uint32 unlock_delay,
        uint160 address_mask,
        uint160 address_target,
        uint80 capitalization_map
    ) external {
        RequestState storage state =
            _request_state(msg.sender, unlock_delay, address_mask, address_target, capitalization_map);
        uint256 initiated_refund_at = state.initiated_refund_at;
        uint256 reward = state.reward;
        if (initiated_refund_at == 0) revert EmptyRequest();
        if (!(block.timestamp <= initiated_refund_at + unlock_delay)) revert RefundStillInProgress();
        _delete(state);

        // TODO: event

        msg.sender.safeTransferETH(reward);
    }

    function _request_state(
        address owner,
        uint32 unlock_delay,
        uint160 address_mask,
        uint160 address_target,
        uint80 capitalization_map
    ) internal pure returns (RequestState storage state) {
        assembly ("memory-safe") {
            let fmp := mload(0x40)
            mstore(64, _REQUEST_STATE_SLOT)
            mstore(60, capitalization_map)
            mstore(50, address_target)
            mstore(30, address_mask)
            mstore(10, unlock_delay)
            mstore(6, owner)
            state.slot := keccak256(18, 78)
            mstore(0x40, fmp)
        }
    }

    function _delete(RequestState storage state) internal {
        assembly {
            sstore(state.slot, 0)
        }
    }

    function _id(RequestState storage state) internal pure returns (uint256 id) {
        assembly {
            id := state.slot
        }
    }

    uint256 internal constant HEX_ALPHABET = 0x3031323334353637383961626364656600000000000000000000000000000000;
    uint256 internal constant UPPER_MAP_MASK = 0x001111111111111111111111111111111111111111;
    uint256 internal constant CAP_MAP_MASK = 0x55555555555555555555;

    function _satisfies_request(
        address to_be_minted,
        uint160 address_mask,
        uint160 address_target,
        uint80 capitalization_map
    ) internal pure returns (bool) {
        if (uint160(to_be_minted) & address_mask != address_target) return false;
        if (capitalization_map == 0) return true;

        uint256 checksum_hash;
        assembly ("memory-safe") {
            let addr := shl(96, to_be_minted)
            for { let i := 0 } 1 {} {
                let b := byte(shr(1, i), addr)
                mstore8(i, byte(shr(4, b), HEX_ALPHABET))
                mstore8(add(i, 1), byte(and(0xf, b), HEX_ALPHABET))
                i := add(i, 2)
                if iszero(lt(i, 40)) { break }
            }

            checksum_hash := keccak256(0, 40)
        }
        // Build a map where every nibble tracks whether the letter is uppercase or not
        uint256 two_four_bits = uint256(uint160(to_be_minted)) & 0x006666666666666666666666666666666666666666;
        uint256 is_letter_map = uint256(uint160(to_be_minted)) & ((two_four_bits | (two_four_bits << 1)) << 1);
        // Map where each nibble tracks whether letter is uppercase
        uint256 is_upper_map = ((is_letter_map & (checksum_hash >> 96)) >> 3) & UPPER_MAP_MASK;

        // Fold upper map onto itself such that each nibble holds the upper info: | <i>  <i + 20> |
        is_upper_map = is_upper_map | (is_upper_map >> 78);

        return (is_upper_map & capitalization_map) ^ ((capitalization_map >> 1) & CAP_MAP_MASK) == 0;
    }

    function _compute_address(bytes32 salt, uint8 nonce) internal pure returns (address vanity) {
        address deployProxy = Create2Lib.predict(DEPLOY_PROXY_INITHASH, salt, address(VANITY_MARKET));
        vanity = LibRLP.computeAddress(deployProxy, nonce + 1);
    }
}
