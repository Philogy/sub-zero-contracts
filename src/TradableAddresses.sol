// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {ERC1155Unique} from "./utils/ERC1155Unique.sol";
import {ITradableAddresses} from "./interfaces/ITradableAddresses.sol";
import {DeployProxy} from "./DeployProxy.sol";

/// @author philogy <https://github.com/philogy>
contract TradableAddresses is ERC1155Unique, ITradableAddresses {
    error NotSaltOwner();
    error NotOwnerOrOperator();
    error AlreadyDeployed();

    bytes32 public immutable DEPLOY_PROXY_INITHASH;

    address internal constant NO_DEPLOY_SOURCE = address(1);

    address private _deploySource = NO_DEPLOY_SOURCE;

    struct Salt {
        address owner;
        bool deployed;
    }

    mapping(address => Salt) public salts;

    constructor() {
        DEPLOY_PROXY_INITHASH = keccak256(type(DeployProxy).creationCode);
    }

    function deployWithSource(uint salt, address source) external {
        if (!approvedOrOwner(msg.sender, salt)) revert NotOwnerOrOperator();
        salts[salt].deployed = true;
        _burn(salt);

        _deploySource = source;
        new DeployProxy{salt: bytes32(salt)}();
        _deploySource = NO_DEPLOY_SOURCE;
    }

    function mintOwnedSalt(address to, uint256 salt) public {
        _checkNewSalt(salt);
        _mint(to, salt, new bytes(0));
    }

    function mintOwnedSalts(address to, uint256[] memory newSalts) public {
        uint256 saltsLength = newSalts.length;
        unchecked {
            for (uint256 i = 0; i < saltsLength; i++) {
                _checkNewSalt(newSalts[i]);
            }
        }
        _batchMint(to, newSalts, new bytes(0));
    }

    function ownerOf(uint256 id) public view override returns (address) {
        return salts[id].owner;
    }

    function getDeploySource() external view returns (address src) {
        src = _deploySource;
        if (src == NO_DEPLOY_SOURCE) revert NoDeploySourceAvailable();
    }

    function approvedOrOwner(address operator, uint256 id) public view returns (bool) {
        address owner = ownerOf[id];
        return operator == owner || isApprovedForAll[owner][operator];
    }

    function uri(uint256) public pure override returns (string memory) {
        return "TODO";
    }

    function _setOwnerOf(uint256 id, address owner) internal override {
        salts[id].owner = owner;
    }

    function _checkNewSalt(uint256 salt) internal view {
        if (address(uint160(salt >> 96)) != msg.sender) revert NotSaltOwner();
        if (salts[salt].deployed) revert AlreadyDeployed();
    }
}
