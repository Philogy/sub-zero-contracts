// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {RequestMarket} from "../src/RequestMarket.sol";

import {Test} from "forge-std/Test.sol";
import {HuffTest} from "./base/HuffTest.sol";
import {ICreate3RequestMarket} from "../src/interfaces/ICreate3RequestMarket.sol";
import {VanityMarket} from "src/VanityMarket.sol";
import {LibString} from "solady/src/utils/LibString.sol";
import {Brutalizer} from "solady/test/utils/Brutalizer.sol";

import {console} from "forge-std/console.sol";

/// @author philogy <https://github.com/philogy>
contract RequestMarketTest is Test, HuffTest, RequestMarket(address(0)), Brutalizer {
    VanityMarket constant MARKET = VanityMarket(payable(0x000000000000b361194cfe6312EE3210d53C15AA));
    address market_owner = 0xea57c1ef7eF1c88b456ADf0927ec0EAe3B17f1F5;

    address fulfiller = makeAddr("fulfiller");
    address request_owner = makeAddr("request_owner");
    RequestMarket request_market;

    function setUp() public {
        setupBase_ffi();

        if (address(VANITY_MARKET).code.length == 0) {
            deployCodeTo("VanityMarket.sol", abi.encode(market_owner), address(VANITY_MARKET));
        }
        // refetch owner in case changed from initial
        vm.label(market_owner = MARKET.owner(), "market_owner");

        request_market = new RequestMarket(request_owner);

        vm.prank(fulfiller);
        MARKET.setApprovalForAll(address(request_market), true);
    }

    enum Caps {
        None,
        Lower,
        Upper
    }

    function test_fuzzing_request_state(
        address owner_,
        uint32 unlock_delay,
        uint160 address_mask,
        uint160 address_target,
        uint80 capitalization_map
    ) public view brutalizeMemory {
        RequestState storage state = _request_state(
            _brutalized(owner_),
            _brutalizedUint32(unlock_delay),
            _brutalizedUint160(address_mask),
            _brutalizedUint160(address_target),
            _brutalizedUint80(capitalization_map)
        );
        bytes32 slot;
        assembly ("memory-safe") {
            slot := state.slot
        }
        assertEq(
            slot,
            keccak256(
                abi.encodePacked(
                    owner_, unlock_delay, address_mask, address_target, capitalization_map, uint32(_REQUEST_STATE_SLOT)
                )
            )
        );
    }

    function test_fuzzing_compute_address(bytes32 salt, uint256 nonce) public view {
        uint8 nonce8 = uint8(bound(nonce, 0, 254));
        assertEq(_compute_address(salt, nonce8), MARKET.computeAddress(salt, nonce8));
    }

    function test_fuzzing_capsPatternSatisfied(address addr, uint80 capitalization_map) public pure {
        // Normalize map
        capitalization_map = _normalizeMap(capitalization_map);

        Caps[40] memory caps;
        bytes memory checksummed = bytes(LibString.toHexStringChecksummed(addr));
        for (uint256 i = 0; i < 20; i++) {
            uint256 bits = (uint256(capitalization_map) >> ((19 - i) * 4)) & 0xf;
            Caps two1 = _toCap(bits >> 2);
            Caps two2 = _toCap(bits & 3);
            caps[i] = two1;
            caps[i + 20] = two2;
        }

        bool good = true;
        for (uint256 i = 0; i < 40; i++) {
            bytes1 char = checksummed[i + 2];

            Caps cap = caps[i];
            console.log(
                "'%s': %s",
                string(bytes.concat(char)),
                cap == Caps.None ? "None" : cap == Caps.Lower ? "Lower" : "Upper"
            );

            if (cap == Caps.None) continue;

            bool isUpper = char == "A" || char == "B" || char == "C" || char == "D" || char == "E" || char == "F";

            good = good && isUpper == (cap == Caps.Upper);
        }

        assertEq(_satisfies_request(addr, 0, 0, capitalization_map), good);
    }

    function test_benchmark_satifiesRequest(address addr, uint80 capitalization_map) public pure {
        _satisfies_request(addr, 0, 0, capitalization_map);
    }

    function _normalizeMap(uint80 capitalization_map) internal pure returns (uint80) {
        uint80 variant = capitalization_map & uint80(CAP_MAP_MASK);
        uint80 data = (capitalization_map >> 1) & uint80(CAP_MAP_MASK);
        return ((data & variant) << 1) | variant;
    }

    function _toCap(uint256 two) internal pure returns (Caps c) {
        if (two & 1 == 0) return Caps.None;
        return two & 2 == 0 ? Caps.Lower : Caps.Upper;
    }
}
