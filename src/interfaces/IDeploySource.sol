// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @author philogy <https://github.com/philogy>
interface IDeploySource {
    function prime(bytes calldata payload) external;

    function get() external returns (bytes memory runtime, address initializer, bytes memory initializerPayload);
}
