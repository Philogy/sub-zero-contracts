// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.24;

// Base contracts & interfaces.
import {Ownable} from "solady/src/auth/Ownable.sol";
import {PermitERC721} from "./base/PermitERC721.sol";
import {ITradableAddresses} from "./interfaces/ITradableAddresses.sol";
import {IRenderer} from "./interfaces/IRenderer.sol";
// Source & deployment.
import {IDeploySource} from "./interfaces/IDeploySource.sol";
import {TransientBytes} from "./utils/TransientBytes.sol";
import {DeployProxy} from "./DeployProxy.sol";
// Libraries.
import {SafeTransferLib} from "solady/src/utils/SafeTransferLib.sol";
import {SignatureCheckerLib} from "solady/src/utils/SignatureCheckerLib.sol";
import {Create2Lib} from "./utils/Create2Lib.sol";
import {BytesLib} from "./utils/BytesLib.sol";
import {SaltLib} from "./utils/SaltLib.sol";

/// @author philogy <https://github.com/philogy>
contract TradableAddresses is Ownable, PermitERC721, ITradableAddresses, IDeploySource {
    using BytesLib for bytes;
    using SaltLib for uint256;
    using SafeTransferLib for address;

    error InvalidFee();

    error PastDeadline();
    error InvalidSignature();

    error NoSource();
    error InvalidSource();
    error ReenteringDeploy();

    error NotOwnerOrOperator();
    error AlreadyMinted();
    error NoRenderer();

    event RendererSet(address indexed renderer);
    event FeeSet(uint16 fee);

    uint96 internal constant NOT_MINTED = 0;
    uint96 internal constant ALREADY_MINTED = 1;
    uint256 internal constant BPS = 10000;

    bytes32 internal immutable MINT_AND_SELL_TYPEHASH =
        keccak256("MintAndSell(uint256 salt,uint256 amount,address beneficiary,uint256 nonce,uint256 deadline)");

    address internal constant NO_DEPLOY_SOURCE = address(1);
    bytes32 internal immutable DEPLOY_PROXY_INITHASH = keccak256(type(DeployProxy).creationCode);

    address internal _deploySource = NO_DEPLOY_SOURCE;
    TransientBytes internal _payloadCache;

    address public renderer;
    uint16 public buyFeeBps;

    constructor(address initialOwner) {
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
        address beneficiary,
        uint256 sellerAmount,
        uint256 nonce,
        uint256 deadline,
        bytes calldata signature
    ) external payable {
        // Validate sale.
        if (block.timestamp > deadline) revert PastDeadline();
        bytes32 hash = _hashTypedData(
            keccak256(abi.encode(MINT_AND_SELL_TYPEHASH, salt, sellerAmount, beneficiary, nonce, deadline))
        );
        address owner = salt.owner();
        if (!SignatureCheckerLib.isValidSignatureNowCalldata(owner, hash, signature)) revert InvalidSignature();
        _useNonce(owner, nonce);
        _mint(to, salt);
        // Distribute ETH (fee is kept as contract balance).
        uint256 feeRate = buyFeeBps;
        uint256 fee = sellerAmount * feeRate / (BPS - feeRate);
        uint256 amountLeft = msg.value - fee - sellerAmount;
        beneficiary.safeTransferETH(sellerAmount);
        if (amountLeft > 0) msg.sender.safeTransferETH(amountLeft);
    }

    ////////////////////////////////////////////////////////////////
    //                          MINTING                           //
    ////////////////////////////////////////////////////////////////

    function mint(address to, uint256 salt) public {
        if (msg.sender != address(this)) {
            address owner = salt.owner();
            if (msg.sender != owner && !isApprovedForAll(owner, msg.sender)) revert NotOwnerOrOperator();
        }
        _mint(to, salt);
    }

    function mintMany(address to, uint256[] calldata newSalts) public {
        uint256 saltsLength = newSalts.length;
        unchecked {
            for (uint256 i = 0; i < saltsLength; i++) {
                mint(to, newSalts[i]);
            }
        }
    }

    function _mint(address to, uint256 salt) internal override {
        if (alreadyMinted(salt)) revert AlreadyMinted();
        _mintAndSetExtraDataUnchecked(to, salt, ALREADY_MINTED);
    }

    ////////////////////////////////////////////////////////////////
    //                   DEPLOYMENT & SOURCING                    //
    ////////////////////////////////////////////////////////////////

    function deploy(uint256 salt, address source, bytes calldata payload) public payable returns (address deployed) {
        if (source == NO_DEPLOY_SOURCE) revert InvalidSource();
        if (_deploySource != NO_DEPLOY_SOURCE) revert ReenteringDeploy();
        if (!approvedOrOwner(msg.sender, salt)) revert NotOwnerOrOperator();
        _burn(salt);

        if (source == address(0) || source == address(this)) store(payload);
        else IDeploySource(source).store(payload);

        // Poor man's transient storage to ensure backwards compatibility with pre-Dencun
        // EVM chains.
        _deploySource = source;
        deployed = address(new DeployProxy{salt: bytes32(salt), value: msg.value}());
        _deploySource = NO_DEPLOY_SOURCE;
    }

    function store(bytes calldata payload) public override {
        _payloadCache.store(payload);
    }

    function load() external override {
        bytes memory payload = _payloadCache.load();
        _payloadCache.reset();
        payload.directReturn();
    }

    function getDeploySource() external view returns (address src) {
        src = _deploySource;
    }

    ////////////////////////////////////////////////////////////////
    //                          HELPERS                           //
    ////////////////////////////////////////////////////////////////

    function alreadyMinted(uint256 id) public view returns (bool) {
        return _getExtraData(id) == ALREADY_MINTED;
    }

    function approvedOrOwner(address operator, uint256 id) public view returns (bool) {
        address owner = ownerOf(id);
        return operator == owner || isApprovedForAll(owner, operator);
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
        address vanityAddr =
            Create2Lib.predict({initCodeHash: DEPLOY_PROXY_INITHASH, salt: bytes32(id), deployer: address(this)});
        return IRenderer(currentRenderer).render(id, vanityAddr);
    }
}
