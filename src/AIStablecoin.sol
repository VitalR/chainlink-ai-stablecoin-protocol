// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { ERC20Burnable, ERC20 } from "@openzeppelin/token/ERC20/extensions/ERC20Burnable.sol";
import { ERC20Permit } from "@openzeppelin/token/ERC20/extensions/ERC20Permit.sol";
import { OwnedThreeStep } from "@solbase/auth/OwnedThreeStep.sol";

/// @title AIStablecoin - AI-Powered USD Stablecoin (AIUSD)
/// @notice Decentralized stablecoin with AI-driven dynamic collateral ratios and vault-based minting
/// @dev ERC20 token with burn capabilities, permit functionality, and vault authorization system
contract AIStablecoin is ERC20Burnable, ERC20Permit, OwnedThreeStep {
    // =============================================================
    //                 CONFIGURATION & STORAGE
    // =============================================================

    /// @notice State mapping for vault authorization and access control
    /// @dev Maps vault addresses to their authorization status for minting and burning operations
    mapping(address => bool) public authorizedVaults;

    // =============================================================
    //                    EVENTS & ERRORS
    // =============================================================

    /// @notice Vault management events
    event VaultAdded(address indexed vault);
    event VaultRemoved(address indexed vault);

    /// @notice Validation errors
    error InvalidAddress(address account);
    error InvalidAmount(uint256 amount);
    error UnauthorizedAccount();

    // =============================================================
    //                  DEPLOYMENT & INITIALIZATION
    // =============================================================

    /// @notice Deploy and initialize the AI USD Stablecoin token
    /// @dev Sets up ERC20 token with name, symbol, permit functionality, and owner authorization
    constructor() ERC20("AI USD Stablecoin", "AIUSD") ERC20Permit("AI USD Stablecoin") OwnedThreeStep(msg.sender) { }

    // =============================================================
    //                     ACCESS CONTROL
    // =============================================================

    /// @notice Restrict function access to authorized vault contracts only
    modifier onlyAuthorizedVaults() {
        if (!authorizedVaults[msg.sender]) revert UnauthorizedAccount();
        _;
    }

    // =============================================================
    //                        CORE LOGIC
    // =============================================================

    /// @notice Mint AIUSD tokens to specified address
    /// @dev Only authorized vaults can mint tokens based on collateral deposits and AI assessments
    /// @param _to Address to receive newly minted AIUSD tokens
    /// @param _amount Number of tokens to mint (18 decimal places)
    /// @return success Whether the minting operation completed successfully
    function mint(address _to, uint256 _amount) external onlyAuthorizedVaults returns (bool) {
        if (_to == address(0)) revert InvalidAddress(_to);
        if (_amount == 0) revert InvalidAmount(_amount);

        _mint(_to, _amount);
        return true;
    }

    /// @notice Burn AIUSD tokens from caller's balance
    /// @dev Overrides ERC20Burnable burn function with vault-only restriction and validation
    /// @param _amount Number of tokens to burn from caller's balance
    function burn(uint256 _amount) public override onlyAuthorizedVaults {
        if (_amount == 0) revert InvalidAmount(_amount);
        _burn(msg.sender, _amount);
    }

    /// @notice Burn AIUSD tokens from specified address with allowance check
    /// @dev Overrides ERC20Burnable burnFrom with vault-only access and comprehensive validation
    /// @param _from Address from which tokens will be burned
    /// @param _amount Number of tokens to burn from specified address
    function burnFrom(address _from, uint256 _amount) public override onlyAuthorizedVaults {
        uint256 balance = balanceOf(_from);
        if (_amount == 0) revert InvalidAmount(_amount);
        if (balance < _amount) revert InvalidAmount(_amount);

        // Handle allowance checking with infinite approval optimization
        uint256 currentAllowance = allowance(_from, msg.sender);
        if (currentAllowance != type(uint256).max) {
            if (currentAllowance < _amount) revert InvalidAmount(_amount);
            _approve(_from, msg.sender, currentAllowance - _amount);
        }

        _burn(_from, _amount);
    }

    // =============================================================
    //                     MANAGER LOGIC
    // =============================================================

    /// @notice Authorize vault contract for AIUSD minting and burning operations
    /// @dev Only contract owner can grant vault authorization for token operations
    /// @param _vault Address of the vault contract to authorize
    function addVault(address _vault) external onlyOwner {
        if (_vault == address(0)) revert InvalidAddress(_vault);
        authorizedVaults[_vault] = true;
        emit VaultAdded(_vault);
    }

    /// @notice Revoke vault authorization for AIUSD operations
    /// @dev Only contract owner can remove vault authorization and disable token operations
    /// @param _vault Address of the vault contract to deauthorize
    function removeVault(address _vault) external onlyOwner {
        if (_vault == address(0)) revert InvalidAddress(_vault);
        authorizedVaults[_vault] = false;
        emit VaultRemoved(_vault);
    }
}
