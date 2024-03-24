// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @author philogy <https://github.com/philogy>
contract MockDeployProxy {
    function deploy(address nonceIncreaser, uint8 skipNonce, bytes memory initcode)
        external
        payable
        returns (address addr)
    {
        (bool suc,) = nonceIncreaser.delegatecall(bytes.concat(bytes1(skipNonce)));
        require(suc, "FAILED_INCREASE");
        assembly ("memory-safe") {
            addr := create(callvalue(), add(initcode, 0x20), mload(initcode))
        }
    }
}
