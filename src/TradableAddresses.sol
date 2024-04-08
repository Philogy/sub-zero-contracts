// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.24;

// Base contracts & interfaces.
import {Ownable} from "solady/src/auth/Ownable.sol";
import {PermitERC721} from "./base/PermitERC721.sol";
import {IRenderer} from "./interfaces/IRenderer.sol";
// Libraries.
import {SafeTransferLib} from "solady/src/utils/SafeTransferLib.sol";
import {Create2Lib} from "./utils/Create2Lib.sol";
import {LibRLP} from "solady/src/utils/LibRLP.sol";

/**
 * @author philogy <https://github.com/philogy>
 * @notice A contract that allows tokenizing, transfering and selling vanity addresses. Addresses are
 * made independent from the to-be-deployed bytecode via the "CREATE3" pattern.
 * @dev Methods are grouped by functionality / purpose rather than public / view / internal for the
 * sake of legibility. Added events on common user methods are avoided for the sake of gas and
 * because indirect events are already emitted by the underyling ERC721 implementation.
 */
contract TradableAddresses is Ownable, PermitERC721 {
    using SafeTransferLib for address;

    error NotAuthorizedBuyer();
    error InsufficientValue();
    error InvalidFee();

    error AlreadyMinted();

    error NoRenderer();
    error RendererLockedIn();
    error DeploymentFailed();

    event RendererSet(address indexed renderer);
    event FeeSet(uint16 fee);

    uint96 internal constant MINTED_BIT = 0x100;
    uint256 internal constant BPS = 10000;

    uint256 internal constant DEPLOY_PROXY_INITCODE_0_32 =
        0x60288060093d393df36001600581360334348434363434376d01e4a82b33373d;
    uint256 internal constant DEPLOY_PROXY_INITCODE_32_17 = 0xe1334e7d8f48795af49247f034521b34f3;

    bytes32 public immutable DEPLOY_PROXY_INITHASH = keccak256(
        hex"60288060093d393df36001600581360334348434363434376d01e4a82b33373de1334e7d8f48795af49247f034521b34f3"
    );

    bytes32 internal immutable MINT_AND_SELL_TYPEHASH = keccak256(
        "MintAndSell(uint256 id,uint8 saltNonce,uint256 price,address beneficiary,address buyer,uint256 nonce,uint256 deadline)"
    );

    address public renderer;
    uint16 public feeBps;

    constructor(address initialOwner) {
        _initializeOwner(initialOwner);
    }

    ////////////////////////////////////////////////////////////////
    //                           ADMIN                            //
    ////////////////////////////////////////////////////////////////

    /**
     * @dev Set the renderer contract that creates the graphic & metadata representation returned
     * from the `tokenURI(...)` method.
     * @param newRenderer Address of the new renderer contract. If it has 6 leading zero bytes it
     * will be considered immutable.
     */
    function setRenderer(address newRenderer) external onlyOwner {
        address currentRenderer = renderer;
        // If the `currentRenderer` is set (not the zero address) and has at least 6 leading zero
        // bytes (numerically smaller than 2^(160 - 8 * 6)) it's considered immutable.
        if (currentRenderer != address(0) && uint160(currentRenderer) < 1 << 112) revert RendererLockedIn();

        renderer = newRenderer;
        emit RendererSet(newRenderer);
    }

    /**
     * @dev Change the contract's buy fee.
     * @param newFee The new fee in basis points.
     */
    function setFee(uint16 newFee) external onlyOwner {
        if (newFee >= BPS) revert InvalidFee();
        emit FeeSet(feeBps = newFee);
    }

    /**
     * @dev Withdraws leftover held ETH from the contract.
     * @param to The address to receive the ETH.
     * @param amount The amount of ETH to withdraw. If greater than or equal to 2^248 will withdraw
     * all available ETH.
     */
    function withdraw(address to, uint256 amount) external onlyOwner {
        if (amount > type(uint248).max) amount = address(this).balance;
        to.safeTransferETH(amount);
    }

    ////////////////////////////////////////////////////////////////
    //                          MINTING                           //
    ////////////////////////////////////////////////////////////////

    /**
     * @dev Buys an unminted tradable address from the owner that mined it. The price is denominated
     * in ETH. On top of the specified `sellerPrice` the caller has to supply value such that it
     * satisfies the contract's royalty or "buy fee" (calculated via the `calculateBuyCost` method).
     * Any value provided above the calculated buy cost will be returned, note that a sudden fee
     * change may capture any delta. Do not specify a value higher than what you're willing to pay.
     * @notice Mint & buy a vanity address from the actual salt owner using an off-chain approval.
     * @param to The address that'll receive the token.
     * @param id The token's salt and subsequently id.
     * @param saltNonce The create3 nonce *increase* to tie to the token. The deploy proxy's final
     * deployment nonce will be qual to `saltNonce + 1`. This is because contract nonces start at 1.
     * @param beneficiary The recipient of the ETH sale proceeds. Note that this can be different
     * than the salt's owner.
     * @param sellerPrice The sale proceeds to be sent to the `beneficiary`.
     * @param buyer The address that's authorized to complete the purchase, `address(0)` if it's
     * meant to be open to anyone.
     * @param nonce The salt owner's nonce.
     * @param deadline Timestamp until which the sale intent is valid.
     * @param signature ECDSA (r, s, v), ERC2098 compressed ECDSA (r, vs), or ERC-1271 signature
     * from the salt owner for the `MintAndSell` struct.
     */
    function mintAndBuyWithSig(
        address to,
        uint256 id,
        uint8 saltNonce,
        address beneficiary,
        uint256 sellerPrice,
        address buyer,
        uint256 nonce,
        uint256 deadline,
        bytes calldata signature
    ) external payable {
        _checkDeadline(deadline);
        address owner = _saltOwner(id);
        _checkAndUseNonce(owner, nonce);

        uint256 buyCost = calculateBuyCost(sellerPrice);
        if (buyCost > msg.value) revert InsufficientValue();

        _checkBuyer(buyer);
        bytes32 hash = _hashTypedData(
            keccak256(
                abi.encode(MINT_AND_SELL_TYPEHASH, id, saltNonce, sellerPrice, beneficiary, buyer, nonce, deadline)
            )
        );
        // Deals with `address(0)` for us.
        _checkSignature(owner, hash, signature);

        _mint(to, id, saltNonce);

        unchecked {
            // Guaranteed not to overflow due to above check (`buyCost > msg.value`).
            uint256 amountLeft = msg.value - buyCost;
            if (sellerPrice > 0) beneficiary.safeTransferETH(sellerPrice);
            if (amountLeft > 0) msg.sender.safeTransferETH(amountLeft);
        }
    }

    /**
     * @notice Calculate the final buyer's cost given a price and the current fee rate.
     * @param sellerPrice Input price in ETH.
     * @return Buyer's final total cost in ETH.
     */
    function calculateBuyCost(uint256 sellerPrice) public view returns (uint256) {
        return sellerPrice * BPS / (BPS - feeBps);
    }

    /**
     * @dev Mints a salt you own or on behalf of the owner if they've approved you.
     * @notice Mint a vanity address token.
     * @param to Address to receive the newly minted token.
     * @param id The CREATE3 salt for the vanity address to be used. Will also be the token ID
     * for the resulting ERC-721 NFT.
     * @param nonce The CREATE3 nonce increase for the vanity address to be deployed. The actual
     * deployment nonce will be `nonce + 1` because contract nonces start at 1.
     */
    function mint(address to, uint256 id, uint8 nonce) external {
        address owner = _saltOwner(id);
        if (msg.sender != owner && !isApprovedForAll(owner, msg.sender)) revert NotOwnerNorApproved();
        _mint(to, id, nonce);
    }

    function _mint(address to, uint256 id, uint8 nonce) internal {
        (bool minted,) = getTokenData(id);
        if (minted) revert AlreadyMinted();
        _mintAndSetExtraDataUnchecked(to, id, uint96(nonce) | MINTED_BIT);
    }

    ////////////////////////////////////////////////////////////////
    //                         DEPLOYMENT                         //
    ////////////////////////////////////////////////////////////////

    /**
     * @dev Deploys code to the address underlying the `id` token. Burns the token and requires
     * the caller to have authorization to transfer the token (direct owner, universal operator or
     * token approval).
     * @param id Address token to deploy and burn.
     * @param initcode Full bytecode including the initialization (or "constructor") code.
     * @return deployed The address of the contract.
     */
    function deploy(uint256 id, bytes calldata initcode) external payable returns (address deployed) {
        // Access control for the token is handled by `ERC721._burn`.
        _burn(msg.sender, id);
        (, uint8 nonce) = getTokenData(id);
        assembly ("memory-safe") {
            mstore(17, DEPLOY_PROXY_INITCODE_32_17)
            mstore(0, DEPLOY_PROXY_INITCODE_0_32)
            // Passing value via create is cheaper than passing it via the call.
            let deployProxy := create2(callvalue(), 0, 49, id)
            let m := mload(0x40)
            mstore8(m, nonce)
            calldatacopy(add(m, 1), initcode.offset, initcode.length)
            let success := call(gas(), deployProxy, 0, m, add(initcode.length, 1), 0x00, 0x20)
            deployed := mload(0x00)
            // Checks that `success` is `true` (1), the loaded address is non-zero and that the
            // actual returndata has the expected size (32).
            if iszero(and(success, lt(iszero(deployed), eq(returndatasize(), 0x20)))) {
                mstore(0x00, 0x30116425 /* DeploymentFailed() */ )
                revert(0x1c, 0x04)
            }
        }
    }

    ////////////////////////////////////////////////////////////////
    //                          HELPERS                           //
    ////////////////////////////////////////////////////////////////

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

    /// @dev Checks that the caller is either equal to `buyer` or `buyer` is the zero address.
    function _checkBuyer(address buyer) internal view {
        assembly ("memory-safe") {
            if iszero(or(iszero(buyer), eq(buyer, caller()))) {
                mstore(0x00, 0xd7fce0a8 /* NotAuthorizedBuyer() */ )
                revert(0x1c, 0x04)
            }
        }
    }

    function _saltOwner(uint256 id) internal pure returns (address) {
        return address(uint160(id >> 96));
    }

    ////////////////////////////////////////////////////////////////
    //                          METADATA                          //
    ////////////////////////////////////////////////////////////////

    function name() public pure override returns (string memory) {
        return "Tokenized CREATE3 Vanity Addresses";
    }

    function symbol() public pure override returns (string memory) {
        return "ADDR";
    }

    function tokenURI(uint256 id) public view override returns (string memory) {
        address currentRenderer = renderer;
        if (currentRenderer == address(0)) revert NoRenderer();
        (bool minted, uint8 nonce) = getTokenData(id);
        if (!minted) revert TokenDoesNotExist();
        address vanityAddr = computeAddress(bytes32(id), nonce);
        return IRenderer(currentRenderer).render(id, vanityAddr, nonce);
    }
}
