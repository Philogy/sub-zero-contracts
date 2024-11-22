// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {HuffTest} from "./base/HuffTest.sol";
import {ICreate3RequestMarket} from "../src/interfaces/ICreate3RequestMarket.sol";
import {VanityMarket} from "src/VanityMarket.sol";

import {console} from "forge-std/console.sol";

/// @author philogy <https://github.com/philogy>
contract Create3RequestMarketTest is Test, HuffTest {
    ICreate3RequestMarket requestMarket;
    VanityMarket constant VANITY_MARKET = VanityMarket(payable(0x000000000000b361194cfe6312EE3210d53C15AA));

    address owner = 0xea57c1ef7eF1c88b456ADf0927ec0EAe3B17f1F5;
    address fulfiller = makeAddr("fulfiller");

    function setUp() public {
        setupBase_ffi();

        if (address(VANITY_MARKET).code.length == 0) {
            deployCodeTo("VanityMarket.sol", abi.encode(owner), address(VANITY_MARKET));
        }
        vm.label(owner = VANITY_MARKET.owner(), "market_owner");
        requestMarket =
            ICreate3RequestMarket(deployCode("Create3RequestMarket.vy", abi.encode(VANITY_MARKET, fulfiller)));
        vm.prank(fulfiller);
        VANITY_MARKET.setApprovalForAll(address(requestMarket), true);
    }

    function test_correctStartFulfiller() public {
        assertEq(requestMarket.FULFILLER(), fulfiller);
    }

    function test_simpleRequest() public {
        uint160 relevant = 0x00fe00000000000000000000000000000000000000;
        uint160 desired = 0x00fe00000000000000000000000000000000000000;
        address user = makeAddr("user");

        hoax(user, 3 ether);
        requestMarket.request{value: 1 ether}(1 hours, relevant, desired);
        assertEq(address(requestMarket).balance, 1 ether);

        (bytes32 salt, uint8 nonce) = mineForRequest(relevant, desired);
        uint256 id = uint256(salt);
        requestMarket.fulfill(user, 1 hours, relevant, desired, id, nonce);

        assertEq(address(requestMarket).balance, 0);
        assertEq(address(fulfiller).balance, 1 ether);

        assertEq(VANITY_MARKET.ownerOf(id), user);
    }

    function test_simpleRefund() public {
        uint160 relevant = 0x00fe00000000000000000ffffffffffff000000000;
        uint160 desired = 0x00fe00000000000000000000000000000000000000;
        address user = makeAddr("user");

        vm.deal(address(requestMarket), 3 ether);

        hoax(user, 3 ether);
        requestMarket.request{value: 1 ether}(1 hours, relevant, desired);
        assertEq(address(requestMarket).balance, 4 ether);
        assertEq(user.balance, 2 ether);

        vm.expectEmit(true, true, true, true);
        emit ICreate3RequestMarket.InitiatedUnlock(keccak256(abi.encode(user, 1 hours, relevant, desired)));
        vm.prank(user);
        requestMarket.initiate_unlock(1 hours, relevant, desired);

        skip(59 minutes);

        vm.prank(user);
        vm.expectRevert("Not unlockable");
        requestMarket.unlock(1 hours, relevant, desired);

        skip(1 minutes);

        vm.prank(user);
        requestMarket.unlock(1 hours, relevant, desired);

        assertEq(address(requestMarket).balance, 3 ether);
        assertEq(user.balance, 3 ether);

        vm.prank(user);
        vm.expectRevert("Not unlockable");
        requestMarket.unlock(1 hours, relevant, desired);
    }

    function test_fulfillWhileUnlocking() public {
        uint160 relevant = 0x00fe00000000000000000000000000000000000000;
        uint160 desired = 0x00fe00000000000000000000000000000000000000;
        address user = makeAddr("user");

        hoax(user, 3 ether);
        requestMarket.request{value: 1 ether}(1 hours, relevant, desired);
        assertEq(address(requestMarket).balance, 1 ether);

        vm.prank(user);
        requestMarket.initiate_unlock(1 hours, relevant, desired);

        skip(30 minutes);

        (bytes32 salt, uint8 nonce) = mineForRequest(relevant, desired);
        uint256 id = uint256(salt);
        requestMarket.fulfill(user, 1 hours, relevant, desired, id, nonce);

        assertEq(address(requestMarket).balance, 0);
        assertEq(address(fulfiller).balance, 1 ether);

        assertEq(VANITY_MARKET.ownerOf(id), user);

        skip(1 hours);

        vm.prank(user);
        vm.expectRevert("Not unlockable");
        requestMarket.unlock(1 hours, relevant, desired);
    }

    function mineForRequest(uint160 relevantBits, uint160 desired) internal view returns (bytes32 salt, uint8 nonce) {
        uint256 offset = 0;
        nonce = 0;
        while (true) {
            salt = _salt(offset);
            address addr = VANITY_MARKET.computeAddress(salt, nonce);
            if (uint160(addr) & relevantBits == desired) break;
            offset++;
        }
    }

    function _salt(uint256 offset) internal view returns (bytes32 salt) {
        address f = fulfiller;
        assembly {
            salt := or(shl(96, f), offset)
        }
    }
}
