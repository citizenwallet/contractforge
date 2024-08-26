# Card Manager Safe Module

## Overview

The Card Manager Safe Module is a powerful and flexible system for managing digital cards as Safe contracts. It provides functionality for creating instances, generating cards, managing whitelists, and controlling withdrawals.

## Key Features

1. **Instance Creation**: Create and manage separate instances within the Card Manager.

2. **Card Creation**: Generate new cards (implemented as Safe contracts) for instances using the hash of their serial numbers.

3. **Whitelist Management**: Maintain a whitelist of accounts for each instance, controlling access to card operations.

4. **Controlled Withdrawals**: Allow whitelisted accounts to withdraw from cards associated with their instance.

5. **Token Authorization**: Restrict withdrawals to only authorized tokens for each instance.

## Main Functions

- `createInstance(bytes32 id, address[] memory tokens)`: Create a new instance with a unique identifier.
- `getCardAddress(bytes32 id, bytes32 hashedSerial)`: Returns the address of a card for a given instance and hashed serial number without creating it.
- `createCard(bytes32 id, bytes32 hashedSerial)`: Generate a new card (Safe) for a given instance and hashed serial number.
- `updateWhitelist(bytes32 id, address[] memory addresses)`: Update the whitelist for a specific instance with the provided addresses.
- `updateInstanceTokens(bytes32 id, address[] memory tokens)`: Update the list of authorized tokens for withdrawals in a specific instance.
- `withdraw(bytes32 id, bytes32 hashedSerial, IERC20 token, address to, uint256 amount)`: Allow whitelisted accounts to withdraw authorized tokens from cards.

## Security Considerations

- Only instance owners can modify whitelists and authorize tokens.
- Withdrawals are restricted to whitelisted accounts and authorized tokens.
- Card creation uses secure hashing of serial numbers to ensure uniqueness.
- Serial numbers are never exposed, only their hashed values (bytes32) are used.
- Adding an existing card to an instance requires being authorized to do so.

## Usage

- Create an instance using any EOA or Smart Contract Account
- Add instance to POS app in order to get a vendor EOA and associated address
- Add vendor to instance whitelist
- Start scanning tags with the POS app
- View card details in web view

In theory, any hash serial can work as the seed for the card. So NFC tags are not a requirement. A bar code or qr code could work.

The advantage of NFC is that the serial number is only readable with proximity to the tag.


