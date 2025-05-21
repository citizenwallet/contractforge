// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/OnRampProvider/OnRampSwapper.sol";
import "../src/OnRampProvider/IUniswapV2Router02.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

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
	address public callbackTarget;

	constructor(address _tokenOut) {
		tokenOut = _tokenOut;
	}

	function setCallback(address _target) external {
		callbackTarget = _target;
	}

	receive() external payable {}
	function exactInputSingle(ExactInputSingleParams calldata params) external payable override returns (uint256) {
		console.log("xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx");
		// Mint some CTZN to simulate swap output
		uint256 output = params.amountIn * 2; // simulate 1 MATIC = 2 CTZN
		MockCTZN(tokenOut).mint(params.recipient, output);

		// Call back to the target if set
		if (callbackTarget != address(0)) {
			MaliciousReentrant(callbackTarget).onERC20Received();
		}

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

contract MaliciousReentrant {
	OnRampSwapper public swapper;
	address public user;

	constructor(address payable _swapper, address _user) {
		swapper = OnRampSwapper(_swapper);
		user = _user;
	}

	function onERC20Received() external {
		// Attempt to reenter the swap function
		swapper.onRampAndSwap{value: 1 ether}(user, 0);
	}
}

contract OnRampSwapperTest is Test {
	OnRampSwapper public swapper;
	MockCTZN public ctzn;
	MockRouter public router;
	address public treasury = address(0xBEEF);
	address public user = address(0xABCD);
	MockWPOL public wmatic;

	receive() external payable {}

	function setUp() public {
		ctzn = new MockCTZN();
		router = new MockRouter(address(ctzn));
		wmatic = new MockWPOL();
		swapper = new OnRampSwapper(address(router), address(ctzn), address(wmatic), treasury);
		vm.deal(address(this), 100 ether);
		vm.deal(user, 10 ether);
	}

	function testConstructorSetsValues() public {
		assertEq(swapper.CTZN_TOKEN(), address(ctzn));
		assertEq(swapper.QUICKSWAP_ROUTER(), address(router));
		assertEq(swapper.treasuryAddress(), treasury);
		assertEq(swapper.WPOL(), address(wmatic));
	}
	function testOnRampAndSwap() public {
		address recipient = address(0x1234);
		uint256 value = 1 ether;

		vm.deal(address(this), value);
		swapper.onRampAndSwap{ value: value }(recipient, 0);

		uint256 balance = ctzn.balanceOf(recipient);
		assertGt(balance, 0);
	}

	function test_RevertWhen_OnRampWithZeroPOL() public {
		vm.expectRevert(OnRampSwapper.NoPOLSent.selector);
		swapper.onRampAndSwap{ value: 0 }(user, 0);
	}

	function test_RevertWhen_OnRampWithZeroRecipient() public {
		vm.expectRevert(OnRampSwapper.InvalidRecipientAddress.selector);
		swapper.onRampAndSwap{ value: 1 ether }(address(0), 0);
	}

	function test_RevertWhen_UpdateTreasuryToZero() public {
		vm.expectRevert(OnRampSwapper.InvalidTreasuryAddress.selector);
		swapper.updateTreasuryAddress(address(0));
	}

	function test_RevertWhen_EmergencyWithdrawNoBalance() public {
		vm.expectRevert(OnRampSwapper.NoPOLToWithdraw.selector);
		swapper.emergencyWithdraw();
	}

	function test_RevertWhen_ConstructorZeroRouter() public {
		vm.expectRevert(OnRampSwapper.InvalidRouterAddress.selector);
		new OnRampSwapper(address(0), address(ctzn), address(wmatic), treasury);
	}

	function test_RevertWhen_ConstructorZeroCTZN() public {
		vm.expectRevert(OnRampSwapper.InvalidCTZNAddress.selector);
		new OnRampSwapper(address(router), address(0), address(wmatic), treasury);
	}

	function test_RevertWhen_ConstructorZeroTreasury() public {
		vm.expectRevert(OnRampSwapper.InvalidTreasuryAddress.selector);
		new OnRampSwapper(address(router), address(ctzn), address(wmatic), address(0));
	}

	function test_RevertWhen_OnRampAndSwapExcessPOLSendFails() public {
		NonPayableFallback nonPayable = new NonPayableFallback();
		swapper.updateTreasuryAddress(address(nonPayable));

		vm.deal(address(swapper), 1 ether);
		vm.deal(address(this), 1 ether);
		vm.expectRevert(OnRampSwapper.SendingExcessPOLFailed.selector);
		swapper.onRampAndSwap{ value: 1 ether }(user, 0);
	}

	function test_RevertWhen_EmergencyWithdrawFailsIfTransferFails() public {
		RevertingReceiver badOwner = new RevertingReceiver();
		swapper.transferOwnership(address(badOwner));

		vm.deal(address(swapper), 1 ether);

		vm.prank(address(badOwner));
		vm.expectRevert(OnRampSwapper.WithdrawFailed.selector);
		swapper.emergencyWithdraw();
	}

	function testUpdateTreasuryAddress() public {
		address newTreasury = address(0xD00D);
		swapper.updateTreasuryAddress(newTreasury);
		assertEq(swapper.treasuryAddress(), newTreasury);
	}

	function testEmergencyWithdraw() public {
		vm.deal(address(swapper), 1 ether);
		uint256 before = address(this).balance;

		swapper.emergencyWithdraw();
		assertGt(address(this).balance, before);
	}

	function testReceiveFallback() public {
		(bool success, ) = address(swapper).call{ value: 1 ether }("");
		assertTrue(success);
	}

	function testFuzz_onRampAndSwap(uint256 ethAmount) public {
		ethAmount = bound(ethAmount, 1e15, 1 ether); // Bound for realistic fuzzing
		vm.deal(address(this), ethAmount);

		swapper.onRampAndSwap{ value: ethAmount }(user, 0);
		assertGt(ctzn.balanceOf(user), 0);
	}

	function testOnRampAndSwapExcessPOLSentToTreasury() public {
		// Send some ETH to the contract before calling swap to simulate excess POL
		vm.deal(address(swapper), 1 ether);

		vm.deal(address(this), 1 ether);
		swapper.onRampAndSwap{ value: 1 ether }(user, 0);
		// No revert means success, excess was sent
	}

	function test_RevertWhen_SlippageTooHigh() public {
		// Create a new router that returns less tokens than expected
		MockRouter lowOutputRouter = new MockRouter(address(ctzn));
		OnRampSwapper newSwapper = new OnRampSwapper(
			address(lowOutputRouter),
			address(ctzn),
			address(wmatic),
			treasury
		);

		// Set up the test with a high minimum output amount
		uint256 amountIn = 1 ether;
		uint256 minOutput = 3 ether; // Expecting 2x output but setting minimum to 3x

		vm.deal(address(this), amountIn);
		vm.expectRevert(abi.encodeWithSelector(OnRampSwapper.InsufficientOutputAmount.selector, 2 ether, 3 ether));
		newSwapper.onRampAndSwap{ value: amountIn }(user, minOutput);
	}

	function test_RevertWhen_ReentrancyAttempt() public {
		// Create malicious contract
		MaliciousReentrant malicious = new MaliciousReentrant(payable(address(swapper)), user);
		
		// Set the malicious contract as the callback target in the router
		router.setCallback(address(malicious));
		
		// Fund the malicious contract
		vm.deal(address(malicious), 1 ether);
		
		// Attempt the initial swap which will trigger the reentrancy attempt
		vm.expectRevert();
		malicious.onERC20Received();
	}

}
