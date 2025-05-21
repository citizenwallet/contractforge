# OnRampSwapper Smart Contract

## Overview
The OnRampSwapper is a secure smart contract designed to facilitate the swapping of POL (Polygon) tokens to CTZN tokens through the QuickSwap DEX. It acts as an on-ramp service that handles the wrapping of POL to WPOL and subsequent token swaps.

## Core Functionality
1. **Token Swapping**: Converts POL to CTZN tokens through QuickSwap
2. **POL Wrapping**: Automatically wraps POL to WPOL before swapping
3. **Treasury Management**: Handles excess POL by sending it to a treasury address
4. **Emergency Controls**: Includes emergency withdrawal functionality for contract owners

## Security Features

### 1. Access Control
- **Ownable Pattern**: Implements OpenZeppelin's `Ownable` contract for administrative functions
- **Restricted Functions**:
  - `updateTreasuryAddress`: Only callable by owner
  - `emergencyWithdraw`: Only callable by owner

### 2. Reentrancy Protection
- **ReentrancyGuard**: Implements OpenZeppelin's `ReentrancyGuard` to prevent reentrancy attacks
- Applied to critical functions:
  - `onRampAndSwap`
  - `receive` function

### 3. Input Validation
- **Zero Address Checks**:
  - Router address
  - CTZN token address
  - WPOL address
  - Treasury address
  - Recipient address
- **Value Checks**:
  - Ensures non-zero POL amount for swaps
  - Validates minimum output amounts

### 4. Slippage Protection
- Implements minimum output amount parameter (`amountOutMin`)
- Verifies actual output against minimum expected output
- Custom error `InsufficientOutputAmount` for failed slippage checks

### 5. Safe Token Approvals
- Implements approval reset pattern:
  1. Approves router for exact amount needed
  2. Resets approval to zero after swap
  3. Prevents potential approval-based attacks

### 6. Error Handling
- Custom errors for all failure cases
- Comprehensive error messages for debugging

### 7. Event Emission
- Critical state changes are logged:
  - `SwapExecuted`: Records swap details
  - `TreasuryAddressUpdated`: Logs treasury changes
  - `TreasuryChanged`: Records old and new treasury addresses

### 8. Emergency Features
- **Emergency Withdrawal**:
  - Allows owner to withdraw stuck POL
  - Includes balance checks
  - Implements transfer failure handling

## Usage

### Constructor Parameters
```solidity
constructor(
    address _swapRouter,    // QuickSwap router address
    address _ctznToken,     // CTZN token address
    address _wpol,          // Wrapped POL token address
    address _treasuryAddress // Treasury address for excess POL
)
```

### Main Functions
1. `onRampAndSwap(address recipient, uint256 amountOutMin)`
   - Swaps POL to CTZN tokens
   - Requires non-zero POL value
   - Validates minimum output amount

2. `updateTreasuryAddress(address _newTreasury)`
   - Updates treasury address
   - Only callable by owner
   - Emits events for tracking

3. `emergencyWithdraw()`
   - Emergency POL withdrawal
   - Only callable by owner
   - Includes safety checks

## Security Considerations

### Strengths
1. Comprehensive input validation
2. Reentrancy protection
3. Safe approval pattern
4. Slippage protection
5. Emergency controls
6. Extensive testing

### Potential Areas for Review
1. Deadline parameter (fixed 600-second deadline)
2. Treasury address updates (consider timelock)
3. WPOL approval implementation
4. Gas optimization opportunities

## Testing
The contract includes comprehensive test coverage in `test/OnRampSwapper.t.sol`:
- Constructor parameter validation
- Swap functionality
- Error cases
- Reentrancy protection
- Slippage protection
- Treasury management
- Emergency functions
- Fuzzing tests

## License
MIT License 