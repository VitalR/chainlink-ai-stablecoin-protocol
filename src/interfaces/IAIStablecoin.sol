// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { IERC20 } from "@openzeppelin/token/ERC20/IERC20.sol";

/// @title IAIStablecoin Interface
/// @notice Interface for the AI-driven stablecoin contract
interface IAIStablecoin is IERC20 {
    /// @notice Mint new tokens to a specific address
    /// @param to Address to mint tokens to
    /// @param amount Amount of tokens to mint
    function mint(address to, uint256 amount) external;

    /// @notice Burn tokens from a specific address
    /// @param from Address to burn tokens from
    /// @param amount Amount of tokens to burn
    function burnFrom(address from, uint256 amount) external;

    /// @notice Add a new authorized vault
    /// @param vault Address of the vault to authorize
    function addVault(address vault) external;

    /// @notice Remove an authorized vault
    /// @param vault Address of the vault to remove
    function removeVault(address vault) external;

    /// @notice Check if an address is an authorized vault
    /// @param vault Address to check
    /// @return Whether the address is an authorized vault
    function isVault(address vault) external view returns (bool);
}
