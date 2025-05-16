// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/OnRampProvider/OnRampSwapper.sol";
import "../src/OnRampProvider/IUniswapV2Router02.sol";

contract MockCTZN is IERC20 {
    string public constant name = "CTZN";
    string public constant symbol = "CTZN";
    uint8 public constant decimals = 18;
    uint256 public override totalSupply;

    mapping(address => uint256) public override balanceOf;
    mapping(address => mapping(address => uint256)) public override allowance;

    function transfer(address recipient, uint256 amount) external override returns (bool) {
        balanceOf[msg.sender] -= amount;
        balanceOf[recipient] += amount;
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) external override returns (bool) {
        allowance[sender][msg.sender] -= amount;
        balanceOf[sender] -= amount;
        balanceOf[recipient] += amount;
        return true;
    }

    function approve(address spender, uint256 amount) external override returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
        totalSupply += amount;
    }
}

contract MockRouter is ISwapRouter {
    address public tokenOut;

    constructor(address _tokenOut) {
        tokenOut = _tokenOut;
    }
    receive() external payable {}
    function exactInputSingle(ExactInputSingleParams calldata params) external payable override returns (uint256) {
        console.log("xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx");
        // Mint some CTZN to simulate swap output
        uint256 output = params.amountIn * 2; // simulate 1 MATIC = 2 CTZN
        MockCTZN(tokenOut).mint(params.recipient, output);
        return output;
    }
}


contract NonPayableFallback {
    fallback() external {}
}

contract RevertingReceiver {
    fallback() external payable {
        revert("I don't accept ETH");
    }
}

contract MockWPOL is IWPOL {
    receive() external payable {}

    function deposit() external payable override {}

    function approve(address, uint256) external pure override returns (bool) {
        return true;
    }
}

contract OnRampSwapperTest is Test {
    OnRampSwapper public swapper;
    MockCTZN public ctzn;
    MockRouter public router;
    address public treasury = address(0xBEEF);
    address public user = address(0xABCD);
    MockWPOL public wpol;

    receive() external payable {}

    function setUp() public {
        ctzn = new MockCTZN();
        router = new MockRouter(address(ctzn));
        wpol = new MockWPOL();
        swapper = new OnRampSwapper(address(router), address(ctzn), address(wpol), treasury);
        vm.deal(address(this), 100 ether);
        vm.deal(user, 10 ether);
    }

    function testConstructorSetsValues() public {
        assertEq(swapper.ctznToken(), address(ctzn));
        assertEq(swapper.quickswapRouter(), address(router));
        assertEq(swapper.treasuryAddress(), treasury);
        assertEq(swapper.wpol(), address(wpol));
    }
    function testOnRampAndSwap() public {
        address recipient = address(0x1234);
        uint256 value = 1 ether;

        vm.deal(address(this), value);
        swapper.onRampAndSwap{value: value}(recipient, 0);

        uint256 balance = ctzn.balanceOf(recipient);
        assertGt(balance, 0);
    }

    function testFailOnRampWithZeroPOL() public {
        swapper.onRampAndSwap{value: 0}(user, 0);
    }

    function testFailOnRampWithZeroRecipient() public {
        swapper.onRampAndSwap{value: 1 ether}(address(0), 0);
    }

    function testUpdateTreasuryAddress() public {
        address newTreasury = address(0xD00D);
        swapper.updateTreasuryAddress(newTreasury);
        assertEq(swapper.treasuryAddress(), newTreasury);
    }

    function testFailUpdateTreasuryToZero() public {
        swapper.updateTreasuryAddress(address(0));
    }

    function testEmergencyWithdraw() public {
        vm.deal(address(swapper), 1 ether);
        uint256 before = address(this).balance;

        swapper.emergencyWithdraw();
        assertGt(address(this).balance, before);
    }

    function testFailEmergencyWithdrawNoBalance() public {
        swapper.emergencyWithdraw();
    }
    
    function testFailConstructorZeroRouter() public {
    new OnRampSwapper(address(0), address(ctzn), address(wpol), treasury);
    }

    function testFailConstructorZeroCTZN() public {
        new OnRampSwapper(address(router), address(0), address(wpol), treasury);
    }

    function testFailConstructorZeroTreasury() public {
        new OnRampSwapper(address(router), address(ctzn), address(wpol), address(0));
    }


    function testReceiveFallback() public {
        (bool success, ) = address(swapper).call{value: 1 ether}("");
        assertTrue(success);
    }

    function testFuzz_onRampAndSwap(uint256 ethAmount) public {
        ethAmount = bound(ethAmount, 1e15, 1 ether); // Bound for realistic fuzzing
        vm.deal(address(this), ethAmount);

        swapper.onRampAndSwap{value: ethAmount}(user, 0);
        assertGt(ctzn.balanceOf(user), 0);
    }

    function testOnRampAndSwapExcessPOLSentToTreasury() public {
        // Send some ETH to the contract before calling swap to simulate excess POL
        vm.deal(address(swapper), 1 ether);

        vm.deal(address(this), 1 ether);
        swapper.onRampAndSwap{value: 1 ether}(user, 0);
        // No revert means success, excess was sent
    }

    function testFailOnRampAndSwapExcessPOLSendFails() public {
        NonPayableFallback nonPayable = new NonPayableFallback();
        swapper.updateTreasuryAddress(address(nonPayable));

        vm.deal(address(swapper), 1 ether);
        vm.deal(address(this), 1 ether);
        swapper.onRampAndSwap{value: 1 ether}(user, 0);
    }

    function testFailEmergencyWithdrawFailsIfTransferFails() public {
        RevertingReceiver badOwner = new RevertingReceiver();
        swapper.transferOwnership(address(badOwner));

        vm.deal(address(swapper), 1 ether);

        vm.prank(address(badOwner));
        swapper.emergencyWithdraw();
    }
}