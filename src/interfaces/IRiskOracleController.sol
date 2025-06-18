// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/// @title IRiskOracleController Interface
/// @notice Interface for AI-powered risk assessment and collateral ratio determination
/// @dev Defines the contract interface for submitting collateral baskets to AI analysis via Chainlink Functions
interface IRiskOracleController {
    /// @notice Submit collateral basket for AI-powered risk assessment
    /// @dev Creates Chainlink Functions request with collateral data and current market prices
    /// @param user Address of the user who deposited collateral
    /// @param basketData Encoded information about the collateral basket composition
    /// @param collateralValue Total USD value of the deposited collateral (18 decimals)
    /// @return requestId Unique identifier for tracking this AI assessment request
    function submitAIRequest(address user, bytes calldata basketData, uint256 collateralValue)
        external
        payable
        returns (uint256 requestId);
}
