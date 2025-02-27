// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {RequestMarket} from "../src/RequestMarket.sol";

import {Test} from "forge-std/Test.sol";
import {HuffTest} from "./base/HuffTest.sol";
import {ICreate3RequestMarket} from "../src/interfaces/ICreate3RequestMarket.sol";
import {VanityMarket} from "src/VanityMarket.sol";
import {LibString} from "solady/src/utils/LibString.sol";
import {Brutalizer} from "solady/test/utils/Brutalizer.sol";

import {Create2Lib} from "src/utils/Create2Lib.sol";
import {LibRLP} from "solady/src/utils/LibRLP.sol";

import {console} from "forge-std/console.sol";

/// @author philogy <https://github.com/philogy>
contract RequestMarketTest is Test, HuffTest, RequestMarket(address(0)), Brutalizer {
    VanityMarket constant FACTORY = VanityMarket(payable(0x000000000000b361194cfe6312EE3210d53C15AA));
    address market_owner = 0xea57c1ef7eF1c88b456ADf0927ec0EAe3B17f1F5;

    address fulfiller = makeAddr("fulfiller");
    address request_owner = makeAddr("request_owner");
    RequestMarket market;

    function setUp() public {
        setupBase_ffi();

        if (address(VANITY_MARKET).code.length == 0) {
            deployCodeTo("VanityMarket.sol", abi.encode(market_owner), address(VANITY_MARKET));
        }
        // refetch owner in case changed from initial
        vm.label(market_owner = FACTORY.owner(), "market_owner");

        market = new RequestMarket(request_owner);

        vm.prank(fulfiller);
        FACTORY.setApprovalForAll(address(market), true);
    }

    enum Caps {
        None,
        Lower,
        Upper
    }

    function test_fulfill() public {
        address user = makeAddr("user");
        uint256 value = 1 ether;
        uint32 delay = 1 days;
        uint160 mask = 0x00fFf0000000000000000000000000000000000000;
        uint160 target = 0x00ccc0000000000000000000000000000000000000;
        uint80 cap_map = _strToCapMap("lll.....................................");

        assertEq(market.claimable_eth(), 0);

        vm.expectEmit(true, true, true, true);
        emit NewRequest(
            _pack(bytes20(user), uint96(value)),
            _pack(bytes20(mask), uint96(delay)),
            _pack(bytes20(target), uint96(cap_map))
        );
        hoax(user, value);
        market.request{value: value}(delay, mask, target, cap_map);

        RequestState memory req = market.get_request(user, delay, mask, target, cap_map);
        assertEq(req.reward, value, "req.reward != value");
        assertEq(req.initiated_refund_at, REQUEST_LOCKED, "req not locked");

        (uint256 id, uint8 nonce) = _mine(fulfiller, mask, target, cap_map);

        vm.expectEmit(true, true, true, true);
        emit Fulfilled(_id(_request_state(user, delay, mask, target, cap_map)));
        vm.prank(fulfiller);
        market.fulfill(user, delay, mask, target, cap_map, id, nonce);

        req = market.get_request(user, delay, mask, target, cap_map);
        assertEq(req.reward, 0, "req.reward not reset");
        assertEq(req.initiated_refund_at, 0, "req.initiated_refund_at not reset");

        assertEq(market.claimable_eth(), value, "claimable eth not accounted");

        vm.prank(request_owner);
        market.claim_eth();

        assertEq(request_owner.balance, value, "claimable eth not transferred");
        assertEq(market.claimable_eth(), 0, "claimable eth not reset");
    }

    function test_refund() public {
        address user = makeAddr("user");
        uint256 value = 1.21 ether;
        uint32 delay = 3 days;
        uint160 mask = 0x0000000000000000000000000000000000000fff00;
        uint160 target = 0x0000000000000000000000000000000000000a0a00;
        uint80 cap_map = _strToCapMap("...................................U.U..");

        assertEq(market.claimable_eth(), 0);

        vm.expectEmit(true, true, true, true);
        emit NewRequest(
            _pack(bytes20(user), uint96(value)),
            _pack(bytes20(mask), uint96(delay)),
            _pack(bytes20(target), uint96(cap_map))
        );
        hoax(user, value);
        market.request{value: value}(delay, mask, target, cap_map);

        RequestState memory req = market.get_request(user, delay, mask, target, cap_map);
        assertEq(req.reward, value, "req.reward != value");
        assertEq(req.initiated_refund_at, REQUEST_LOCKED, "req not locked");
        assertEq(user.balance, 0, "balance not empty");

        vm.expectEmit(true, true, true, true);
        emit RefundInitiated(_id(_request_state(user, delay, mask, target, cap_map)));
        vm.prank(user);
        market.initiate_refund(delay, mask, target, cap_map);

        req = market.get_request(user, delay, mask, target, cap_map);
        assertEq(req.reward, value, "req.reward != value (post refund init)");
        assertEq(req.initiated_refund_at, block.timestamp, "refund not initiated");

        skip(delay / 3);
        vm.expectRevert(RefundStillInProgress.selector);
        vm.prank(user);
        market.complete_refund(delay, mask, target, cap_map);

        skip(delay);
        vm.expectEmit(true, true, true, true);
        emit RefundCompleted(_id(_request_state(user, delay, mask, target, cap_map)));
        vm.prank(user);
        market.complete_refund(delay, mask, target, cap_map);

        req = market.get_request(user, delay, mask, target, cap_map);
        assertEq(req.reward, 0, "req.reward != value (post refund init)");
        assertEq(req.initiated_refund_at, 0, "refund not initiated");

        assertEq(user.balance, value);
    }

    function test_fulfill_while_refund() public {
        address user = makeAddr("user");
        uint256 value = 1.21 ether;
        uint32 delay = 3 days;
        uint160 mask = 0x0000000000000000000000000000000000000fff00;
        uint160 target = 0x0000000000000000000000000000000000000a0a00;
        uint80 cap_map = _strToCapMap("...................................U.U..");

        assertEq(market.claimable_eth(), 0);

        vm.expectEmit(true, true, true, true);
        emit NewRequest(
            _pack(bytes20(user), uint96(value)),
            _pack(bytes20(mask), uint96(delay)),
            _pack(bytes20(target), uint96(cap_map))
        );
        hoax(user, value);
        market.request{value: value}(delay, mask, target, cap_map);

        RequestState memory req = market.get_request(user, delay, mask, target, cap_map);
        assertEq(req.reward, value, "req.reward != value");
        assertEq(req.initiated_refund_at, REQUEST_LOCKED, "req not locked");
        assertEq(user.balance, 0, "balance not empty");

        vm.expectEmit(true, true, true, true);
        emit RefundInitiated(_id(_request_state(user, delay, mask, target, cap_map)));
        vm.prank(user);
        market.initiate_refund(delay, mask, target, cap_map);

        req = market.get_request(user, delay, mask, target, cap_map);
        assertEq(req.reward, value, "req.reward != value (post refund init)");
        assertEq(req.initiated_refund_at, block.timestamp, "refund not initiated");

        (uint256 id, uint8 nonce) = _mine(fulfiller, mask, target, cap_map);

        vm.expectEmit(true, true, true, true);
        emit Fulfilled(_id(_request_state(user, delay, mask, target, cap_map)));
        vm.prank(fulfiller);
        market.fulfill(user, delay, mask, target, cap_map, id, nonce);

        req = market.get_request(user, delay, mask, target, cap_map);
        assertEq(req.reward, 0, "req.reward not reset");
        assertEq(req.initiated_refund_at, 0, "req.timestamp not reset");

        skip(delay);

        vm.expectRevert(EmptyRequest.selector);
        vm.prank(user);
        market.complete_refund(delay, mask, target, cap_map);
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
        assertEq(
            _id(state),
            keccak256(
                abi.encodePacked(
                    owner_, unlock_delay, address_mask, address_target, capitalization_map, uint32(_REQUEST_STATE_SLOT)
                )
            )
        );
    }

    function test_fuzzing_compute_address(bytes32 salt, uint256 nonce) public view {
        uint8 nonce8 = uint8(bound(nonce, 0, 254));
        assertEq(_compute_address(salt, nonce8), FACTORY.computeAddress(salt, nonce8));
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
            // console.log(
            //     "'%s': %s",
            //     string(bytes.concat(char)),
            //     cap == Caps.None ? "None" : cap == Caps.Lower ? "Lower" : "Upper"
            // );

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

    function _mine(address owner, uint160 mask, uint160 target, uint80 cap_map)
        internal
        pure
        returns (uint256, uint8)
    {
        uint256 id = uint256(uint160(owner)) << 96;

        while (true) {
            address deployProxy = Create2Lib.predict(DEPLOY_PROXY_INITHASH, bytes32(id), address(VANITY_MARKET));
            for (uint256 nonce = 1; nonce < 256; nonce++) {
                address vanity = LibRLP.computeAddress(deployProxy, uint8(nonce));
                if (_satisfies_request(vanity, mask, target, cap_map)) {
                    return (id, uint8(nonce) - 1);
                }
            }
            id++;
        }
        revert("unreachable");
    }

    function _strToCapMap(string memory str) internal pure returns (uint80 cap_map) {
        bytes memory b = bytes(str);
        require(b.length == 40, "String must be exactly 40 characters long");
        for (uint256 i = 0; i < 20; i++) {
            uint80 g1 = _charToCaps(b[i]);
            uint80 g2 = _charToCaps(b[i + 20]);
            cap_map |= ((g1 << 2) | g2) << uint80((19 - i) * 4);
        }
    }

    function _charToCaps(bytes1 char) internal pure returns (uint80) {
        if (char == "U") return 3;
        if (char == "L" || char == "l") return 1;
        return 0;
    }

    function _toCap(uint256 two) internal pure returns (Caps c) {
        if (two & 1 == 0) return Caps.None;
        return two & 2 == 0 ? Caps.Lower : Caps.Upper;
    }

    function _pack(bytes20 x1, uint96 x2) internal pure returns (uint256) {
        return uint256(bytes32(bytes.concat(x1, bytes12(x2))));
    }
}
