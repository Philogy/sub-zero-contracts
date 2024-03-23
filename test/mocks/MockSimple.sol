// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @author philogy <https://github.com/philogy>
contract MockSimple {
    mapping(address => uint256) public balanceOf;

    constructor(address addr) {
        balanceOf[addr] = 10e18;
    }
}
