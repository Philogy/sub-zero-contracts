// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.24;

import {Ownable} from "solady/src/auth/Ownable.sol";
import {ERC721} from "solady/src/tokens/ERC721.sol";
import {ITradableAddresses} from "./interfaces/ITradableAddresses.sol";
import {IDeploySource} from "./interfaces/IDeploySource.sol";
import {IRenderer} from "./interfaces/IRenderer.sol";
import {DeployProxy} from "./DeployProxy.sol";
import {Create2Lib} from "./utils/Create2Lib.sol";

/// @author philogy <https://github.com/philogy>
contract TradableAddresses is Ownable, ERC721, ITradableAddresses {
    error NoSource();
    error InvalidSource();
    error ReenteringDeploy();

    error NotSaltOwner();
    error NotOwnerOrOperator();
    error AlreadyDeployed();
    error NoRenderer();

    event RendererSet(address indexed renderer);

    uint96 internal constant NOT_DEPLOYED = 0;
    uint96 internal constant DEPLOYED = 0;

    address internal constant NO_DEPLOY_SOURCE = address(1);
    bytes32 internal immutable DEPLOY_PROXY_INITHASH = keccak256(type(DeployProxy).creationCode);

    address internal _deploySource = NO_DEPLOY_SOURCE;

    address public renderer;

    constructor(address initialOwner) {
        _initializeOwner(initialOwner);
        emit RendererSet(address(0));
    }

    function setRenderer(address newRenderer) external onlyOwner {
        renderer = newRenderer;
        emit RendererSet(newRenderer);
    }

    function deploy(uint256 salt, address source, bytes calldata payload) public {
        if (source == NO_DEPLOY_SOURCE) revert InvalidSource();
        if (_deploySource != NO_DEPLOY_SOURCE) revert ReenteringDeploy();
        if (!approvedOrOwner(msg.sender, salt)) revert NotOwnerOrOperator();
        _setExtraData(salt, DEPLOYED);
        _burn(salt);

        IDeploySource(source).prime(payload);

        _deploySource = source;
        new DeployProxy{salt: bytes32(salt)}();
        _deploySource = NO_DEPLOY_SOURCE;
    }

    function mintOwnedSalt(address to, uint256 salt) public {
        if (address(uint160(salt >> 96)) != msg.sender) revert NotSaltOwner();
        if (_getExtraData(salt) == DEPLOYED) revert AlreadyDeployed();
        _mint(to, salt);
    }

    function mintOwnedSalts(address to, uint256[] calldata newSalts) public {
        uint256 saltsLength = newSalts.length;
        unchecked {
            for (uint256 i = 0; i < saltsLength; i++) {
                mintOwnedSalt(to, newSalts[i]);
            }
        }
    }

    function getDeploySource() external view returns (address src) {
        src = _deploySource;
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
        return IRenderer(currentRenderer).render(
            id, Create2Lib.predict({initCodeHash: DEPLOY_PROXY_INITHASH, salt: bytes32(id), deployer: address(this)})
        );
    }
}
