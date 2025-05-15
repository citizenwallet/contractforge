// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ISwapRouter {
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    function exactInputSingle(ExactInputSingleParams calldata params) external payable returns (uint256 amountOut);
}

interface IWMATIC {
    function deposit() external payable;
    function approve(address spender, uint256 amount) external returns (bool);
}

contract OnRampSwapper is Ownable, ReentrancyGuard {
    address public immutable quickswapRouter;
    address public immutable ctznToken;
    address public immutable wmatic;
    address public treasuryAddress;

    event SwapExecuted(address indexed recipient, uint256 amountPOL, uint256 amountCTZN);
    event TreasuryAddressUpdated(address indexed newTreasury);

    constructor(
        address _swapRouter,
        address _ctznToken,
        address _wmatic,
        address _treasuryAddress
    ) Ownable(msg.sender) {
        require(_swapRouter != address(0), "Invalid router address");
        require(_ctznToken != address(0), "Invalid CTZN address");
        require(_wmatic != address(0), "Invalid WMATIC address");
        require(_treasuryAddress != address(0), "Invalid treasury address");

        quickswapRouter = _swapRouter;
        ctznToken = _ctznToken;
        wmatic = _wmatic;
        treasuryAddress = _treasuryAddress;
    }

    function onRampAndSwap(address recipient, uint256 amountOutMin) external payable nonReentrant {
        require(msg.value > 0, "No MATIC sent");
        require(recipient != address(0), "Invalid recipient address");

        uint256 amountPOL = msg.value;

        IWMATIC(wmatic).deposit{value: amountPOL}();
        require(IWMATIC(wmatic).approve(quickswapRouter, amountPOL), "Approve failed");

        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
            tokenIn: wmatic,
            tokenOut: ctznToken,
            fee: 3000,
            recipient: recipient,
            deadline: block.timestamp + 600,
            amountIn: amountPOL,
            amountOutMinimum: amountOutMin,
            sqrtPriceLimitX96: 0
        });

        uint256 amountOut = ISwapRouter(quickswapRouter).exactInputSingle(params);
        emit SwapExecuted(recipient, amountPOL, amountOut);

        uint256 excess = address(this).balance;
        if (excess > 0) {
            (bool success, ) = treasuryAddress.call{value: excess}("");
            require(success, "Sending excess MATIC failed");
        }
    }

    function updateTreasuryAddress(address _newTreasury) external onlyOwner {
        require(_newTreasury != address(0), "Invalid treasury address");
        treasuryAddress = _newTreasury;
        emit TreasuryAddressUpdated(_newTreasury);
    }

    function emergencyWithdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No MATIC to withdraw");
        (bool success, ) = owner().call{value: balance}("");
        require(success, "Withdraw failed");
    }

    receive() external payable {}
}