// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "./utils/SafeSingleton.t.sol";
import "./Network.s.sol";

contract SafeSuiteSetupScript is Script, NetworkUtilsScript {
    // contract SafeSuiteSetupScript is Script, NetworkUtilsScript, SafeSingletonFixtureTest {
    function run() external {
        setUp();

        // 1. Network check and get private key
        checkNetwork();

        fundDeployer();

        // 2. start broadcasting
        vm.startBroadcast(deployerPrivateKey);

        // 3. deploy safe suites
        deployEntireSafeSuite();

        // broadcast transaction bundle
        vm.stopBroadcast();
    }
} 