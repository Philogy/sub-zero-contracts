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
import {LibRLP} from "solady/src/utils/LibRLP.sol";

/// @author philogy <https://github.com/philogy>
contract TradableAddresses is Ownable, PermitERC721 {
    using BytesLib for bytes;
    using SafeTransferLib for address;

    error NotAuhtorizedBuyer();
    error InvalidFee();

    error AlreadyCommited();
    error RevealTooSoon();
    error NotFreeSalt();
    error AlreadyMinted();
    error NotSaltOwnerOrApproved();

    error NoRenderer();
    error DeploymentFailed();

    event RendererSet(address indexed renderer);
    event FeeSet(uint16 fee);

    uint96 internal constant MINTED_BIT = 0x100;
    uint256 internal constant BPS = 10000;

    /// @dev Want to provide chain censoring / reorg attacks to frontrun the claim & reveal.
    uint256 internal constant COMMIT_REVEAL_DELAY = 10 minutes;

    // TODO: Mine and insert nonce incrementer.
    bytes internal DEPLOY_PROXY_INITCODE;
    bytes32 internal immutable DEPLOY_PROXY_INITHASH;

    bytes32 internal immutable MINT_AND_SELL_TYPEHASH = keccak256(
        "MintAndSell(bytes32 salt,uint8 saltNonce,uint256 amount,address beneficiary,address buyer,uint256 nonce,uint256 deadline)"
    );

    address public renderer;
    uint16 public buyFeeBps;

    mapping(bytes32 hash => uint256 time) public commitedAt;

    constructor(address initialOwner, address nonceIncreaser) {
        DEPLOY_PROXY_INITCODE = abi.encodePacked(
            hex"602e8060093d393df360013d8136033d3d843d363d3d3773", nonceIncreaser, hex"5af460051b9234f08152f3"
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
        if (amount > type(uint248).max) amount = address(this).balance;
        to.safeTransferETH(amount);
    }

    ////////////////////////////////////////////////////////////////
    //                          MINTING                           //
    ////////////////////////////////////////////////////////////////

    function mintAndBuyWithSig(
        address to,
        bytes32 salt,
        uint8 saltNonce,
        address beneficiary,
        uint256 sellerAmount,
        address buyer,
        uint256 nonce,
        uint256 deadline,
        bytes calldata signature
    ) external payable {
        _checkDeadline(deadline);
        address owner = _saltOwner(salt);
        _checkAndUseNonce(owner, nonce);
        _checkBuyer(buyer);
        bytes32 hash = _hashTypedData(
            keccak256(
                abi.encode(MINT_AND_SELL_TYPEHASH, salt, saltNonce, sellerAmount, beneficiary, buyer, nonce, deadline)
            )
        );
        // Deals with `address(0)` for us.
        _checkSignature(owner, hash, signature);

        _mint(to, salt, saltNonce);

        // Calculate buy cost such that retained fee is `buyFeeBps / BPS` of the cost.
        uint256 buyCost = sellerAmount * BPS / (BPS - buyFeeBps);
        // Checked subtraction will underflow if insufficient funds were sent.
        uint256 amountLeft = msg.value - buyCost;
        beneficiary.safeTransferETH(sellerAmount);
        if (amountLeft > 0) msg.sender.safeTransferETH(amountLeft);
    }

    function commit(bytes32 hash) external {
        if (commitedAt[hash] != 0) revert AlreadyCommited();
        commitedAt[hash] = block.timestamp;
    }

    function mintRevealed(address to, bytes32 salt, uint8 nonce) external {
        bytes32 hash = keccak256(abi.encodePacked(to, salt, nonce));
        if (commitedAt[hash] + COMMIT_REVEAL_DELAY > block.timestamp) revert RevealTooSoon();
        if (_saltOwner(salt) != address(0)) revert NotFreeSalt();
        _mint(to, salt, nonce);
    }

    function mint(address to, bytes32 salt, uint8 nonce) external {
        address owner = _saltOwner(salt);
        if (msg.sender != owner && !isApprovedForAll(owner, msg.sender)) revert NotSaltOwnerOrApproved();
        _mint(to, salt, nonce);
    }

    function _mint(address to, bytes32 salt, uint8 nonce) internal {
        uint256 id = uint256(salt);
        (bool minted,) = getTokenData(id);
        if (minted) revert AlreadyMinted();
        _mintAndSetExtraDataUnchecked(to, id, _packMinted(nonce));
    }

    ////////////////////////////////////////////////////////////////
    //                         DEPLOYMENT                         //
    ////////////////////////////////////////////////////////////////

    function deploy(uint256 id, bytes calldata initcode) external payable returns (address deployed) {
        if (!approvedOrOwner(msg.sender, id)) revert NotOwnerNorApproved();
        (, uint8 nonce) = getTokenData(id);
        bytes memory deployProxyInitcode = DEPLOY_PROXY_INITCODE;
        assembly ("memory-safe") {
            let deployProxy := create2(0, add(deployProxyInitcode, 0x20), mload(deployProxyInitcode), id)
            let m := mload(0x40)
            mstore8(m, nonce)
            calldatacopy(add(m, 1), initcode.offset, initcode.length)
            let success := call(gas(), deployProxy, callvalue(), m, add(initcode.length, 1), 0x00, 0x20)
            deployed := mload(0x00)
            // `and(iszero(x), y: 0/1)` is equivalent to `lt(x, y)`.
            if iszero(and(success, lt(iszero(deployed), eq(returndatasize(), 0x20)))) {
                mstore(0x00, 0x30116425 /* DeploymentFailed() */ )
                revert(0x1c, 0x04)
            }
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
        vanity = LibRLP.computeAddress(deployProxy, nonce + 1);
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

    function _saltOwner(bytes32 salt) internal pure returns (address) {
        return address(bytes20(salt));
    }
}
