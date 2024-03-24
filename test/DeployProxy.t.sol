// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {HuffTest} from "./base/HuffTest.sol";
import {MockDeployProxy} from "./mocks/MockDeployProxy.sol";
import {LibRLP} from "solady/src/utils/LibRLP.sol";
import {LibString} from "solady/src/utils/LibString.sol";

/// @author philogy <https://github.com/philogy>
contract DeployProxyTest is Test, HuffTest {
    using LibString for *;

    address increaser = deployRaw(_huffInitcode("src/deploy-proxy/NonceIncreaser.huff"));

    function test_increases() public {
        address creaser = increaser;
        string[] memory consts = new string[](1);
        consts[0] = string.concat("NONCE_INCREASER=", creaser.toHexString());
        bytes memory deployerInitcode = _huffInitcode("src/deploy-proxy/DeployProxy.huff", consts);

        for (uint256 i = 0; i < 256; i++) {
            address deployer = deployRaw(deployerInitcode);
            (bool success, bytes memory ret) = deployer.call(bytes.concat(bytes1(uint8(i))));
            assertTrue(success);
            address deployed = abi.decode(ret, (address));
            assertValidNonce(deployed, address(deployer), i + 1);
            assertEq(deployed, LibRLP.computeAddress(address(deployer), i + 1));
        }
    }

    function assertValidNonce(address finalAddr, address deployer, uint256 expectedNonce) internal {
        if (finalAddr != LibRLP.computeAddress(deployer, expectedNonce)) {
            bool broke;
            for (uint256 i = 0; i <= 512; i++) {
                if (finalAddr == LibRLP.computeAddress(deployer, i)) {
                    fail("Invalid nonce increase");
                    emit log_named_uint("expected nonce", expectedNonce);
                    emit log_named_uint("actual nonce", i);
                    broke = true;
                    break;
                }
            }
            if (!broke) fail("Wtf no nonce");
        }
    }
}
