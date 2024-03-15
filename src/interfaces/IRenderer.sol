// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @author philogy <https://github.com/philogy>
interface IRenderer {
    function render(uint256 id, address addr) external view returns (string memory);
}
