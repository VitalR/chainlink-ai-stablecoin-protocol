// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { OwnedThreeStep } from "@solbase/auth/OwnedThreeStep.sol";
import { AISimplePromptController } from "./AISimplePromptController.sol";
import { AICollateralVaultSimple } from "./AICollateralVaultSimple.sol";

/// @title AIEventProcessor - On-chain Event Processing for SimplePrompt Pattern
/// @notice Processes AI results from events and triggers vault operations
/// @dev Can be called by anyone (permissionless) or restricted to authorized operators
contract AIEventProcessor is OwnedThreeStep {
    /// @notice Core contracts
    AISimplePromptController public immutable controller;
    AICollateralVaultSimple public immutable vault;

    /// @notice Configuration
    mapping(address => bool) public authorizedOperators;
    bool public permissionlessMode = true; // Allow anyone to process by default

    /// @notice Tracking processed requests to prevent double-processing
    mapping(uint256 => bool) public processedRequests;

    /// @notice Events
    event ResultProcessed(uint256 indexed requestId, address indexed user, uint256 mintAmount);
    event OperatorUpdated(address indexed operator, bool authorized);
    event PermissionlessModeUpdated(bool enabled);
    event ProcessingFailed(uint256 indexed requestId, string reason);

    /// @notice Custom errors
    error UnauthorizedOperator();
    error RequestAlreadyProcessed();
    error InvalidOutput();
    error ProcessingError();

    /// @notice Modifier for access control
    modifier onlyAuthorizedOperator() {
        if (!permissionlessMode && !authorizedOperators[msg.sender]) {
            revert UnauthorizedOperator();
        }
        _;
    }

    /// @notice Initialize the processor
    constructor(address _controller, address payable _vault) OwnedThreeStep(msg.sender) {
        controller = AISimplePromptController(_controller);
        vault = AICollateralVaultSimple(_vault);
    }

    /// @notice Process AI result from event data
    /// @param oracleRequestId The oracle request ID from the event
    /// @param internalRequestId The internal request ID from the event
    /// @param output The AI output from the event
    /// @param callbackData The callback data from the event
    function processAIResult(
        uint256 oracleRequestId,
        uint256 internalRequestId,
        bytes calldata output,
        bytes calldata callbackData
    ) external onlyAuthorizedOperator {
        // Prevent double processing
        if (processedRequests[internalRequestId]) {
            revert RequestAlreadyProcessed();
        }

        // Decode callback data to get user and vault info
        (address vaultAddress, address user, bytes memory basketData, uint256 collateralValue,) =
            abi.decode(callbackData, (address, address, bytes, uint256, uint256));

        // Verify this is for our vault
        require(vaultAddress == address(vault), "Wrong vault");

        try vault.processAIResult(user, internalRequestId, output) {
            // Mark as processed
            processedRequests[internalRequestId] = true;

            // Get the pending mint info to emit details
            AICollateralVaultSimple.PendingMint memory pendingMint = vault.getPendingMint(internalRequestId);

            emit ResultProcessed(internalRequestId, user, pendingMint.mintAmount);
        } catch Error(string memory reason) {
            emit ProcessingFailed(internalRequestId, reason);
            revert ProcessingError();
        }
    }

    /// @notice Finalize mint for a processed request
    /// @param requestId The request ID to finalize
    function finalizeMint(uint256 requestId) external onlyAuthorizedOperator {
        try vault.finalizeMint(requestId) {
            // Success - event will be emitted by vault
        } catch Error(string memory reason) {
            emit ProcessingFailed(requestId, reason);
            revert ProcessingError();
        }
    }

    /// @notice Process and finalize in one transaction (convenience function)
    /// @param oracleRequestId The oracle request ID from the event
    /// @param internalRequestId The internal request ID from the event
    /// @param output The AI output from the event
    /// @param callbackData The callback data from the event
    function processAndFinalize(
        uint256 oracleRequestId,
        uint256 internalRequestId,
        bytes calldata output,
        bytes calldata callbackData
    ) external onlyAuthorizedOperator {
        // Process the AI result
        this.processAIResult(oracleRequestId, internalRequestId, output, callbackData);

        // Finalize the mint
        this.finalizeMint(internalRequestId);
    }

    /// @notice Batch process multiple results (gas efficient)
    /// @param requests Array of request data to process
    struct BatchRequest {
        uint256 oracleRequestId;
        uint256 internalRequestId;
        bytes output;
        bytes callbackData;
    }

    function batchProcessAndFinalize(BatchRequest[] calldata requests) external onlyAuthorizedOperator {
        for (uint256 i = 0; i < requests.length; i++) {
            try this.processAndFinalize(
                requests[i].oracleRequestId, requests[i].internalRequestId, requests[i].output, requests[i].callbackData
            ) {
                // Success
            } catch {
                // Log failure but continue with other requests
                emit ProcessingFailed(requests[i].internalRequestId, "Batch processing failed");
            }
        }
    }

    /// @notice Emergency function to cancel timed out requests
    /// @param user The user whose request timed out
    /// @param requestId The request ID to cancel
    function cancelTimedOutRequest(address user, uint256 requestId) external {
        // This can be called by anyone for timed out requests
        vault.cancelTimedOutRequest(requestId);
    }

    /// @notice Admin functions
    function setAuthorizedOperator(address operator, bool authorized) external onlyOwner {
        authorizedOperators[operator] = authorized;
        emit OperatorUpdated(operator, authorized);
    }

    function setPermissionlessMode(bool enabled) external onlyOwner {
        permissionlessMode = enabled;
        emit PermissionlessModeUpdated(enabled);
    }

    /// @notice View functions
    function isRequestProcessed(uint256 requestId) external view returns (bool) {
        return processedRequests[requestId];
    }

    function canProcess(address operator) external view returns (bool) {
        return permissionlessMode || authorizedOperators[operator];
    }
}
