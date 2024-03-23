// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @author philogy <https://github.com/philogy>
contract FailingDeploy {
    constructor() {
        revert();
    }
}
