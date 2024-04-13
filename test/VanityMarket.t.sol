// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {HuffTest} from "./base/HuffTest.sol";
import {ERC721} from "solady/src/tokens/ERC721.sol";
import {VanityMarket} from "../src/VanityMarket.sol";
import {PermitERC721} from "../src/base/PermitERC721.sol";
import {LibRLP} from "solady/src/utils/LibRLP.sol";
import {Create2Lib} from "../src/utils/Create2Lib.sol";
import {MockSimple} from "./mocks/MockSimple.sol";
import {MockRenderer} from "./mocks/MockRenderer.sol";
import {FailingDeploy} from "./mocks/FailingDeploy.sol";
import {Empty} from "./mocks/Empty.sol";

import {console2 as console} from "forge-std/console2.sol";

/// @author philogy <https://github.com/philogy>
contract VanityMarketTest is Test, HuffTest {
    VanityMarket trader;

    address immutable owner = makeAddr("owner");

    bytes32 internal immutable MINT_AND_SELL_TYPEHASH = keccak256(
        "MintAndSell(uint256 id,uint8 saltNonce,uint256 price,address beneficiary,address buyer,uint256 nonce,uint256 deadline)"
    );

    bytes32 internal immutable PERMIT_FOR_ALL_TYPEHASH =
        keccak256("PermitForAll(address operator,uint256 nonce,uint256 deadline)");

    function setUp() public {
        setupBase_ffi();
        trader = new VanityMarket(owner);
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
        vm.expectRevert(VanityMarket.DeploymentFailed.selector);
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
        vm.expectRevert(VanityMarket.DeploymentFailed.selector);
        // Ensure out-of-gas within increaser but sufficient remaining gas to test whether
        // standalone increase revert will actually get bubbled up.
        trader.deploy{gas: 250 * 32000}(id, type(Empty).creationCode);
    }

    function test_mintAndBuy_anyBuyerWithFee() public {
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

    struct MintAndSell {
        uint256 id;
        uint8 saltNonce;
        uint256 price;
        address beneficiary;
        address buyer;
        uint256 nonce;
        uint256 deadline;
    }

    function test_mintAndBuy_specificBuyer() public {
        vm.prank(owner);
        trader.setFee(0.02e4);

        Account memory seller = makeAccount("seller");

        address buyer = makeAddr("buyer");
        MintAndSell memory sell = MintAndSell({
            id: getId(seller.addr, 0xc1c1c1c1c1c1c1c1c1c1c1c1),
            saltNonce: 3,
            price: 0.98 ether,
            beneficiary: seller.addr,
            buyer: buyer,
            nonce: 34,
            deadline: type(uint256).max
        });

        bytes memory sig;
        {
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(
                seller.key,
                mintAndBuyDigest(
                    sell.id, sell.saltNonce, sell.beneficiary, sell.price, sell.buyer, sell.nonce, sell.deadline
                )
            );
            sig = abi.encodePacked(r, s, v);
        }

        address other = makeAddr("other");
        vm.expectRevert(VanityMarket.NotAuthorizedBuyer.selector);
        hoax(other, 1 ether);
        trader.mintAndBuyWithSig{value: 1 ether}(
            other, sell.id, sell.saltNonce, sell.beneficiary, sell.price, sell.buyer, sell.nonce, sell.deadline, sig
        );

        address recipient = makeAddr("recipient");
        hoax(sell.buyer, 1 ether);
        trader.mintAndBuyWithSig{value: 1 ether}(
            recipient, sell.id, sell.saltNonce, sell.beneficiary, sell.price, sell.buyer, sell.nonce, sell.deadline, sig
        );
        assertEq(trader.ownerOf(sell.id), recipient);

        assertEq(buyer.balance, 0);
        assertEq(seller.addr.balance, sell.price);
        assertEq(address(trader).balance, 0.02 ether);
        assertTrue(trader.getNonceIsSet(seller.addr, sell.nonce));

        vm.prank(owner);
    }

    function test_settingRenderer() public {
        address user = makeAddr("user");
        uint256 id = getId(user, 0);

        // Test basic errors
        vm.expectRevert(VanityMarket.NoRenderer.selector);
        trader.tokenURI(id);

        MockRenderer renderer = new MockRenderer("");
        // Test set.
        vm.expectEmit(true, true, true, true);
        emit VanityMarket.RendererSet(address(renderer));
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
        vm.expectEmit(true, true, true, true);
        emit VanityMarket.RendererSet(address(renderer));
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

        vm.expectRevert(VanityMarket.RendererLockedIn.selector);
        vm.prank(owner);
        trader.setRenderer(address(renderer));
    }

    function test_approveForAllWithSig() public {
        Account memory user = makeAccount("user");
        address operator = makeAddr("operator");

        assertFalse(trader.isApprovedForAll(user.addr, operator));

        uint256 messageNonce = 111;
        assertFalse(trader.getNonceIsSet(user.addr, messageNonce));

        (uint8 v, bytes32 r, bytes32 s) =
            vm.sign(user.key, permitForAllDigest(operator, messageNonce, type(uint256).max));

        vm.prank(makeAddr("submitter"));
        bytes32 vs = bytes32((uint256(v - 27) << 255) | uint256(s));
        trader.permitForAll(user.addr, operator, messageNonce, type(uint256).max, abi.encodePacked(r, vs));

        assertTrue(trader.getNonceIsSet(user.addr, messageNonce));
        assertTrue(trader.isApprovedForAll(user.addr, operator));
    }

    function test_nonceInvalidation() public {
        Account memory user = makeAccount("user");
        address operator = makeAddr("operator");

        uint256 messageNonce = 111;

        vm.prank(user.addr);
        trader.invalidateNonce(messageNonce);

        vm.prank(makeAddr("submitter"));
        (uint8 v, bytes32 r, bytes32 s) =
            vm.sign(user.key, permitForAllDigest(operator, messageNonce, type(uint256).max));
        bytes32 vs = bytes32((uint256(v - 27) << 255) | uint256(s));
        vm.expectRevert(PermitERC721.NonceAlreadyInvalidated.selector);
        trader.permitForAll(user.addr, operator, messageNonce, type(uint256).max, abi.encodePacked(r, vs));
    }

    function test_blocksReplay() public {
        Account memory user = makeAccount("user");
        address operator = makeAddr("operator");
        address submitter = makeAddr("submitter");

        uint256 messageNonce = 111;

        (uint8 v, bytes32 r, bytes32 s) =
            vm.sign(user.key, permitForAllDigest(operator, messageNonce, type(uint256).max));
        bytes32 vs = bytes32((uint256(v - 27) << 255) | uint256(s));
        vm.prank(submitter);
        trader.permitForAll(user.addr, operator, messageNonce, type(uint256).max, abi.encodePacked(r, vs));

        assertTrue(trader.isApprovedForAll(user.addr, operator));

        vm.prank(user.addr);
        trader.setApprovalForAll(operator, false);

        vm.prank(submitter);
        vm.expectRevert(PermitERC721.NonceAlreadyInvalidated.selector);
        trader.permitForAll(user.addr, operator, messageNonce, type(uint256).max, abi.encodePacked(r, vs));

        assertFalse(trader.isApprovedForAll(user.addr, operator));
    }

    function test_cannotSubmitPermitPastDeadline() public {
        Account memory user = makeAccount("user");
        address operator = makeAddr("operator");
        address submitter = makeAddr("submitter");

        uint256 messageNonce = 111;
        uint256 deadline = block.timestamp + 100 seconds;

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(user.key, permitForAllDigest(operator, messageNonce, deadline));
        bytes32 vs = bytes32((uint256(v - 27) << 255) | uint256(s));

        vm.warp(deadline + 1);

        vm.prank(submitter);
        vm.expectRevert(PermitERC721.PastDeadline.selector);
        trader.permitForAll(user.addr, operator, messageNonce, deadline, abi.encodePacked(r, vs));
    }

    function test_mintAndBuy_cannotBuyPastDeadline() public {
        vm.prank(owner);
        trader.setFee(0.02e4);

        Account memory seller = makeAccount("seller");

        address buyer = makeAddr("buyer");
        MintAndSell memory sell = MintAndSell({
            id: getId(seller.addr, 0xc1c1c1c1c1c1c1c1c1c1c1c1),
            saltNonce: 3,
            price: 0.98 ether,
            beneficiary: seller.addr,
            buyer: buyer,
            nonce: 34,
            deadline: block.timestamp + 3 hours
        });

        bytes memory sig;
        {
            (uint8 v, bytes32 r, bytes32 s) = vm.sign(
                seller.key,
                mintAndBuyDigest(
                    sell.id, sell.saltNonce, sell.beneficiary, sell.price, sell.buyer, sell.nonce, sell.deadline
                )
            );
            sig = abi.encodePacked(r, s, v);
        }

        vm.warp(sell.deadline + 1);

        address recipient = makeAddr("recipient");
        hoax(sell.buyer, 1 ether);
        vm.expectRevert(PermitERC721.PastDeadline.selector);
        trader.mintAndBuyWithSig{value: 1 ether}(
            recipient, sell.id, sell.saltNonce, sell.beneficiary, sell.price, sell.buyer, sell.nonce, sell.deadline, sig
        );
    }

    function test_auth_transferOwnership() public {
        address newOwner = makeAddr("newOwner");

        vm.prank(owner);
        trader.transferOwnership(newOwner);

        assertEq(newOwner, trader.owner());
    }

    function test_fuzzing_defaultRoyaltyIsZero(uint256 tokenId, uint256 price) public {
        (address receiver, uint256 value) = trader.royaltyInfo(tokenId, price);
        assertEq(receiver, owner);
        assertEq(value, 0);
    }

    function test_auth_changeRoyalty() public {
        vm.prank(owner);
        trader.setRoyalty(0.01e4);
        (address receiver, uint256 royalty) = _getRoyalty();
        assertEq(receiver, owner);
        assertEq(royalty, 0.01e4);

        address newOwner = makeAddr("newOwner");
        vm.prank(owner);
        trader.transferOwnership(newOwner);

        (receiver, royalty) = _getRoyalty();
        assertEq(receiver, newOwner);
        assertEq(royalty, 0.01e4);

        vm.prank(owner);
        vm.expectRevert(bytes4(keccak256("Unauthorized()")));
        trader.setRoyalty(0.0e4);
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

    function permitForAllDigest(address operator, uint256 nonce, uint256 deadline) internal view returns (bytes32) {
        return _hashTraderTypedData(keccak256(abi.encode(PERMIT_FOR_ALL_TYPEHASH, operator, nonce, deadline)));
    }

    function _hashTraderTypedData(bytes32 structHash) internal view returns (bytes32) {
        return keccak256(abi.encodePacked(hex"1901", trader.DOMAIN_SEPARATOR(), structHash));
    }

    function _getRoyalty() internal view returns (address receiver, uint256 royalty) {
        (receiver, royalty) = trader.royaltyInfo(0, 1.0e4);
    }
}
