// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/interfaces/IERC1271.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import { CompatibilityFallbackHandler } from "safe-smart-account/contracts/handler/CompatibilityFallbackHandler.sol";
import { Enum, ModuleManager, OwnerManager } from "safe-smart-account/contracts/Safe.sol";
import { BaseGuard, Guard } from "safe-smart-account/contracts/base/GuardManager.sol";
import { IERC165 } from "safe-smart-account/contracts/interfaces/IERC165.sol";
import { TokenCallbackHandler } from "safe-smart-account/contracts/handler/TokenCallbackHandler.sol";

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

import { TwoFAFactory } from "./TwoFAFactory.sol";
import { SessionRequest, ActiveSession } from "./SessionRequest.sol";

import { toEthSignedMessageHash } from "../../utils/Helpers.sol";

error SessionRequestExpired();
error SessionOwnerIsProvider();
error InvalidProvider();
error SessionRequestNotFound();
error InvalidOwnerSignedSessionHash();
error AccountNotCreated();
error FailedToAddSigner();
error FailedToRemoveSigner();
error SignerNotOwner();
error SignerAlreadyExists();
contract SessionManagerModule is
	CompatibilityFallbackHandler,
	BaseGuard,
	Initializable,
	ReentrancyGuardUpgradeable,
	OwnableUpgradeable,
	UUPSUpgradeable
{
	string public constant NAME = "Session Module";
	string public constant VERSION = "0.0.2";

	////////////////

	// keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
	bytes32 private constant DOMAIN_SEPARATOR_TYPEHASH =
		0x8b73c3c69bb8fe3d512ecc4cf759cc79239f7b179b0ffacaa9a75d522b39400f;

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
					// address(communityModule),
					this
				)
			);
	}

	/////////////////////////////////////////////////
	// VARIABLES
	address public twoFAFactory;
	mapping(address => mapping(bytes32 => SessionRequest)) public sessionRequests;
	ActiveSession[] public activeSessions;

	/////////////////////////////////////////////////
	// EVENTS
	event Requested(address indexed provider, bytes32 sessionRequestHash);
	event Confirmed(address indexed provider, address indexed account, address sessionOwner);

	/////////////////////////////////////////////////
	// INITIALIZATION

	function initialize(address _owner, address _twoFAFactory) external initializer {
		__Ownable_init(_owner);
		__UUPSUpgradeable_init();
		__ReentrancyGuard_init();

		twoFAFactory = _twoFAFactory;
	}

	/////////////////////////////////////////////////

	/////////////////////////////////////////////////
	// UPGRADE AUTHORIZATION

	function _authorizeUpgrade(address newImplementation) internal view override onlyOwner {
		(newImplementation);
	}

	/////////////////////////////////////////////////

	/////////////////////////////////////////////////
	// SESSION MANAGEMENT

	/**
	 * @notice Initiates a session request between a provider and a session owner
	 * @dev Creates or retrieves an account and stores the session request for later confirmation
	 * @param sessionSalt A unique salt used to deterministically generate the account address
	 * @param sessionRequestHash Hash of the session request data
	 * @param signedSessionRequestHash Signature of the session request hash by the session owner
	 * @param signedSessionHash Signature of the session hash by the provider
	 * @param sessionRequestExpiry Timestamp when the session request expires (0 for no expiry)
	 * @custom:throws SessionRequestExpired if the expiry timestamp is in the past
	 * @custom:throws SessionOwnerIsProvider if the recovered session owner is the same as the provider
	 * @custom:emits Requested event with provider address and session request hash
	 */
	function request(
		bytes32 sessionSalt,
		bytes32 sessionRequestHash,
		bytes calldata signedSessionRequestHash,
		bytes calldata signedSessionHash,
		uint48 sessionRequestExpiry
	) external {
		// TODO: add a uint48 challengeExpiry as well to expire the session request after a certain time, ok for now
		// make sure challengeExpiry is in the future
		if (sessionRequestExpiry > 0 && sessionRequestExpiry < block.timestamp) {
			revert SessionRequestExpired();
		}

		// provider is sender
		address provider = msg.sender;

		// get account address and deploy account if it doesn't exist
		uint256 salt = _bytes32ToUint256(sessionSalt);
		address account = TwoFAFactory(twoFAFactory).createAccount(provider, salt);

		// recover session owner
		address sessionOwner = _recoverEthSignedSigner(sessionRequestHash, signedSessionRequestHash);

		// session owner should not be provider
		if (sessionOwner == provider) {
			revert SessionOwnerIsProvider();
		}

		// save session request
		sessionRequests[provider][sessionRequestHash] = SessionRequest({
			expiry: sessionRequestExpiry,
			signedSessionHash: signedSessionHash,
			provider: provider,
			owner: sessionOwner,
			account: account
		});

		emit Requested(provider, sessionRequestHash);
	}

	/**
	 * @notice Confirms a session request and adds the session owner as a signer to the account
	 * @dev Verifies signatures from both provider and owner before adding the owner as a signer
	 * @param sessionRequestHash Hash of the session request to confirm
	 * @param sessionHash Hash of the session data
	 * @param ownerSignedSessionHash Signature of the session hash by the session owner
	 * @custom:throws SessionRequestNotFound if the session request doesn't exist
	 * @custom:throws SessionRequestExpired if the session request has expired
	 * @custom:throws InvalidProvider if the recovered provider doesn't match the sender
	 * @custom:throws InvalidOwnerSignedSessionHash if the owner signature is invalid
	 * @custom:emits Confirmed event with provider, account, and session owner addresses
	 */
	function confirm(bytes32 sessionRequestHash, bytes32 sessionHash, bytes calldata ownerSignedSessionHash) external {
		// check if session request exists
		SessionRequest memory sessionRequest = sessionRequests[msg.sender][sessionRequestHash];
		if (sessionRequest.owner == address(0)) {
			revert SessionRequestNotFound();
		}

		// check if session request has expired
		if (sessionRequest.expiry > 0 && sessionRequest.expiry < block.timestamp) {
			revert SessionRequestExpired();
		}

		// provider is sender
		address provider = msg.sender;

		// check if provider is valid
		if (sessionRequest.provider != provider) {
			revert InvalidProvider();
		}

		if (!_isOwnerSignature(provider, sessionHash, sessionRequest.signedSessionHash)) {
			revert InvalidProvider();
		}

		// check if owner signed session hash is valid
		if (_recoverEthSignedSigner(sessionHash, ownerSignedSessionHash) != sessionRequest.owner) {
			revert InvalidOwnerSignedSessionHash();
		}

		// add session owner as signer
		_addSigner(sessionRequest.account, sessionRequest.owner);

		// set expiry
		activeSessions.push(
			ActiveSession({
				owner: sessionRequest.owner,
				account: sessionRequest.account,
				expiry: sessionRequest.expiry
			})
		);

		// delete session request
		delete sessionRequests[provider][sessionRequestHash];

		emit Confirmed(provider, sessionRequest.account, sessionRequest.owner);
	}

	/**
	 * @notice Calculates the deterministic account address for a given session salt
	 * @dev Uses the TwoFAFactory to compute the address without deploying the contract
	 * @param sessionSalt A unique salt used to deterministically generate the account address
	 * @return The address where the account contract would be deployed with the given salt
	 */
	function _getAccountAddress(bytes32 sessionSalt) internal view returns (address) {
		uint256 salt = _bytes32ToUint256(sessionSalt);

		address accountAddress = TwoFAFactory(twoFAFactory).getAddress(address(this), salt);

		return accountAddress;
	}

	/**
	 * @notice Converts a bytes32 value to a uint256
	 * @dev Simple type conversion used for salt calculations
	 * @param b The bytes32 value to convert
	 * @return The equivalent uint256 value
	 */
	function _bytes32ToUint256(bytes32 b) internal pure returns (uint256) {
		return uint256(b);
	}

	/////////////////////////////////////////////////
	// ACCOUNT OWNERSHIP

	/**
	 * @notice Internal function to add a new signer to an account
	 * @dev Uses the Safe's ModuleManager to execute the addOwnerWithThreshold function
	 *      while maintaining the same threshold
	 * @param account The address of the account to modify
	 * @param newSigner The address to add as a new signer
	 * @custom:throws AccountNotCreated if the account is not a valid contract
	 * @custom:throws FailedToAddSigner if the transaction to add the signer fails
	 */
	function _addSigner(address account, address newSigner) internal {
		if (!contractExists(account)) {
			revert AccountNotCreated();
		}

		uint256 threshold = OwnerManager(account).getThreshold();

		bytes memory data = abi.encodeCall(OwnerManager.addOwnerWithThreshold, (newSigner, threshold));

		bool success = ModuleManager(account).execTransactionFromModule(account, 0, data, Enum.Operation.Call);
		if (!success) {
			revert FailedToAddSigner();
		}
	}

	/**
	 * @notice Internal function to remove a signer from an account
	 * @dev Uses the Safe's ModuleManager to execute the removeOwner function
	 *      Safe uses a linked list structure for owners, so we need to find the previous owner
	 *      in the list before removing the target signer
	 * @param account The address of the account to modify
	 * @param signer The address to remove as a signer
	 * @custom:throws SignerNotOwner if the signer is not an owner of the account
	 * @custom:throws FailedToRemoveSigner if the transaction to remove the signer fails
	 */
	function _removeSigner(address account, address signer) internal {
		OwnerManager ownerManager = OwnerManager(account);

		if (!ownerManager.isOwner(signer)) {
			revert SignerNotOwner();
		}

		uint256 threshold = ownerManager.getThreshold();

		// Need to find the previous owner in the linked list
		address[] memory owners = ownerManager.getOwners();
		address prevOwner = address(0x1);
		address currentOwner = signer;

		// Traverse the linked list to find the previous owner
		for (uint256 i = 0; i < owners.length; i++) {
			if (owners[i] == signer) {
				// If signer is the first owner in the array, prevOwner should remain SENTINEL_OWNERS
				if (i > 0) {
					prevOwner = owners[i - 1];
				}
				break;
			}
		}

		bytes memory data = abi.encodeCall(OwnerManager.removeOwner, (prevOwner, currentOwner, threshold));

		bool success = ModuleManager(account).execTransactionFromModule(account, 0, data, Enum.Operation.Call);
		if (!success) {
			revert FailedToRemoveSigner();
		}
	}

	/**
	 * @notice Adds a new signer to the calling account
	 * @dev Can only be called by an existing account contract
	 * @param signer The address to add as a new signer to the account
	 * @custom:throws AccountNotCreated if the caller is not a valid contract
	 * @custom:throws SignerAlreadyExists if the signer is already an owner of the account
	 */
	function addSigner(address signer) public {
		if (!contractExists(msg.sender)) {
			revert AccountNotCreated();
		}

		if (OwnerManager(msg.sender).isOwner(signer)) {
			revert SignerAlreadyExists();
		}

		_addSigner(msg.sender, signer);
	}

	/**
	 * @notice Removes a signer from the calling account
	 * @dev Can only be called by an existing account contract
	 * @param signer The address to remove as a signer from the account
	 * @custom:throws AccountNotCreated if the caller is not a valid contract
	 * @custom:throws SignerNotOwner if the signer is not an owner of the account
	 */
	function revoke(address signer) public {
		if (!contractExists(msg.sender)) {
			revert AccountNotCreated();
		}

		if (!OwnerManager(msg.sender).isOwner(signer)) {
			revert SignerNotOwner();
		}

		_removeSigner(msg.sender, signer);
	}

	/////////////////////////////////////////////////
	// Session Management

	/**
	 * @notice Removes all expired sessions from active sessions
	 * @dev Iterates through all active sessions, removes signers from accounts where sessions have expired,
	 *      and deletes the expired session entries from the activeSessions array
	 * @custom:security This function is called automatically by the Guard's checkTransaction function
	 *                  before any transaction execution to ensure expired sessions are properly cleaned up
	 */
	function removeExpiredSessions() public {
		if (activeSessions.length == 0) {
			return;
		}

		for (uint256 i = 0; i < activeSessions.length; i++) {
			if (activeSessions[i].expiry < block.timestamp) {
				_removeSigner(activeSessions[i].account, activeSessions[i].owner);

				delete activeSessions[i];
			}
		}
	}

	/////////////////////////////////////////////////

	/////////////////////////////////////////////////
	// Guard

	/**
	 * @notice Hook that is called before any transaction execution
	 * @dev Implements the Guard interface to automatically clean up expired sessions
	 *      before any transaction is executed
	 */
	function checkTransaction(
		address /*to*/,
		uint256 /*value*/,
		bytes memory /*data*/,
		Enum.Operation /*operation*/,
		uint256 /*safeTxGas*/,
		uint256 /*baseGas*/,
		uint256 /*gasPrice*/,
		address /*gasToken*/,
		address payable /*refundReceiver*/,
		bytes memory /*signatures*/,
		address /*msgSender*/
	) external override {
		removeExpiredSessions();
	}

	/**
	 * @notice Hook that is called after a transaction has been executed
	 * @dev Required by the Guard interface but not used in this implementation
	 */
	function checkAfterExecution(bytes32 /*txHash*/, bool /*success*/) external override {}

	/**
	 * @notice Determines if the contract implements a specific interface
	 * @dev Overrides both BaseGuard and TokenCallbackHandler implementations
	 * @param interfaceId The interface identifier to check
	 * @return True if the contract implements the interface, false otherwise
	 */
	function supportsInterface(
		bytes4 interfaceId
	) external view virtual override(BaseGuard, TokenCallbackHandler) returns (bool) {
		return
			interfaceId == type(Guard).interfaceId || // 0xe6d7a83a
			interfaceId == type(IERC165).interfaceId; // 0x01ffc9a7
	}

	/////////////////////////////////////////////////

	/////////////////////////////////////////////////
	// HELPERS

	/**
	 * @notice Checks if a contract exists at the given address
	 * @dev Uses assembly to check the code size at the address
	 * @param contractAddress The address to check for contract code
	 * @return True if contract code exists at the address, false otherwise
	 */
	function contractExists(address contractAddress) public view returns (bool) {
		uint256 size;
		// solhint-disable-next-line no-inline-assembly
		assembly {
			size := extcodesize(contractAddress)
		}
		return size > 0;
	}

	/**
	 * @notice Extracts a bytes32 value from a bytes array at the specified index
	 * @dev Uses assembly for efficient memory access
	 * @param data The bytes array to read from
	 * @param index The starting position in the bytes array
	 * @return result The bytes32 value at the specified index
	 */
	function readBytes32(bytes memory data, uint256 index) internal pure returns (bytes32 result) {
		require(data.length >= index + 32, "readBytes32: invalid data length");
		assembly {
			result := mload(add(data, add(32, index)))
		}
	}

	/**
	 * @notice Determines if a signature is valid for an account, either directly or through ERC1271 validation
	 * @dev Checks multiple validation paths: direct signer match, ERC1271 contract validation, or ownership via OwnerManager
	 * @param account The account address to check ownership against
	 * @param _hash The message hash that was signed
	 * @param _signature The signature bytes to validate
	 * @return True if the signature is valid for the account, false otherwise
	 */
	function _isOwnerSignature(address account, bytes32 _hash, bytes memory _signature) internal view returns (bool) {
		// First, recover the signer address from the signature
		address signer = _recoverEthSignedSigner(_hash, _signature);
		
		// If recovery failed (returned address zero), the signature is invalid
		if (signer == address(0)) {
			return false;
		}

		// If the signer is the account itself, it's automatically valid
		if (signer == account) {
			return true;
		}

		// If the account is not a contract, we can't perform further checks
		if (!contractExists(account)) {
			return false;
		}

		// Try ERC1271 signature validation if the account is a contract
		// This allows smart contracts to implement their own signature validation logic
		try IERC1271(account).isValidSignature(_hash, _signature) returns (bytes4 magicValue) {
			// The magic value 0x1626ba7e is the ERC1271 standard return value for valid signatures
			if (magicValue == 0x1626ba7e) {
				return true; // Signature is valid according to the contract's validation logic
			}
			// If a different magic value is returned, the signature is considered invalid
		} catch {
			// If the call reverts, the contract might not implement ERC1271
			// We'll fall through to the OwnerManager check
		}

		// As a final check, verify if the signer is registered as an owner in the OwnerManager
		return OwnerManager(account).isOwner(signer);
	}

	/**
	 * @notice Recovers the signer of an Ethereum signed message hash
	 * @dev Converts the hash to an Ethereum signed message hash before recovery
	 * @param _hash The original hash that was signed
	 * @param _signature The signature bytes
	 * @return signer The address that signed the message
	 */
	function _recoverEthSignedSigner(bytes32 _hash, bytes memory _signature) internal pure returns (address signer) {
		return recoverSigner(toEthSignedMessageHash(_hash), _signature);
	}

	/**
	 * @notice Recover the signer of hash, assuming it's an EOA account
	 * @dev Only for EthSign signatures
	 * @param _hash Hash of message that was signed
	 * @param _signature Signature encoded as (bytes32 r, bytes32 s, uint8 v)
	 * @return signer The address that signed the message
	 */
	function recoverSigner(bytes32 _hash, bytes memory _signature) internal pure returns (address signer) {
		require(_signature.length == 65, "SignatureValidator#recoverSigner: invalid signature length");

		// Variables are not scoped in Solidity.
		uint8 v = uint8(_signature[64]);
		bytes32 r = readBytes32(_signature, 0);
		bytes32 s = readBytes32(_signature, 32);

		// EIP-2 still allows signature malleability for ecrecover(). Remove this possibility and make the signature
		// unique. Appendix F in the Ethereum Yellow paper (https://ethereum.github.io/yellowpaper/paper.pdf), defines
		// the valid range for s in (281): 0 < s < secp256k1n ÷ 2 + 1, and for v in (282): v ∈ {27, 28}. Most
		// signatures from current libraries generate a unique signature with an s-value in the lower half order.
		//
		// If your library generates malleable signatures, such as s-values in the upper range, calculate a new s-value
		// with 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141 - s1 and flip v from 27 to 28 or
		// vice versa. If your library also generates signatures with 0/1 for v instead 27/28, add 27 to v to accept
		// these malleable signatures as well.
		//
		// Source OpenZeppelin
		// https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/cryptography/ECDSA.sol

		if (uint256(s) > 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0) {
			revert("SignatureValidator#recoverSigner: invalid signature 's' value");
		}

		if (v != 27 && v != 28) {
			revert("SignatureValidator#recoverSigner: invalid signature 'v' value");
		}

		// Recover ECDSA signer
		signer = ecrecover(_hash, v, r, s);

		// Prevent signer from being 0x0
		require(signer != address(0x0), "SignatureValidator#recoverSigner: INVALID_SIGNER");

		return signer;
	}

	/////////////////////////////////////////////////
}
