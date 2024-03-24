// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {HuffTest} from "./base/HuffTest.sol";
import {MockDeployProxy} from "./mocks/MockDeployProxy.sol";
import {LibRLP} from "solady/src/utils/LibRLP.sol";

/// @author philogy <https://github.com/philogy>
contract NonceIncreaserTest is Test, HuffTest {
    address increaser = deployRaw(_huffInitcode("src/deploy-proxy/NonceIncreaser.huff"));

    function test_increases() public {
        address creaser = increaser;

        for (uint256 i = 0; i < 256; i++) {
            MockDeployProxy deployer = new MockDeployProxy();
            address deployed = deployer.deploy(creaser, uint8(i), new bytes(0));
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
