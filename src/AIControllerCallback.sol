// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { OwnedThreeStep } from "@solbase/auth/OwnedThreeStep.sol";

/// @title AIControllerCallback - Core Infrastructure
/// @notice Core infrastructure for AI-driven collateral ratio management
contract AIControllerCallback is OwnedThreeStep {
    /// @notice Mapping of authorized callers
    mapping(address => bool) public authorizedCallers;

    /// @notice State management
    mapping(uint256 => RequestInfo) public requests;
    uint256 private requestCounter = 1;

    /// @notice Request information
    struct RequestInfo {
        address vault;
        address user;
        bytes basketData;
        uint256 collateralValue;
        uint256 timestamp;
        bool processed;
    }

    /// @notice Events
    event AuthorizedCallerUpdated(address indexed caller, bool authorized);
    event FeeUpdated(uint256 fee);
    event ModelIdUpdated(uint256 modelId);

    /// @notice Custom errors
    error UnauthorizedCaller();
    error InsufficientFee();
    error InvalidCallback();
    error AlreadyProcessed();

    /// @notice Configuration
    uint256 public aiFee = 0.01 ether; // Standard fee
    uint256 public aiModelId = 11; // Default model
    uint64 public callbackGasLimit = 500_000; // Gas for callback

    /// @notice Initializes the contract
    constructor() OwnedThreeStep(msg.sender) { }

    /// @notice Set authorized caller
    function setAuthorizedCaller(address caller, bool authorized) external onlyOwner {
        require(caller != address(0), "Caller cannot be zero address");
        authorizedCallers[caller] = authorized;
        emit AuthorizedCallerUpdated(caller, authorized);
    }

    /// @notice Update model ID
    function updateModelId(uint256 newModelId) external onlyOwner {
        require(newModelId > 0, "Model ID must be greater than 0");
        aiModelId = newModelId;
        emit ModelIdUpdated(newModelId);
    }

    /// @notice Update fee
    function updateFee(uint256 newFee) external onlyOwner {
        require(newFee > 0, "Fee must be greater than 0");
        aiFee = newFee;
        emit FeeUpdated(newFee);
    }
}
