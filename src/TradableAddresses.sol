// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.24;

import {Ownable} from "solady/src/auth/Ownable.sol";
import {ERC721} from "solady/src/tokens/ERC721.sol";
import {ITradableAddresses} from "./interfaces/ITradableAddresses.sol";
import {IDeploySource} from "./interfaces/IDeploySource.sol";
import {IRenderer} from "./interfaces/IRenderer.sol";
import {DeployProxy} from "./DeployProxy.sol";
import {Create2Lib} from "./utils/Create2Lib.sol";
import {BytesLib} from "./utils/BytesLib.sol";
import {SaltLib} from "./utils/SaltLib.sol";
import {TransientBytes} from "./utils/TransientBytes.sol";

/// @author philogy <https://github.com/philogy>
contract TradableAddresses is Ownable, ERC721, ITradableAddresses, IDeploySource {
    using BytesLib for bytes;
    using SaltLib for uint256;

    error NoSource();
    error InvalidSource();
    error ReenteringDeploy();

    error NotOwnerOrOperator();
    error AlreadyMinted();
    error NoRenderer();

    event RendererSet(address indexed renderer);

    uint96 internal constant NOT_MINTED = 0;
    uint96 internal constant ALREADY_MINTED = 1;

    address internal constant NO_DEPLOY_SOURCE = address(1);
    bytes32 internal immutable DEPLOY_PROXY_INITHASH = keccak256(type(DeployProxy).creationCode);

    address internal _deploySource = NO_DEPLOY_SOURCE;
    TransientBytes internal _payloadCache;

    address public renderer;

    constructor(address initialOwner) {
        _initializeOwner(initialOwner);
    }

    function setRenderer(address newRenderer) external onlyOwner {
        renderer = newRenderer;
        emit RendererSet(newRenderer);
    }

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

    function mint(address to, uint256 salt) public {
        if (msg.sender != address(this)) {
            address owner = salt.owner();
            if (msg.sender != owner && !isApprovedForAll(owner, msg.sender)) revert NotOwnerOrOperator();
        }
        if (alreadyMinted(salt)) revert AlreadyMinted();
        _mintAndSetExtraDataUnchecked(to, salt, ALREADY_MINTED);
    }

    function mintMany(address to, uint256[] calldata newSalts) public {
        uint256 saltsLength = newSalts.length;
        unchecked {
            for (uint256 i = 0; i < saltsLength; i++) {
                mint(to, newSalts[i]);
            }
        }
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

    function alreadyMinted(uint256 id) public view returns (bool) {
        return _getExtraData(id) == ALREADY_MINTED;
    }

    function approvedOrOwner(address operator, uint256 id) public view returns (bool) {
        address owner = ownerOf(id);
        return operator == owner || isApprovedForAll(owner, operator);
    }

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
