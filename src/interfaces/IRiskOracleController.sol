// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/// @title IRiskOracleController Interface
/// @notice Interface for AI-powered risk assessment and collateral ratio determination
/// @dev Defines the contract interface for submitting collateral baskets to AI analysis via Chainlink Functions
interface IRiskOracleController {
    /// @notice AI engine types for hybrid AI architecture
    /// @param ALGO Algorithmic AI engine (always available, fully decentralized)
    /// @param BEDROCK Amazon Bedrock AI engine (advanced analysis, subject to DON constraints)
    /// @param TEST_TIMEOUT Mock engine that simulates timeout for testing emergency automation
    enum Engine {
        ALGO,
        BEDROCK,
        TEST_TIMEOUT
    }

    /// @notice Submit collateral basket for AI-powered risk assessment
    /// @dev Creates Chainlink Functions request with collateral data and current market prices
    /// @param user Address of the user who deposited collateral
    /// @param basketData Encoded information about the collateral basket composition
    /// @param collateralValue Total USD value of the deposited collateral (18 decimals)
    /// @param engine AI engine to use for this request (ALGO, BEDROCK, or TEST_TIMEOUT for testing)
    /// @return requestId Unique identifier for tracking this AI assessment request
    function submitAIRequest(address user, bytes calldata basketData, uint256 collateralValue, Engine engine)
        external
        payable
        returns (uint256 requestId);
}
