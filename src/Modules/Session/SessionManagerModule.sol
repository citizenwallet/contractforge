// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

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
contract SessionManagerModule is
	CompatibilityFallbackHandler,
	BaseGuard,
	Initializable,
	ReentrancyGuardUpgradeable,
	OwnableUpgradeable,
	UUPSUpgradeable
{
	string public constant NAME = "Session Module";
	string public constant VERSION = "0.0.1";

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

	function request(
		bytes32 sessionSalt,
		bytes32 sessionRequestHash,
		bytes calldata signedSessionRequestHash,
		bytes calldata signedSessionHash,
		uint48 sessionRequestExpiry
	) external {
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
			owner: sessionOwner,
			account: account
		});

		emit Requested(provider, sessionRequestHash);
	}

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
		address recoveredProvider = _recoverEthSignedSigner(sessionHash, sessionRequest.signedSessionHash);
		if (recoveredProvider != provider) {
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

	function _getAccountAddress(bytes32 sessionSalt) internal view returns (address) {
		uint256 salt = _bytes32ToUint256(sessionSalt);

		address accountAddress = TwoFAFactory(twoFAFactory).getAddress(address(this), salt);

		return accountAddress;
	}

	function _bytes32ToUint256(bytes32 b) internal pure returns (uint256) {
		return uint256(b);
	}

	/////////////////////////////////////////////////
	// ACCOUNT OWNERSHIP

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

	/////////////////////////////////////////////////
	// Session Management

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

	function checkAfterExecution(bytes32 txHash, bool success) external override {}

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

	function contractExists(address contractAddress) public view returns (bool) {
		uint256 size;
		// solhint-disable-next-line no-inline-assembly
		assembly {
			size := extcodesize(contractAddress)
		}
		return size > 0;
	}

	function readBytes32(bytes memory data, uint256 index) internal pure returns (bytes32 result) {
		require(data.length >= index + 32, "readBytes32: invalid data length");
		assembly {
			result := mload(add(data, add(32, index)))
		}
	}

	function _recoverEthSignedSigner(bytes32 _hash, bytes memory _signature) internal pure returns (address signer) {
		return recoverSigner(toEthSignedMessageHash(_hash), _signature);
	}

	/**
	 * @notice Recover the signer of hash, assuming it's an EOA account
	 * @dev Only for EthSign signatures
	 * @param _hash       Hash of message that was signed
	 * @param _signature  Signature encoded as (bytes32 r, bytes32 s, uint8 v)
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
