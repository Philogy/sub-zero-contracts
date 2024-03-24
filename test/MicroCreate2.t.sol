// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Test} from "forge-std/Test.sol";
import {FailingDeploy} from "./mocks/FailingDeploy.sol";
import {MockSimple} from "./mocks/MockSimple.sol";

/// @author philogy <https://github.com/philogy>
contract MicroCreate2Test is Test {
    address micro;

    function setUp() public {
        bytes memory c = _code();
        address m;
        assembly ("memory-safe") {
            m := create(0, add(c, 0x20), mload(c))
        }
        micro = m;
    }

    function test_inception() public {
        bytes memory c = _code();
        bytes32 salt = 0x736910e11ee80955bc66400158e50c2f7318633f228ac93e3edf7fe7f1341daf;
        (bool success, bytes memory ret) = micro.call(abi.encodePacked(salt, c));
        assertTrue(success);
        assertEq(ret.length, 32);
        address addr = abi.decode(ret, (address));
        assertEq(addr, _predict(salt, c));
        assertEq(addr.code, micro.code);
    }

    function test_failing() public {
        bytes32 salt = bytes32(0);
        (bool success, bytes memory ret) = micro.call(abi.encodePacked(salt, type(FailingDeploy).creationCode));
        assertFalse(success);
        assertEq(ret.length, 0);
    }

    function test_deploySimple() public {
        bytes32 salt = 0xfc45227641c800fe11b798e04e9ea73109474f9f14ac55a59c55e6d593bbba5a;
        address dev = makeAddr("dev");
        address user = makeAddr("user");
        bytes memory initcode = abi.encodePacked(type(MockSimple).creationCode, abi.encode(dev));
        (bool success, bytes memory ret) = micro.call(abi.encodePacked(salt, initcode));
        assertTrue(success);
        assertEq(ret.length, 32);
        address addr = abi.decode(ret, (address));
        assertEq(addr, _predict(salt, initcode));

        MockSimple simple = MockSimple(addr);
        assertEq(simple.balanceOf(dev), 10e18);
        assertEq(simple.balanceOf(user), 0);
    }

    function _predict(bytes32 salt, bytes memory initcode) internal view returns (address) {
        bytes32 hash = keccak256(abi.encodePacked(hex"ff", micro, salt, keccak256(initcode)));
        return address(uint160(uint256(hash)));
    }

    function _code() internal returns (bytes memory) {
        string[] memory args = new string[](4);
        args[0] = "huffy";
        args[1] = "-b";
        args[2] = "src/micro-create2/MicroCreate2.huff";
        args[3] = "--avoid-push0";
        return vm.ffi(args);
    }
}
