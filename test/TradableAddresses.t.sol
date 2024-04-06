// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {HuffTest} from "./base/HuffTest.sol";
import {TradableAddresses} from "../src/TradableAddresses.sol";
import {LibRLP} from "solady/src/utils/LibRLP.sol";
import {Create2Lib} from "../src/utils/Create2Lib.sol";
import {MockSimple} from "./mocks/MockSimple.sol";
import {FailingDeploy} from "./mocks/FailingDeploy.sol";
import {Empty} from "./mocks/Empty.sol";

import {console2 as console} from "forge-std/console2.sol";

/// @author philogy <https://github.com/philogy>
contract TradableAddressesTest is Test, HuffTest {
    TradableAddresses trader;

    address immutable owner = makeAddr("owner");

    function setUp() public {
        setupBase_ffi();
        trader = new TradableAddresses(owner);
    }

    function test_mintAndDeploy() public {
        address user = makeAddr("user");
        uint256 id = getId(user, 0x983974);
        uint8 nonce = 34;
        vm.prank(user);
        trader.mint(user, id, nonce);
        assertEq(trader.ownerOf(id), user);

        vm.prank(user);
        MockSimple simp =
            MockSimple(trader.deploy(id, abi.encodePacked(type(MockSimple).creationCode, abi.encode(user))));
        assertEq(address(simp), trader.computeAddress(bytes32(id), nonce));
        assertEq(address(simp), trader.addressOf(id));
        assertEq(address(simp).code, type(MockSimple).runtimeCode);
        assertEq(simp.balanceOf(user), 10e18);
        assertEq(simp.balanceOf(makeAddr("other")), 0);
    }

    function test_bubblesDeployRevert() public {
        address user = makeAddr("user");
        uint256 id = getId(user, 0xab19c31);
        uint8 nonce = 21;
        vm.prank(user);
        trader.mint(user, id, nonce);
        assertEq(trader.ownerOf(id), user);

        vm.prank(user);
        vm.expectRevert(TradableAddresses.DeploymentFailed.selector);
        trader.deploy(id, type(FailingDeploy).creationCode);
    }

    function test_bubblesIncreaseRevert() public {
        address user = makeAddr("user");
        uint256 id = getId(user, 0xab19c31);
        uint8 nonce = 255;
        vm.prank(user);
        trader.mint(user, id, nonce);
        assertEq(trader.ownerOf(id), user);

        vm.prank(user);
        vm.expectRevert(TradableAddresses.DeploymentFailed.selector);
        // Ensure out-of-gas within increaser but sufficient remaining gas to test whether
        // standalone increase revert will actually get bubbled up.
        trader.deploy{gas: 250 * 32000}(id, type(Empty).creationCode);
    }

    // function test_nonOwnerCannotMint

    function getId(address miner, uint96 extra) internal pure returns (uint256) {
        return (uint256(uint160(miner)) << 96) | uint256(extra);
    }
}
