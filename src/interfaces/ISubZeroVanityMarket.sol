// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @author philogy <https://github.com/philogy>
interface ISubZeroVanityMarket {
    function mint(address to, uint256 id, uint8 nonce) external;
}
