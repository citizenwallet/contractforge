// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * library for Safe 1.4.1 addresses
 * deployed contract addresses on Gnosis Chain from
 * https://github.com/safe-global/safe-deployments/tree/51efc59d05ddf725478d6472fc67989dfb031b4d/src/assets/v1.4.1
 */
library SafeSuiteLib {
    address internal constant SAFE_SimulateTxAccessor_ADDRESS = 0x3d4BA2E0884aa488718476ca2FB8Efc291A46199;
    address internal constant SAFE_SafeProxyFactory_ADDRESS = 0x4e1DCf7AD4e460CfD30791CCC4F9c8a4f820ec67;
    address internal constant SAFE_TokenCallbackHandler_ADDRESS = 0xeDCF620325E82e3B9836eaaeFdc4283E99Dd7562;
    address internal constant SAFE_CompatibilityFallbackHandler_ADDRESS = 0xfd0732Dc9E303f09fCEf3a7388Ad10A83459Ec99;
    address internal constant SAFE_CreateCall_ADDRESS = 0x9b35Af71d77eaf8d7e40252370304687390A1A52;
    address internal constant SAFE_MultiSend_ADDRESS = 0x38869bf66a61cF6bDB996A6aE40D5853Fd43B526;
    address internal constant SAFE_MultiSendCallOnly_ADDRESS = 0x9641d764fc13c8B624c04430C7356C1C7C8102e2;
    address internal constant SAFE_SignMessageLib_ADDRESS = 0xd53cd0aB83D845Ac265BE939c57F53AD838012c9;
    address internal constant SAFE_Safe_ADDRESS = 0x41675C099F32341bf84BFc5382aF534df5C7461a;
    address internal constant SAFE_SINGLETON_ADDRESS = 0x914d7Fec6aaC8cd542e72Bca78B30650d45643d7;
    string internal constant SAFE_VERSION = "1.4.1";
}