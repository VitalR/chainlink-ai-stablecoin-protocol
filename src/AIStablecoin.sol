// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { ERC20Burnable, ERC20 } from "@openzeppelin/token/ERC20/extensions/ERC20Burnable.sol";
import { ERC20Permit } from "@openzeppelin/token/ERC20/extensions/ERC20Permit.sol";
import { OwnedThreeStep } from "@solbase/auth/OwnedThreeStep.sol";

/// @title AIStablecoin (AIUSD)
/// @notice AI-optimized stablecoin with dynamic collateral ratios.
contract AIStablecoin is ERC20Burnable, ERC20Permit, OwnedThreeStep {
    /// @notice Mapping of addresses recognized as authorizedVaults .
    mapping(address => bool) public authorizedVaults;

    event VaultAdded(address indexed vault);
    event VaultRemoved(address indexed vault);

    error UnauthorizedAccount(address account);
    error InvalidAddress(address account);
    error InvalidAmount(uint256 amount);

    /// @notice Ensures the function is called by a trusted pool only.
    modifier onlyAuthorizedVaults() {
        if (!authorizedVaults[msg.sender]) revert UnauthorizedAccount(msg.sender);
        _;
    }

    /// @notice Initializes the AIStablecoin contract.
    /// @dev Sets the name and symbol of the token, and the owner of the contract.
    constructor() ERC20("AI USD Stablecoin", "AIUSD") ERC20Permit("AI USD Stablecoin") OwnedThreeStep(msg.sender) { }

    /// @notice Mint AIUSD tokens (only authorized vaults).
    function mint(address _to, uint256 _amount) external onlyAuthorizedVaults returns (bool) {
        if (_to == address(0)) revert InvalidAddress(_to);
        if (_amount == 0) revert InvalidAmount(_amount);
        _mint(_to, _amount);
        return true;
    }

    /// @notice Burn AIUSD tokens.
    /// @dev Overrides the `burn` function of ERC20Burnable to include custom logic and can only be called by an
    /// authorized vault.
    /// @param _amount The number of tokens to burn.
    function burn(uint256 _amount) public override onlyAuthorizedVaults {
        if (_amount == 0) revert InvalidAmount(_amount);
        _burn(msg.sender, _amount);
    }

    /// @notice Burns a specific amount of AIUSD tokens from an address.
    /// @dev Overrides the `burnFrom` function of ERC20Burnable to include custom logic and can only be called by an
    /// authorized vault.
    /// @param _from The address from which tokens will be burned.
    /// @param _amount The number of tokens to burn.
    function burnFrom(address _from, uint256 _amount) public override onlyAuthorizedVaults {
        uint256 balance = balanceOf(_from);
        if (_amount == 0) revert InvalidAmount(_amount);
        if (balance < _amount) revert InvalidAmount(_amount);
        _burn(_from, _amount);
    }

    /// @notice Add authorized vault.
    /// @dev Only the owner can add authorized vaults.
    /// @param _vault The address of the vault to add.
    function addVault(address _vault) external onlyOwner {
        if (_vault == address(0)) revert InvalidAddress(_vault);
        authorizedVaults[_vault] = true;
        emit VaultAdded(_vault);
    }

    /// @notice Remove authorized vault.
    /// @dev Only the owner can remove authorized vaults.
    /// @param _vault The address of the vault to remove.
    function removeVault(address _vault) external onlyOwner {
        if (_vault == address(0)) revert InvalidAddress(_vault);
        authorizedVaults[_vault] = false;
        emit VaultRemoved(_vault);
    }
}
