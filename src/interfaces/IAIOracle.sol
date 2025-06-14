// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/// @title IAIOracle - Interface for ORA OAO (Complete Version)
/// @notice Defines the core functionality for AI oracle interactions
/// @dev Based on the working interface from bootcamp projects and proxy implementation
interface IAIOracle {
    /// @notice Event emitted upon receiving a callback request
    event AICallbackRequest(
        address account,
        uint256 requestId,
        uint256 modelId,
        bytes input,
        address callbackContract,
        uint64 gasLimit,
        bytes callbackData
    );

    /// @notice Event emitted when the result is uploaded or updated
    event AICallbackResult(uint256 requestId, bytes output);

    /// @notice Submit a callback request to the AI oracle
    /// @dev Initiates a request in OAO
    /// @param modelId ID for AI model
    /// @param input Input for AI model
    /// @param callbackContract Address of callback contract
    /// @param gasLimit Gas limitation of calling the callback function
    /// @param callbackData Optional, user-defined data, will send back to the callback function
    /// @return requestId The ID of this request
    function requestCallback(
        uint256 modelId,
        bytes calldata input,
        address callbackContract,
        uint64 gasLimit,
        bytes calldata callbackData
    ) external payable returns (uint256 requestId);

    /// @notice Estimate the fee required for a request
    /// @param modelId The AI model to use
    /// @param gasLimit Gas limit for the callback
    /// @return The estimated fee in wei
    function estimateFee(uint256 modelId, uint64 gasLimit) external view returns (uint256);

    /// @notice Check if a request has been finalized
    /// @param requestId The request ID to check
    /// @return Whether the request is finalized
    function isFinalized(uint256 requestId) external view returns (bool);

    /// @notice Get the result of an AI request
    /// @param requestId The request ID to get result for
    /// @return The AI result as bytes
    function getResult(uint256 requestId) external view returns (bytes memory);
}
