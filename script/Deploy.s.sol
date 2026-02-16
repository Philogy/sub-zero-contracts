// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console2 as console} from "forge-std/console2.sol";
import {CreationCodes} from "./utils/CreationCodes.sol";
import {Addresses} from "src/utils/Addresses.sol";

interface ICreateX {
    function deployCreate2(bytes32 salt, bytes calldata initCode) external payable returns (address);
}

/**
 * @notice Main script entrypoint. Deploys contracts with expected vanity addresses to the chain.
 * @author philogy <https://github.com/philogy>
 */
contract DeployScript is Script, Addresses, CreationCodes {
    ICreateX constant CREATEX = ICreateX(0xba5Ed099633D3B313e4D5F7bdc1305d3c28ba5Ed);

    address constant MARKET_OWNER = 0xea57c1ef7eF1c88b456ADf0927ec0EAe3B17f1F5;
    bytes32 constant MARKET_SALT = 0x000000000000000000000000000000000000000094038e9be572f900652a472c;

    function deployMicroCreate2(bytes32 _salt, address _expectedAddress) public {
        if (_expectedAddress.code.length != 0) {
            console.log("MicroCreate2 already deployed");
            return;
        }

        address microCreate2 = CREATEX.deployCreate2(_salt, MICRO_CREATE2_BYTECODE);
        console.log("MicroCreate2 deployed to: %s", microCreate2);
        require(microCreate2 == _expectedAddress, "MicroCreate2 addresses mismatch");
    }

    function deployNonceIncreaser(address _microCreate2, address _expectedAddress) public {
        if (_expectedAddress.code.length != 0) {
            console.log("NonceIncreaser already deployed");
            return;
        }

        (bool success, bytes memory ret) = _microCreate2.call(NONCE_INCREASER_BYTECODE);
        require(success && ret.length == 0x20, "NonceIncreaser deployment failed");

        address nonceIncreaser = abi.decode(ret, (address));
        console.log("NonceIncreaser deployed to: %s", nonceIncreaser);
        require(nonceIncreaser == _expectedAddress, "NonceIncreaser addresses mismatch");
    }

    function deployVanityMarket(address _microCreate2, address _expectedAddress) public {
        if (_expectedAddress.code.length != 0) {
            console.log("VanityMarket already deployed");
            return;
        }

        bytes memory bytecode = abi.encodePacked(VANITY_MARKET_BYTECODE, abi.encode(MARKET_OWNER));
        (bool success, bytes memory ret) = _microCreate2.call(abi.encodePacked(MARKET_SALT, bytecode));
        require(success && ret.length == 0x20, "VanityMarket deployment failed");

        address vanityMarket = abi.decode(ret, (address));
        console.log("VanityMarket deployed to: %s", vanityMarket);
        require(vanityMarket == _expectedAddress, "VanityMarket addresses mismatch");
    }

    function run() public virtual {
        vm.startBroadcast();

        require(address(CREATEX).code.length > 0, "No CreateX deployed to your chain");

        deployMicroCreate2({_salt: bytes32(0), _expectedAddress: MICRO_CREATE2_ADDRESS});

        deployNonceIncreaser({_microCreate2: MICRO_CREATE2_ADDRESS, _expectedAddress: NONCE_INCREASER_ADDRESS});

        deployVanityMarket({_microCreate2: MICRO_CREATE2_ADDRESS, _expectedAddress: VANITY_MARKET_ADDRESS});

        vm.stopBroadcast();
    }
}

/**
 * @notice Deploy contracts with a mock salt to the chain, to act as a probe before the main script is executed.
 * @author tinom.eth
 */
contract DeployProbeScript is DeployScript {
    bytes32 internal constant MICRO_CREATE2_PROBE_SALT = keccak256("safety first!");

    address internal constant MICRO_CREATE2_PROBE_ADDRESS = 0xb2EbA5Ac9d47E1F57639A115dBf7148Fab863A7E;
    address internal constant NONCE_INCREASER_PROBE_ADDRESS = 0x275211f908553595A0B5fA9dE5E6B1dbac52B5e2;
    address internal constant VANITY_MARKET_PROBE_ADDRESS = 0x3f3506b136D59CA6d0B75418559f7bA5B686f797;

    function run() public virtual override {
        vm.startBroadcast();

        require(address(CREATEX).code.length > 0, "No CreateX deployed to your chain");

        deployMicroCreate2({_salt: MICRO_CREATE2_PROBE_SALT, _expectedAddress: MICRO_CREATE2_PROBE_ADDRESS});

        deployNonceIncreaser({_microCreate2: MICRO_CREATE2_PROBE_ADDRESS, _expectedAddress: NONCE_INCREASER_PROBE_ADDRESS});

        deployVanityMarket({_microCreate2: MICRO_CREATE2_PROBE_ADDRESS, _expectedAddress: VANITY_MARKET_PROBE_ADDRESS});

        vm.stopBroadcast();
    }
}
