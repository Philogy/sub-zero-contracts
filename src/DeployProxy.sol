// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.24;

import {ITradableAddresses} from "./interfaces/ITradableAddresses.sol";
import {IDeploySource} from "./interfaces/IDeploySource.sol";
import {BytesLib} from "./utils/BytesLib.sol";

/**
 * @author philogy <https://github.com/philogy>
 * @dev Contract that actually deploys your contract.
 */
contract DeployProxy {
    using BytesLib for bytes;

    error InitializationFailed();

    constructor() {
        address source = ITradableAddresses(msg.sender).getDeploySource();
        (bytes memory runtime, address initializer, bytes memory initializerPayload) = IDeploySource(source).get();

        // Optional initializer that can do initial state mutations on behalf of the new contract.
        if (initializer != address(0)) {
            (bool success,) = initializer.delegatecall(initializerPayload);
            if (!success) revert InitializationFailed();
        }

        runtime.directReturn();
    }
}
