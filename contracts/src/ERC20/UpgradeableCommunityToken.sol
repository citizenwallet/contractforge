// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

import { ERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import { ERC20BurnableUpgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { AccessControlUpgradeable } from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { ERC20PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PausableUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract UpgradeableCommunityToken is
	Initializable,
	ERC20Upgradeable,
	ERC20BurnableUpgradeable,
	OwnableUpgradeable,
	AccessControlUpgradeable,
	ERC20PausableUpgradeable,
	UUPSUpgradeable
{
	bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
	bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

	event Minted(address indexed to, uint256 amount);

    // Custom errors
    error MustHaveMinterRole(address account);

	function initialize(
		address _owner,
		address[] memory minters,
		string memory name,
		string memory symbol
	) public initializer {
		__ERC20_init(name, symbol);
		__Ownable_init(_owner);
		__AccessControl_init();
		__UUPSUpgradeable_init();

		_grantRole(DEFAULT_ADMIN_ROLE, _owner);

		_setRoleAdmin(MINTER_ROLE, DEFAULT_ADMIN_ROLE);
		_setRoleAdmin(PAUSER_ROLE, DEFAULT_ADMIN_ROLE);

		for (uint256 i = 0; i < minters.length; i++) {
			_grantRole(MINTER_ROLE, minters[i]);
		}
	}

	function decimals() public view virtual override returns (uint8) {
		return 6;
	}

	function mint(address to, uint256 amount) public {
        if (!hasRole(MINTER_ROLE, msg.sender)) revert MustHaveMinterRole(msg.sender);
		_mint(to, amount);
		emit Minted(to, amount);
	}

	function pause() public onlyRole(PAUSER_ROLE) {
		_pause();
	}

	function unpause() public onlyRole(PAUSER_ROLE) {
		_unpause();
	}

	function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

	function _update(
		address from,
		address to,
		uint256 value
	) internal override(ERC20Upgradeable, ERC20PausableUpgradeable) onlyOwner whenNotPaused {
		super._update(from, to, value);
	}
}
