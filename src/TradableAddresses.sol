// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.24;

// Base contracts & interfaces.
import {Ownable} from "solady/src/auth/Ownable.sol";
import {PermitERC721} from "./base/PermitERC721.sol";
import {IRenderer} from "./interfaces/IRenderer.sol";
// Libraries.
import {SafeTransferLib} from "solady/src/utils/SafeTransferLib.sol";
import {Create2Lib} from "./utils/Create2Lib.sol";
import {BytesLib} from "./utils/BytesLib.sol";
import {SaltLib} from "./utils/SaltLib.sol";
import {LibRLP} from "solady/src/utils/LibRLP.sol";

/// @author philogy <https://github.com/philogy>
contract TradableAddresses is Ownable, PermitERC721 {
    using BytesLib for bytes;
    using SaltLib for uint256;
    using SafeTransferLib for address;

    error NotAuhtorizedBuyer();
    error InvalidFee();

    error NoSource();
    error InvalidSource();
    error ReenteringDeploy();

    error NotOwnerOrOperator();
    error AlreadyMinted();
    error NoRenderer();

    event RendererSet(address indexed renderer);
    event FeeSet(uint16 fee);

    uint96 internal constant MINTED_BIT = 0x100;
    uint256 internal constant BPS = 10000;

    // TODO: Mine and insert nonce incrementer.
    bytes internal DEPLOY_PROXY_INITCODE;
    bytes32 internal immutable DEPLOY_PROXY_INITHASH;

    bytes32 internal immutable MINT_AND_SELL_TYPEHASH = keccak256(
        "MintAndSell(uint256 salt,uint8 saltNonce,uint256 amount,address beneficiary,address buyer,uint256 nonce,uint256 deadline)"
    );

    address public renderer;
    uint16 public buyFeeBps;

    constructor(address initialOwner, address nonceIncreaser) {
        DEPLOY_PROXY_INITCODE = abi.encodePacked(
            hex"602e8060095f395ff360013d363d3d373d823d73", nonceIncreaser, hex"5af4503603600134f03d5260203df3"
        );
        DEPLOY_PROXY_INITHASH = keccak256(DEPLOY_PROXY_INITCODE);
        _initializeOwner(initialOwner);
    }

    ////////////////////////////////////////////////////////////////
    //                           ADMIN                            //
    ////////////////////////////////////////////////////////////////

    function setRenderer(address newRenderer) external onlyOwner {
        renderer = newRenderer;
        emit RendererSet(newRenderer);
    }

    function setFee(uint16 newFee) external onlyOwner {
        if (newFee >= BPS) revert InvalidFee();
        buyFeeBps = newFee;
        emit FeeSet(newFee);
    }

    function withdraw(address to, uint256 amount) external onlyOwner {
        assembly ("memory-safe") {
            amount := add(amount, mul(selfbalance(), iszero(amount)))
        }
        to.safeTransferETH(amount);
    }

    ////////////////////////////////////////////////////////////////
    //                      GASLESS MINTING                       //
    ////////////////////////////////////////////////////////////////

    function mintAndBuy(
        address to,
        uint256 salt,
        uint8 saltNonce,
        address beneficiary,
        uint256 sellerAmount,
        address buyer,
        uint256 nonce,
        uint256 deadline,
        bytes calldata signature
    ) external payable {
        _checkDeadline(deadline);
        address owner = salt.owner();
        _checkAndUseNonce(owner, nonce);
        _checkBuyer(buyer);
        bytes32 hash = _hashTypedData(
            keccak256(
                abi.encode(MINT_AND_SELL_TYPEHASH, salt, saltNonce, sellerAmount, beneficiary, buyer, nonce, deadline)
            )
        );
        _checkSignature(owner, hash, signature);

        _mint(to, salt, saltNonce);

        uint256 buyCost = sellerAmount * BPS / (BPS - buyFeeBps);
        // Checked subtraction will underflow if insufficient funds were sent.
        uint256 amountLeft = msg.value - buyCost;
        beneficiary.safeTransferETH(sellerAmount);
        if (amountLeft > 0) msg.sender.safeTransferETH(amountLeft);
    }

    ////////////////////////////////////////////////////////////////
    //                          MINTING                           //
    ////////////////////////////////////////////////////////////////

    function mint(address to, uint256 salt, uint8 nonce) public {
        address owner = salt.owner();
        if (msg.sender != owner && !isApprovedForAll(owner, msg.sender)) revert NotOwnerOrOperator();
        _mint(to, salt, nonce);
    }

    struct NewSalt {
        uint256 salt;
        uint8 nonce;
    }

    function mintMany(address to, NewSalt[] calldata salts) public {
        uint256 totalSalts = salts.length;
        unchecked {
            for (uint256 i = 0; i < totalSalts; i++) {
                NewSalt calldata newSalt = salts[i];
                mint(to, newSalt.salt, newSalt.nonce);
            }
        }
    }

    function _mint(address to, uint256 salt, uint8 nonce) internal {
        (bool minted,) = getTokenData(salt);
        if (minted) revert AlreadyMinted();
        _mintAndSetExtraDataUnchecked(to, salt, _packMinted(nonce));
    }

    ////////////////////////////////////////////////////////////////
    //                         DEPLOYMENT                         //
    ////////////////////////////////////////////////////////////////

    function deploy(uint256 id, bytes calldata initcode) public payable returns (address deployed) {
        if (!approvedOrOwner(msg.sender, id)) revert NotOwnerNorApproved();
        (, uint8 nonce) = getTokenData(id);
        bytes memory deployProxyInitcode = DEPLOY_PROXY_INITCODE;
        assembly ("memory-safe") {
            let deployProxy := create2(callvalue(), add(deployProxyInitcode, 0x20), mload(deployProxyInitcode), id)
            let m := mload(0x40)
            mstore8(m, nonce)
            calldatacopy(add(m, 1), initcode.offset, initcode.length)
        }
    }

    ////////////////////////////////////////////////////////////////
    //                          HELPERS                           //
    ////////////////////////////////////////////////////////////////

    function approvedOrOwner(address operator, uint256 id) public view returns (bool) {
        address owner = ownerOf(id);
        return operator == owner || isApprovedForAll(owner, operator) || getApproved(id) == operator;
    }

    function getTokenData(uint256 id) public view returns (bool minted, uint8 nonce) {
        uint96 extraData = _getExtraData(id);
        minted = extraData & MINTED_BIT != 0;
        nonce = uint8(extraData);
    }

    function addressOf(uint256 id) public view returns (address vanity) {
        (bool minted, uint8 nonce) = getTokenData(id);
        if (!minted) revert TokenDoesNotExist();
        vanity = computeAddress(bytes32(id), nonce);
    }

    function computeAddress(bytes32 salt, uint8 nonce) public view returns (address vanity) {
        address deployProxy = Create2Lib.predict(DEPLOY_PROXY_INITHASH, salt, address(this));
        vanity = LibRLP.computeAddress(deployProxy, nonce);
    }

    function _packMinted(uint8 nonce) internal pure returns (uint96) {
        return uint96(nonce) | MINTED_BIT;
    }

    ////////////////////////////////////////////////////////////////
    //                          METADATA                          //
    ////////////////////////////////////////////////////////////////

    function name() public pure override returns (string memory) {
        return "Tradable Vanity Addresses";
    }

    function symbol() public pure override returns (string memory) {
        return "ADDR";
    }

    function tokenURI(uint256 id) public view override returns (string memory) {
        address currentRenderer = renderer;
        if (currentRenderer == address(0)) revert NoRenderer();
        address vanityAddr = addressOf(id);
        return IRenderer(currentRenderer).render(id, vanityAddr);
    }

    function _checkBuyer(address buyer) internal view {
        bool authorized;
        assembly ("memory-safe") {
            authorized := or(iszero(buyer), eq(buyer, caller()))
        }
        if (!authorized) revert NotAuhtorizedBuyer();
    }
}
