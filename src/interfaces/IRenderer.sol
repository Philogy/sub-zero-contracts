// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @author philogy <https://github.com/philogy>
interface IRenderer {
    function contractURI() external view returns (string memory);

    function render(uint256 id, address addr, uint8 nonce) external view returns (string memory);
}
