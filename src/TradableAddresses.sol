// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {NFT_ERC6909} from "./utils/NFT_ERC6909.sol";
import {ITradableAddresses} from "./interfaces/ITradableAddresses.sol";
import {DeployProxy} from "./DeployProxy.sol";

/// @author philogy <https://github.com/philogy>
contract TradableAddresses is NFT_ERC6909, ITradableAddresses {
    error NotSaltOwner();
    error NotOwnerOrOperator();

    bytes32 public immutable DEPLOY_PROXY_INITHASH;

    address internal constant NO_DEPLOY_SOURCE = address(1);

    address private _deploySource = NO_DEPLOY_SOURCE;

    constructor() {
        DEPLOY_PROXY_INITHASH = keccak256(type(DeployProxy).creationCode);
    }

    modifier checkSaltOwner(bytes32 salt) {
        if (address(bytes20(salt)) != msg.sender) revert NotSaltOwner();
        _;
    }

    function deployWithSource(bytes32 salt, address source) external {
        uint256 id = saltToId(salt);
        if (!ownerOrOperater(msg.sender, id)) revert NotOwnerOrOperator();
        _burn(id);
        _deploySource = source;
        new DeployProxy{salt: salt}();
        _deploySource = NO_DEPLOY_SOURCE;
    }

    function mintOwnedSalt(address to, bytes32 salt) external checkSaltOwner(salt) {
        _mint(to, saltToId(salt));
    }

    function getDeploySource() external view returns (address src) {
        src = _deploySource;
        if (src == NO_DEPLOY_SOURCE) revert NoDeploySourceAvailable();
    }

    function ownerOrOperater(address operator, uint256 id) public view returns (bool) {
        address owner = ownerOf(id);
        return operator == owner || isOperator(owner, operator);
    }

    function saltToId(bytes32 salt) public pure returns (uint256) {
        return uint256(salt);
    }

    function name(uint256) public pure override returns (string memory) {
        return "Tradable Addresses";
    }

    function symbol(uint256) public pure override returns (string memory) {
        return "ADDR";
    }

    function tokenURI(uint256) public pure override returns (string memory) {
        return "broooooooooooooooooooooooooo";
    }
}
