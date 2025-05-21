// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

interface ISwapRouter {
	struct ExactInputSingleParams {
		address tokenIn;
		address tokenOut;
		address recipient;
		uint256 deadline;
		uint256 amountIn;
		uint256 amountOutMinimum;
		uint160 sqrtPriceLimitX96;
	}

	function exactInputSingle(ExactInputSingleParams calldata params) external payable returns (uint256 amountOut);
}

interface IWPOL {
	function deposit() external payable;
	function approve(address spender, uint256 amount) external returns (bool);
}

contract OnRampSwapper is Ownable, ReentrancyGuard {
	// Custom errors
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

	address public immutable QUICKSWAP_ROUTER;
	address public immutable CTZN_TOKEN;
	address public immutable WPOL;
	address public treasuryAddress;

	event SwapExecuted(address indexed recipient, uint256 amountPOL, uint256 amountCTZN);
	event TreasuryAddressUpdated(address indexed newTreasury);
	event TreasuryChanged(address indexed oldTreasury, address indexed newTreasury);

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

	function onRampAndSwap(address recipient, uint256 amountOutMin) external payable nonReentrant {
		if (msg.value == 0) revert NoPOLSent();
		if (recipient == address(0)) revert InvalidRecipientAddress();

		uint256 amountPOL = msg.value;

		IWPOL(WPOL).deposit{ value: amountPOL }();
		if (!IWPOL(WPOL).approve(QUICKSWAP_ROUTER, amountPOL)) revert ApproveFailed();

		ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
			tokenIn: WPOL,
			tokenOut: CTZN_TOKEN,
			recipient: recipient,
			deadline: block.timestamp + 600,
			amountIn: amountPOL,
			amountOutMinimum: amountOutMin,
			sqrtPriceLimitX96: 0
		});

		uint256 amountOut = ISwapRouter(QUICKSWAP_ROUTER).exactInputSingle(params);
		
		// Add slippage protection check
		if (amountOut < amountOutMin) revert InsufficientOutputAmount(amountOut, amountOutMin);
		
		// Reset approval to 0 after swap
		if (!IWPOL(WPOL).approve(QUICKSWAP_ROUTER, 0)) revert ApproveFailed();
		
		emit SwapExecuted(recipient, amountPOL, amountOut);

		// Calculate excess after the swap is completed
		uint256 excess = address(this).balance;
		if (excess > 0) {
			(bool success, ) = treasuryAddress.call{ value: excess }("");
			if (!success) revert SendingExcessPOLFailed();
		}
	}

	function updateTreasuryAddress(address _newTreasury) external onlyOwner {
		if (_newTreasury == address(0)) revert InvalidTreasuryAddress();
		address oldTreasury = treasuryAddress;
		treasuryAddress = _newTreasury;
		emit TreasuryAddressUpdated(_newTreasury);
		emit TreasuryChanged(oldTreasury, _newTreasury);
	}

	function emergencyWithdraw() external onlyOwner {
		uint256 balance = address(this).balance;
		if (balance == 0) revert NoPOLToWithdraw();
		(bool success, ) = owner().call{ value: balance }("");
		if (!success) revert WithdrawFailed();
	}

	receive() external payable nonReentrant {}
}
