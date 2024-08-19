// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Safe, OwnerManager, ModuleManager, Enum } from "safe-smart-account/contracts/Safe.sol";
import { CompatibilityFallbackHandler } from "safe-smart-account/contracts/handler/CompatibilityFallbackHandler.sol";

error CountIsZero(address safeAddr);
error ModuleNotEnabled(address safeAddr);

contract CounterModule is CompatibilityFallbackHandler {
    string public constant NAME = "Counter Module";
    string public constant VERSION = "0.0.1";

    ////////////////

    // keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    bytes32 private constant DOMAIN_SEPARATOR_TYPEHASH = 0x8b73c3c69bb8fe3d512ecc4cf759cc79239f7b179b0ffacaa9a75d522b39400f;

    /// @dev Returns the chain id used by this contract.
    function getChainId() public view returns (uint256) {
        uint256 id;
        // solhint-disable-next-line no-inline-assembly
        assembly {
            id := chainid()
        }
        return id;
    }

    function domainSeparator() public view returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    DOMAIN_SEPARATOR_TYPEHASH,
                    keccak256(abi.encodePacked(NAME)),
                    keccak256(abi.encodePacked(VERSION)),
                    getChainId(),
                    this
                )
            );
    }

    mapping(address => uint256) public count;

    /**
     * @dev Throws if the caller is not an enabled module.
     */
    modifier onlyWhenModuleIsEnabled(address safeAddr) {
        bool isEnabled = ModuleManager(payable(safeAddr)).isModuleEnabled(address(this));
        if (!isEnabled) revert ModuleNotEnabled(safeAddr);
        _;
    }

    /**
     * @dev This is a helper function to call the increment function from the CounterModule for test purposes
     * @param safeAddr The address of the Safe contract
     * @return bool Whether the transaction was successful
     */
    function callIncrement(address safeAddr) external onlyWhenModuleIsEnabled(safeAddr) returns (bool) {
        // Prepare the transaction data for the increment function
		bytes memory data = abi.encodeWithSignature("increment(address)", safeAddr);
		
		return Safe(payable(safeAddr)).execTransactionFromModule(
			address(this),
			0,
			data,
			Enum.Operation.Call
		);
    }

    function increment(address safeAddr) external onlyWhenModuleIsEnabled(safeAddr) {
        count[safeAddr] += 1;
    }

    /**
     * @dev This is a helper function to call the decrement function from the CounterModule for test purposes
     * @param safeAddr The address of the Safe contract
     * @return bool Whether the transaction was successful
     */
    function callDecrement(address safeAddr) external onlyWhenModuleIsEnabled(safeAddr) returns (bool) {
        // Prepare the transaction data for the decrement function
		bytes memory data = abi.encodeWithSignature("decrement(address)", safeAddr);
		
		return Safe(payable(safeAddr)).execTransactionFromModule(
			address(this),
			0,
			data,
			Enum.Operation.Call
		);
    }

    function decrement(address safeAddr) external onlyWhenModuleIsEnabled(safeAddr) {
        if (count[safeAddr] == 0) revert CountIsZero(safeAddr);
        count[safeAddr] -= 1;
    }

    function setCount(uint256 _count, address safeAddr) external onlyWhenModuleIsEnabled(safeAddr) {
        count[safeAddr] = _count;
    }

    function getCount(address safeAddr) external view returns (uint256) {
        return count[safeAddr];
    }
}