// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "./utils/SafeSingleton.t.sol";

contract NetworkUtilsScript is Test, SafeSingletonFixtureTest {
    uint256 internal deployerPrivateKey;

    function fundDeployer() public {
        console.log("Funding deployer");
        if (deployerPrivateKey == 0) {
            deployerPrivateKey = isAnvil()
            ? 77_814_517_325_470_205_911_140_941_194_401_928_579_557_062_014_761_831_930_645_393_041_380_819_009_408
            : vm.envUint("PRIVATE_KEY");
        }

        if (isAnvil()) {
            vm.deal(vm.addr(deployerPrivateKey), 100 ether);
        }
    }

    function checkNetwork() public {
        // 1. Network check
        emit log_string(string(abi.encodePacked("Deploying to rpc ", getChain(block.chainid).rpcUrl)));

        // Halt if Safe Singleton has not been deployed.
        mustHaveSingletonContract();

        // 2. Get deployer private key
        // Set to default when it's in development environment (uint for
        // 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80)
        deployerPrivateKey = isAnvil()
            ? 77_814_517_325_470_205_911_140_941_194_401_928_579_557_062_014_761_831_930_645_393_041_380_819_009_408
            : vm.envUint("PRIVATE_KEY");
    }

    function isAnvil() private view returns (bool) {
        return block.chainid == 31_337;
    }
}