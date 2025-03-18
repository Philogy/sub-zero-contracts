// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ISubZeroVanityMarket} from "./interfaces/ISubZeroVanityMarket.sol";
import {Create2Lib} from "./utils/Create2Lib.sol";
import {LibRLP} from "solady/src/utils/LibRLP.sol";
import {Ownable} from "solady/src/auth/Ownable.sol";
import {SafeTransferLib} from "solady/src/utils/SafeTransferLib.sol";
import {SafeCastLib} from "solady/src/utils/SafeCastLib.sol";

/// @author philogy <https://github.com/philogy>
contract RequestMarket is Ownable {
    using SafeTransferLib for address;

    struct RequestState {
        uint64 initiated_refund_at;
        uint128 reward;
    }

    event NewRequest(
        uint256 packed_amount_owner,
        uint256 packed_address_mask_unlock_delay,
        uint256 packed_address_target_capitalization_map
    );
    event Fulfilled(bytes32 id);
    event RefundInitiated(bytes32 id);
    event RefundCompleted(bytes32 id);

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

    uint248 internal _claimable_eth;
    // @dev Intended to be packed into same slot with `_claimable_eth` and ensures that slot is
    // never set to 0 to ensure that fulfilling is always maximally cheap.
    uint8 internal _claimable_eth__padding = 1;

    constructor(address initialOwner) {
        _initializeOwner(initialOwner);
    }

    function claim_eth() external {
        _checkOwner();
        uint256 amount = claimable_eth();
        _claimable_eth = 0;
        msg.sender.safeTransferETH(amount);
    }

    function request(
        uint32 req_nonce,
        uint32 unlock_delay,
        uint160 address_mask,
        uint160 address_target,
        uint80 capitalization_map
    ) external payable {
        if (unlock_delay > MAX_UNLOCK_DELAY) revert UnlockDelayAboveMax();
        RequestState storage state =
            _request_state(msg.sender, req_nonce, unlock_delay, address_mask, address_target, capitalization_map);
        // If cast to `uint128` overflows later safe cast to uint96 will catch.
        state.reward += uint128(msg.value);
        state.initiated_refund_at = REQUEST_LOCKED;

        emit NewRequest(
            (uint256(uint160(msg.sender)) << 96) | SafeCastLib.toUint96(msg.value),
            (uint256(address_mask) << 96) | (uint256(req_nonce) << 32) | unlock_delay,
            (uint256(address_target) << 96) | capitalization_map
        );
    }

    function fulfill(
        address owner,
        uint32 req_nonce,
        uint32 unlock_delay,
        uint160 address_mask,
        uint160 address_target,
        uint80 capitalization_map,
        uint256 id,
        uint8 addr_nonce
    ) external {
        RequestState storage state =
            _request_state(owner, req_nonce, unlock_delay, address_mask, address_target, capitalization_map);
        uint248 reward = state.reward;
        if (reward == 0) revert EmptyRequest();
        address addr = _compute_address(bytes32(id), addr_nonce);
        if (!_satisfies_request(addr, address_mask, address_target, capitalization_map)) revert RequestNotSatisfied();

        _claimable_eth += reward;
        _delete(state);

        emit Fulfilled(_id(state));

        VANITY_MARKET.mint(owner, id, addr_nonce);
    }

    function initiate_refund(
        uint32 req_nonce,
        uint32 unlock_delay,
        uint160 address_mask,
        uint160 address_target,
        uint80 capitalization_map
    ) external {
        RequestState storage state =
            _request_state(msg.sender, req_nonce, unlock_delay, address_mask, address_target, capitalization_map);
        if (state.initiated_refund_at != REQUEST_LOCKED) revert RequestMissingOrNotLocked();
        state.initiated_refund_at = uint64(block.timestamp);

        emit RefundInitiated(_id(state));
    }

    /**
     * @dev Triggers a refund that's passed its unlock period, NOTE: until this is called the
     * request may still be filled.
     */
    function complete_refund(
        uint32 req_nonce,
        uint32 unlock_delay,
        uint160 address_mask,
        uint160 address_target,
        uint80 capitalization_map
    ) external {
        RequestState storage state =
            _request_state(msg.sender, req_nonce, unlock_delay, address_mask, address_target, capitalization_map);
        uint256 initiated_refund_at = state.initiated_refund_at;
        uint256 reward = state.reward;
        if (initiated_refund_at == 0) revert EmptyRequest();
        if (!(block.timestamp >= initiated_refund_at + unlock_delay)) revert RefundStillInProgress();
        _delete(state);

        emit RefundCompleted(_id(state));

        msg.sender.safeTransferETH(reward);
    }

    function claimable_eth() public view returns (uint256) {
        return _claimable_eth;
    }

    function get_request(
        address owner,
        uint32 req_nonce,
        uint32 unlock_delay,
        uint160 address_mask,
        uint160 address_target,
        uint80 capitalization_map
    ) public view returns (bytes32 id, RequestState memory loadedState) {
        RequestState storage state =
            _request_state(owner, req_nonce, unlock_delay, address_mask, address_target, capitalization_map);
        id = _id(state);
        loadedState = state;
    }

    function _request_state(
        address owner,
        uint32 req_nonce,
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
            mstore(6, req_nonce)
            mstore(2, owner)
            state.slot := keccak256(14, 82)
            mstore(0x40, fmp)
        }
    }

    function _delete(RequestState storage state) internal {
        assembly {
            sstore(state.slot, 0)
        }
    }

    function _id(RequestState storage state) internal pure returns (bytes32 id) {
        assembly {
            id := state.slot
        }
    }

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
            // Translate first 8/40 nibbles to ascii
            let alphabet := 0x3031323334353637383961626364656600000000000000000000000000000000
            mstore8(0, byte(and(shr(156, to_be_minted), 0xf), alphabet))
            mstore8(1, byte(and(shr(152, to_be_minted), 0xf), alphabet))
            mstore8(2, byte(and(shr(148, to_be_minted), 0xf), alphabet))
            mstore8(3, byte(and(shr(144, to_be_minted), 0xf), alphabet))
            mstore8(4, byte(and(shr(140, to_be_minted), 0xf), alphabet))
            mstore8(5, byte(and(shr(136, to_be_minted), 0xf), alphabet))
            mstore8(6, byte(and(shr(132, to_be_minted), 0xf), alphabet))
            mstore8(7, byte(and(shr(128, to_be_minted), 0xf), alphabet))

            // Spread remaining nibbles [8..40] into their own bytes.
            let w := to_be_minted
            w := or(shl(64, and(0xffffffffffffffff0000000000000000, w)), and(0xffffffffffffffff, w))
            w := and(0x00000000ffffffff00000000ffffffff00000000ffffffff00000000ffffffff, or(shl(32, w), w))
            w := and(0x0000ffff0000ffff0000ffff0000ffff0000ffff0000ffff0000ffff0000ffff, or(shl(16, w), w))
            w := and(0x00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff, or(shl(8, w), w))
            w :=
                or(
                    shl(4, and(w, 0xf0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0)),
                    and(w, 0x0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f)
                )

            /**
             * ## Determines which byte is going to be a letter (byte indexed).
             *
             * Looking at the hex alphabet and its bits:
             *
             *      |      Binary      |          ASCII Binary            |
             *  Hex |  b4  b3  b2  b1  |  a8  a7  a6  a5  b4  b3  b2  b1  |
             *  ===========================================================
             *  '0' |  0   0   0   0   |  0   0   1   1   0   0   0   0   |
             *  '1' |  0   0   0   1   |  0   0   1   1   0   0   0   1   |
             *  '2' |  0   0   1   0   |  0   0   1   1   0   0   1   0   |
             *  '3' |  0   0   1   1   |  0   0   1   1   0   0   1   1   |
             *  '4' |  0   1   0   0   |  0   0   1   1   0   1   0   0   |
             *  '5' |  0   1   0   1   |  0   0   1   1   0   1   0   1   |
             *  '6' |  0   1   1   0   |  0   0   1   1   0   1   1   0   |
             *  '7' |  0   1   1   1   |  0   0   1   1   0   1   1   1   |
             *  '8' |  1   0   0   0   |  0   0   1   1   1   0   0   0   |
             *  '9' |  1   0   0   1   |  0   0   1   1   1   0   0   1   |
             *  'a' |  1   0   1   0   |  0   1   1   0   0   0   0   1   |
             *  'b' |  1   0   1   1   |  0   1   1   0   0   0   1   0   |
             *  'c' |  1   1   0   0   |  0   1   1   0   0   0   1   1   |
             *  'd' |  1   1   0   1   |  0   1   1   0   0   1   0   0   |
             *  'e' |  1   1   1   0   |  0   1   1   0   0   1   0   1   |
             *  'f' |  1   1   1   1   |  0   1   1   0   0   1   1   0   |
             *
             * Notice how all letters, have b4 set to 1. However '8' & '9' also do. So to exclude
             * them we can simply check whether b3 or b2 is also set giving us the expression:
             * `b4 && (b3 || b2)`. We can compute this for all 32-bytes simultaneously by leveraging
             * a couple bit operations:
             */
            let letter_map :=
                and(
                    shr(3, and(w, shl(1, or(w, shl(1, w))))),
                    0x0101010101010101010101010101010101010101010101010101010101010101
                )

            /**
             * ## Convert the Bits into their Hex Representation in ASCII.
             *
             * Notice that from the alphabet, if we take the original binary as `x` we can convert
             * it to ASCII based on if it's a letter or not like this:
             *
             *           a8   a7   a6   a5   a4   a3   a2   a1
             * digit:     0    0    1    1   [       x       ]
             * letter:    0    1    1    0   [   8 ^ x - 1   ]
             *
             * Now we can achieve the above individually for either digits or letters using bit
             * operations but must do so conditionally for every byte. This is why we constructed
             * the letter bitmap, this let's us use it as a selector to conditionaly only apply
             * operations to bytes that are letters or not.
             */
            w :=
                sub(
                    xor(xor(w, 0x3030303030303030303030303030303030303030303030303030303030303030), mul(0x58, letter_map)),
                    letter_map
                )
            mstore(8, w)

            checksum_hash := keccak256(0, 40)
        }

        // We need to rebuild the `letter_map` but for the entire address & nibble-indexed.
        uint256 bits = uint256(uint160(to_be_minted));
        uint256 is_letter_map = bits & ((bits | (bits << 1)) << 1);
        // We now binary-AND that with the EIP-55 checksum to get a map of whether a digit is upper case.
        uint256 is_upper_map = ((is_letter_map & (checksum_hash >> 96)) >> 3) & UPPER_MAP_MASK;

        /**
         * ## Checking Capitalization against the map.
         *
         * The `capitalization_map` is an 80-bit map consisting 20x nibbles with each nibble
         * containing 2x 2-bit cells. The i-th nibble contains cells that check the capitalization
         * for the i-th and (i+20)-th letter in the address.
         *
         * Each 2-bit cell represents a capitalization pattern.
         *
         *   upper   active  |         meaning          |
         * ==============================================
         *     0       0     |       any character      |
         *     0       1     |  only lowercase / digit  |
         *     1       0     |      always invalid      |
         *     1       1     |      only uppercase      |
         *
         * Note: The `capitalization_map` cannot enforce something to be lowercase & a letter,
         * you can enforce your address to have a specific letter at a position via `address_mask` &
         * `address_target`.
         *
         * For each letter we can check whether it's capitalization is correct via the expression:
         * `(letter.isUpper() && active) == upper`. This is also by the pattern 0b10 is considered
         * "invalid" as it will always result in false.
         */

        // Fold upper map onto itself to create nibbles with 2x 2-bit cells following the
        // `capitalization_map` structure.
        is_upper_map = is_upper_map | (is_upper_map >> 78);
        return ((is_upper_map & capitalization_map) ^ (capitalization_map >> 1)) & CAP_MAP_MASK == 0;
    }

    function _compute_address(bytes32 salt, uint8 addr_nonce) internal pure returns (address vanity) {
        address deployProxy = Create2Lib.predict(DEPLOY_PROXY_INITHASH, salt, address(VANITY_MARKET));
        vanity = LibRLP.computeAddress(deployProxy, addr_nonce + 1);
    }
}
