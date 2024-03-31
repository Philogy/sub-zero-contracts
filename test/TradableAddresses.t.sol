// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {HuffTest} from "./base/HuffTest.sol";
import {TradableAddresses} from "../src/TradableAddresses.sol";
import {LibRLP} from "solady/src/utils/LibRLP.sol";
import {Create2Lib} from "../src/utils/Create2Lib.sol";
import {MockSimple} from "./mocks/MockSimple.sol";

import {console2 as console} from "forge-std/console2.sol";

/// @author philogy <https://github.com/philogy>
contract TradableAddressesTest is Test, HuffTest {
    TradableAddresses trader;

    address immutable owner = makeAddr("owner");
    address immutable increaser = deployRaw(_huffInitcode("src/deploy-proxy/NonceIncreaser.huff"));

    function setUp() public {
        trader = new TradableAddresses(owner, increaser);
    }

    function test_mintAndDeploy() public {
        address user = makeAddr("user");
        bytes32 salt = bytes32((uint256(uint160(user)) << 96) | 0x983974);
        uint256 id = uint256(salt);
        uint8 nonce = 34;
        vm.prank(user);
        trader.mint(user, salt, nonce);
        assertEq(trader.ownerOf(id), user);

        vm.prank(user);
        MockSimple simp =
            MockSimple(trader.deploy(id, abi.encodePacked(type(MockSimple).creationCode, abi.encode(user))));
        assertEq(address(simp), trader.computeAddress(salt, nonce));
        assertEq(address(simp), trader.addressOf(id));
        assertEq(address(simp).code, type(MockSimple).runtimeCode);
        assertEq(simp.balanceOf(user), 10e18);
        assertEq(simp.balanceOf(makeAddr("other")), 0);
    }
}
