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
        assembly ("memory-safe") {
            // Store all selectors: getDeploySource(), get(), MalformedPayload(), InitializationFailed()
            mstore(0x00, 0x94248f316d4ce63c7d0925de19b991a8)

            // Call `msg.sender.getDeploySource()`
            if iszero(staticcall(gas(), caller(), 0x10, 0x04, 0x20, 0x20)) { revert(0, 0) }

            let source := mload(0x20)
            // The `get()` method has no formal ABI return data type, expecting return data as raw
            // return data (not ABI encoded).
            let success := call(gas(), source, 0, 0x14, 0x04, 0, 0)
            // Check header size is at least 3 (to hold the length).
            if iszero(and(gt(returndatasize(), 2), success)) {
                // `revert MalformedPayload()`
                revert(0x18, 0x04)
            }
            // Get first 3 bytes which is the length.
            returndatacopy(0, 0, 3)
            // Decode runtime length
            let runtimeSize := shr(mul(8, 29), mload(0))
            // Ensure returndata size is at least [stated runtime size] + 3.
            if iszero(gt(returndatasize(), add(runtimeSize, 2))) { revert(0x1c, 0x04) }
            // Check if there is data beyond the runtime (meaning there's an initializer).
            let initOffset := add(runtimeSize, 3)
            let remainingSize := sub(returndatasize(), initOffset)
            // Copy runtime data.
            returndatacopy(0, 3, runtimeSize)
            // Handle non-empty remaining payload.
            if remainingSize {
                // If the remainder of the payload is non-zero expect at least 20 bytes for the
                // initializer address.
                if iszero(gt(remainingSize, 19)) {
                    // `revert MalformedPayload()`
                    revert(0x18, 0x04)
                }
                // Load initialization data.
                returndatacopy(runtimeSize, initOffset, 20)
                let initializer := shr(96, mload(runtimeSize))
                let initDataSize := sub(remainingSize, 20)
                let initDataStart := add(initOffset, 20)
                returndatacopy(runtimeSize, initDataStart, initDataSize)
                // Call into initializer.
                success := delegatecall(gas(), initializer, runtimeSize, initDataSize, 0, 0)
                if iszero(success) {
                    // `revert InitializationFailed()`
                    revert(0x1c, 0x04)
                }
            }
            return(0, runtimeSize)
        }
    }
}
