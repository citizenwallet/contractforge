// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./IUniswapV2Router02.sol";

contract OnRampSwapper is Ownable, ReentrancyGuard {
    address public quickswapRouter;
    address public ctznToken;
    address public treasuryAddress;

    event SwapExecuted(address indexed recipient, uint256 amountPOL, uint256 amountCTZN);
    event TreasuryAddressUpdated(address indexed newTreasury);

    constructor(address _quickswapRouter, address _ctznToken, address _treasuryAddress) Ownable(msg.sender) {
        require(_quickswapRouter != address(0), "Invalid router address");
        require(_ctznToken != address(0), "Invalid CTZN address");
        require(_treasuryAddress != address(0), "Invalid treasury address");

        quickswapRouter = _quickswapRouter;
        ctznToken = _ctznToken;
        treasuryAddress = _treasuryAddress;
    }

    // Function called by Transak after fiat payment is complete
    function onRampAndSwap(address recipient, uint256 amountOutMin) external payable nonReentrant {
        require(msg.value > 0, "No POL sent");
        require(recipient != address(0), "Invalid recipient address");

        uint256 amountPOL = msg.value;

        address[] memory path = new address[](2);
        path[0] = 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270; //Wrapped POL (WPOL)
        path[1] = ctznToken;

        IUniswapV2Router02(quickswapRouter).swapExactETHForTokensSupportingFeeOnTransferTokens{ value: amountPOL }(
            amountOutMin,
            path,
            recipient,
            block.timestamp + 10 minutes
        );

        // If any excess POL left in the contract (shouldn't normally happen), send to treasury
        uint256 excessPOL = address(this).balance;
        if (excessPOL > 0) {
            (bool success, ) = treasuryAddress.call{ value: excessPOL }("");
            require(success, "Sending excess POL failed");
        }

        emit SwapExecuted(recipient, amountPOL, IERC20(ctznToken).balanceOf(recipient));
    }

    // Owner can update treasury address
    function updateTreasuryAddress(address _newTreasury) external onlyOwner {
        require(_newTreasury != address(0), "Invalid treasury address");
        treasuryAddress = _newTreasury;
        emit TreasuryAddressUpdated(_newTreasury);
    }

    // Emergency: owner can withdraw stuck POL
    function emergencyWithdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No POL to withdraw");
        (bool success, ) = owner().call{ value: balance }("");
        require(success, "Withdraw failed");
    }

    receive() external payable {}
}
