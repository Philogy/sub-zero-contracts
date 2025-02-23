// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {HuffTest} from "./base/HuffTest.sol";
import {LibRLP} from "solady/src/utils/LibRLP.sol";
import {LibString} from "solady/src/utils/LibString.sol";
import {console2 as console} from "forge-std/console2.sol";

/// @author philogy <https://github.com/philogy>
contract DeployProxyTest is Test, HuffTest {
    using LibString for *;

    function setUp() public {
        setupBase_ffi();
    }

    function test_ffi_increases() public {
        bytes memory deployerInitcode = _huffInitcode("src/deploy-proxy/DeployProxy.huff");

        for (uint256 i = 0; i < 256; i++) {
            address deployer = deployRaw(deployerInitcode);
            (bool success, bytes memory ret) = deployer.call(bytes.concat(bytes1(uint8(i))));
            assertTrue(success);
            assertEq(ret.length, 0x20, "Unexpected returndata length");
            address deployed = abi.decode(ret, (address));
            assertValidNonce(deployed, address(deployer), i + 1);
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

    function fail(string memory err) internal pure {
        assertTrue(false, err);
    }
}
