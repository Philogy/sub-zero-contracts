// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {HuffTest} from "./base/HuffTest.sol";
import {ERC721} from "solady/src/tokens/ERC721.sol";
import {TradableAddresses} from "../src/TradableAddresses.sol";
import {LibRLP} from "solady/src/utils/LibRLP.sol";
import {Create2Lib} from "../src/utils/Create2Lib.sol";
import {MockSimple} from "./mocks/MockSimple.sol";
import {MockRenderer} from "./mocks/MockRenderer.sol";
import {FailingDeploy} from "./mocks/FailingDeploy.sol";
import {Empty} from "./mocks/Empty.sol";

import {console2 as console} from "forge-std/console2.sol";

/// @author philogy <https://github.com/philogy>
contract TradableAddressesTest is Test, HuffTest {
    TradableAddresses trader;

    address immutable owner = makeAddr("owner");

    bytes32 internal immutable MINT_AND_SELL_TYPEHASH = keccak256(
        "MintAndSell(uint256 id,uint8 saltNonce,uint256 amount,address beneficiary,address buyer,uint256 nonce,uint256 deadline)"
    );

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

    function test_mintAndBuyAnyBuyerWithFee() public {
        vm.prank(owner);
        trader.setFee(0.02e4);

        Account memory seller = makeAccount("seller");
        address beneficiary = makeAddr("beneficiary");

        uint256 id = getId(seller.addr, 0xc1c1c1c1c1c1c1c1c1c1c1c1);
        uint8 nonce = 3;
        uint256 price = 0.98 ether;
        uint256 messageNonce = 34;
        assertFalse(trader.getNonceIsSet(seller.addr, messageNonce));

        bytes memory sig;
        {
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(
                seller.key, mintAndBuyDigest(id, nonce, beneficiary, price, address(0), messageNonce, type(uint256).max)
            );
            sig = abi.encodePacked(r, s, v);
        }

        address buyer = makeAddr("buyer");
        address recipient = makeAddr("recipient");

        hoax(buyer, 1 ether);
        trader.mintAndBuyWithSig{value: 1 ether}(
            recipient, id, nonce, beneficiary, price, address(0), messageNonce, type(uint256).max, sig
        );

        assertEq(trader.ownerOf(id), recipient);
        assertEq(buyer.balance, 0);
        assertEq(beneficiary.balance, price);
        assertEq(address(trader).balance, 0.02 ether);
        assertTrue(trader.getNonceIsSet(seller.addr, messageNonce));

        vm.prank(owner);
    }

    function test_settingRenderer() public {
        address user = makeAddr("user");
        uint256 id = getId(user, 0);

        // Test basic errors
        vm.expectRevert(TradableAddresses.NoRenderer.selector);
        trader.tokenURI(id);

        MockRenderer renderer = new MockRenderer("");
        // Test set.
        vm.expectEmit(true, true, true, true );
        emit TradableAddresses.RendererSet(address(renderer));
        vm.prank(owner);
        trader.setRenderer(address(renderer));
        assertEq(trader.renderer(), address(renderer));

        vm.expectRevert(ERC721.TokenDoesNotExist.selector);
        trader.tokenURI(id);

        // Test basic retrieve
        uint8 nonce = 5;
        vm.prank(user);
        trader.mint(user, id, nonce);

        assertEq(trader.tokenURI(id), "5");

        renderer = new MockRenderer("wow_");
        vm.expectEmit(true, true, true, true );
        emit TradableAddresses.RendererSet(address(renderer));
        vm.prank(owner);
        trader.setRenderer(address(renderer));
        assertEq(trader.renderer(), address(renderer));
        assertEq(trader.tokenURI(id), "wow_5");

        address lastRenderer = 0x0000000000007AEa7C08C8d6AE08b2862a662bb4;
        vm.etch(lastRenderer, type(MockRenderer).runtimeCode);
        MockRenderer(lastRenderer).setBase("last_");
        vm.prank(owner);
        trader.setRenderer(lastRenderer);
        assertEq(trader.tokenURI(id), "last_5");

        vm.expectRevert(TradableAddresses.RendererLockedIn.selector);
        vm.prank(owner);
        trader.setRenderer(address(renderer));
    }

    function getId(address miner, uint96 extra) internal pure returns (uint256) {
        return (uint256(uint160(miner)) << 96) | uint256(extra);
    }

    function mintAndBuyDigest(
        uint256 id,
        uint8 saltNonce,
        address beneficiary,
        uint256 sellerPrice,
        address buyer,
        uint256 nonce,
        uint256 deadline
    ) internal view returns (bytes32) {
        return _hashTraderTypedData(
            keccak256(
                abi.encode(MINT_AND_SELL_TYPEHASH, id, saltNonce, sellerPrice, beneficiary, buyer, nonce, deadline)
            )
        );
    }

    function _hashTraderTypedData(bytes32 structHash) internal view returns (bytes32) {
        return keccak256(abi.encodePacked(hex"1901", trader.DOMAIN_SEPARATOR(), structHash));
    }
}
