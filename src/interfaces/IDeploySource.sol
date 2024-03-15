// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @author philogy <https://github.com/philogy>
interface IDeploySource {
    function store(bytes calldata payload) external;

    /**
     * @dev Expects a direct return i.e. the payload is returned without ABI encoding as raw return
     * data. The expected format is, packed: [bytes3(runtime_size) | runtime_data | bytes20(initializer)
     * | initData]. Where | represents bytes concatenation, and everything after the `runtime_data`
     * is optional.
     */
    function load() external;
}
