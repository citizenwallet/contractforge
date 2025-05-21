// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title QuickSwap Router Interface
/// @notice Interface for interacting with QuickSwap's router contract
interface ISwapRouter {
	/// @notice Parameters for exact input single token swap
	struct ExactInputSingleParams {
		address tokenIn;           // Address of input token
		address tokenOut;          // Address of output token
		address recipient;         // Address to receive output tokens
		uint256 deadline;          // Unix timestamp deadline for the swap
		uint256 amountIn;          // Amount of input tokens to send
		uint256 amountOutMinimum;  // Minimum amount of output tokens to receive
		uint160 sqrtPriceLimitX96; // Price limit for the swap (0 for no limit)
	}

	/// @notice Executes a swap with exact input amount
	/// @param params The parameters for the swap
	/// @return amountOut The amount of output tokens received
	function exactInputSingle(ExactInputSingleParams calldata params) external payable returns (uint256 amountOut);
}

/// @title Wrapped POL Interface
/// @notice Interface for interacting with the Wrapped POL token contract
interface IWPOL {
	/// @notice Wraps POL by depositing it into the contract
	function deposit() external payable;
	
	/// @notice Approves the spender to spend tokens
	/// @param spender Address to approve
	/// @param amount Amount to approve
	/// @return success Whether the approval was successful
	function approve(address spender, uint256 amount) external returns (bool);
}

/// @title OnRampSwapper
/// @notice Contract for swapping POL to CTZN tokens through QuickSwap
/// @dev Implements reentrancy protection and safe approval patterns
contract OnRampSwapper is Ownable, ReentrancyGuard {
	// Custom errors for better gas efficiency and error handling
	error InvalidRouterAddress();
	error InvalidCTZNAddress();
	error InvalidWPOLAddress();
	error InvalidTreasuryAddress();
	error NoPOLSent();
	error InvalidRecipientAddress();
	error ApproveFailed();
	error SendingExcessPOLFailed();
	error NoPOLToWithdraw();
	error WithdrawFailed();
	error InsufficientOutputAmount(uint256 actualAmount, uint256 minimumAmount);

	// Immutable state variables
	address public immutable QUICKSWAP_ROUTER;  // QuickSwap router address
	address public immutable CTZN_TOKEN;        // CTZN token address
	address public immutable WPOL;              // Wrapped POL token address
	address public treasuryAddress;             // Treasury address for excess POL

	// Events for tracking important state changes
	event SwapExecuted(address indexed recipient, uint256 amountPOL, uint256 amountCTZN);
	event TreasuryAddressUpdated(address indexed newTreasury);
	event TreasuryChanged(address indexed oldTreasury, address indexed newTreasury);

	/// @notice Constructor initializes the contract with required addresses
	/// @param _swapRouter Address of the QuickSwap router
	/// @param _ctznToken Address of the CTZN token
	/// @param _wpol Address of the Wrapped POL token
	/// @param _treasuryAddress Address of the treasury
	constructor(address _swapRouter, address _ctznToken, address _wpol, address _treasuryAddress) Ownable(msg.sender) {
		if (_swapRouter == address(0)) revert InvalidRouterAddress();
		if (_ctznToken == address(0)) revert InvalidCTZNAddress();
		if (_wpol == address(0)) revert InvalidWPOLAddress();
		if (_treasuryAddress == address(0)) revert InvalidTreasuryAddress();

		QUICKSWAP_ROUTER = _swapRouter;
		CTZN_TOKEN = _ctznToken;
		WPOL = _wpol;
		treasuryAddress = _treasuryAddress;
	}

	/// @notice Swaps POL to CTZN tokens
	/// @dev Implements reentrancy protection and safe approval pattern
	/// @param recipient Address to receive the CTZN tokens
	/// @param amountOutMin Minimum amount of CTZN tokens to receive
	function onRampAndSwap(address recipient, uint256 amountOutMin) external payable nonReentrant {
		if (msg.value == 0) revert NoPOLSent();
		if (recipient == address(0)) revert InvalidRecipientAddress();

		uint256 amountPOL = msg.value;

		// 1. Wrap POL to WPOL
		IWPOL(WPOL).deposit{ value: amountPOL }();
		
		// 2. Approve router to spend WPOL
		if (!IWPOL(WPOL).approve(QUICKSWAP_ROUTER, amountPOL)) revert ApproveFailed();

		// 3. Prepare swap parameters
		ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
			tokenIn: WPOL,
			tokenOut: CTZN_TOKEN,
			recipient: recipient,
			deadline: block.timestamp + 600, // 10-minute deadline
			amountIn: amountPOL,
			amountOutMinimum: amountOutMin,
			sqrtPriceLimitX96: 0
		});

		// 4. Reset approval to 0 for security
		if (!IWPOL(WPOL).approve(QUICKSWAP_ROUTER, 0)) revert ApproveFailed();

		// 5. Execute swap
		uint256 amountOut = ISwapRouter(QUICKSWAP_ROUTER).exactInputSingle(params);
		
		// 6. Verify slippage
		if (amountOut < amountOutMin) revert InsufficientOutputAmount(amountOut, amountOutMin);
		
		emit SwapExecuted(recipient, amountPOL, amountOut);

		// 7. Send any excess POL to treasury
		uint256 excess = address(this).balance;
		if (excess > 0) {
			(bool success, ) = treasuryAddress.call{ value: excess }("");
			if (!success) revert SendingExcessPOLFailed();
		}
	}

	/// @notice Updates the treasury address
	/// @dev Only callable by owner
	/// @param _newTreasury New treasury address
	function updateTreasuryAddress(address _newTreasury) external onlyOwner {
		if (_newTreasury == address(0)) revert InvalidTreasuryAddress();
		address oldTreasury = treasuryAddress;
		treasuryAddress = _newTreasury;
		emit TreasuryAddressUpdated(_newTreasury);
		emit TreasuryChanged(oldTreasury, _newTreasury);
	}

	/// @notice Emergency function to withdraw stuck POL
	/// @dev Only callable by owner
	function emergencyWithdraw() external onlyOwner {
		uint256 balance = address(this).balance;
		if (balance == 0) revert NoPOLToWithdraw();
		(bool success, ) = owner().call{ value: balance }("");
		if (!success) revert WithdrawFailed();
	}

	/// @notice Receive function to accept POL
	/// @dev Implements reentrancy protection
	receive() external payable nonReentrant {}
}
