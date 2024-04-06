// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IRenderer} from "../../src/interfaces/IRenderer.sol";
import {LibString} from "solady/src/utils/LibString.sol";

/// @author philogy <https://github.com/philogy>
contract MockRenderer is IRenderer {
    using LibString for uint256;

    string _base;

    constructor(string memory base) {
        _base = base;
    }

    function setBase(string memory base) external {
        _base = base;
    }

    function render(uint256, address, uint8 nonce) external view returns (string memory) {
        return string.concat(_base, uint256(nonce).toString());
    }
}
