// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {ITradableAddresses} from "./interfaces/ITradableAddresses.sol";
import {IDeploySource} from "./interfaces/IDeploySource.sol";
import {BytesLib} from "./utils/BytesLib.sol";

/**
 * @author philogy <https://github.com/philogy>
 * @dev Contract that actually deploys your contract.
 */
contract DeployProxy {
    using BytesLib for bytes;

    error InvalidSource();
    error FailedToRetrieveSource();
    error EmptySourceReturned();

    constructor() {
        address deploySrc = ITradableAddresses(msg.sender).getDeploySource();

        if (deploySrc == address(0) || deploySrc.code.length == 0) revert InvalidSource();

        // Delegatecall allows source to make initializing state mutations if necessary.
        (bool success, bytes memory retBytes) = deploySrc.delegatecall(abi.encodeCall(IDeploySource.prepareRuntime, ()));
        if (!success) revert FailedToRetrieveSource();
        bytes memory runtime = retBytes.decodeBytes();
        if (runtime.length == 0) revert EmptySourceReturned();

        runtime.directReturn();
    }
}
