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
    error MalformedPayload();

    constructor() payable {
        address source = ITradableAddresses(msg.sender).getDeploySource();

        assembly ("memory-safe") {
            // The `get()` method has no formal ABI return data type, expecting return data as raw
            // return data (not ABI encoded).
            mstore(0x00, 0x6d4ce63c /* get() */ )
            let success := call(gas(), source, 0, 0x1c, 0x04, 0, 0)
            // Check header size is at least 3 (to hold the length).
            if iszero(and(gt(returndatasize(), 2), success)) {
                mstore(0x00, 0x7d0925de /* MalformedPayload() */ )
                revert(0x1c, 0x04)
            }
            // Get first 3 bytes which is the length.
            returndatacopy(0, 0, 3)
            // Decode runtime length
            let runtimeSize := shr(mul(8, 29), mload(0))
            // Ensure returndata size is at least [stated runtime size] + 3.
            if iszero(gt(returndatasize(), add(runtimeSize, 2))) {
                mstore(0x00, 0x7d0925de /* MalformedPayload() */ )
                revert(0x1c, 0x04)
            }
            // Check if there is data beyond the runtime (meaning there's an initializer).
            let initOffset := add(runtimeSize, 3)
            let remainingSize := sub(returndatasize(), initOffset)
            // Handle non-empty remaining payload.
            if remainingSize {
                // If the remainder of the payload is non-zero expect at least 20 bytes for the
                // initializer address.
                if iszero(gt(remainingSize, 19)) {
                    mstore(0x00, 0x7d0925de /* MalformedPayload() */ )
                    revert(0x1c, 0x04)
                }
                // Load initialization data.
                returndatacopy(0, initOffset, 20)
                let initializer := shr(96, mload(0))
                let initDataSize := sub(remainingSize, 20)
                let initDataStart := add(initOffset, 20)
                returndatacopy(0, initDataStart, initDataSize)
                // Call into initializer.
                success := delegatecall(gas(), initializer, 0, initDataSize, 0, 0)
                if iszero(success) {
                    mstore(0x00, 0x19b991a8 /* InitializationFailed() */ )
                    revert(0x1c, 0x04)
                }
            }
            // Copy and return runtime data.
            returndatacopy(0, 3, runtimeSize)
            return(0, runtimeSize)
        }
    }
}
