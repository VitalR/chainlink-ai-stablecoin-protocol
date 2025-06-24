// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { AutomationCompatibleInterface } from "@chainlink/contracts/automation/AutomationCompatible.sol";
import { OwnedThreeStep } from "@solbase/auth/OwnedThreeStep.sol";
import { ICollateralVault } from "../interfaces/ICollateralVault.sol";

/// @title AutoEmergencyWithdrawal - Chainlink Automation for Emergency Withdrawals
/// @notice Monitors user positions and automatically triggers emergency withdrawals after timeout
/// @dev Uses round-robin checking to distribute gas costs across multiple upkeep executions
contract AutoEmergencyWithdrawal is AutomationCompatibleInterface, OwnedThreeStep {
    // =============================================================
    //                        CONSTANTS
    // =============================================================

    /// @notice Maximum positions to process per upkeep execution
    /// @dev Prevents gas limit issues by batching operations
    uint256 public constant MAX_POSITIONS_PER_UPKEEP = 10;

    // =============================================================
    //                   STATE VARIABLES
    // =============================================================

    /// @notice CollateralVault contract to monitor
    ICollateralVault public vault;

    /// @notice Whether the automation is enabled
    bool public automationEnabled;

    /// @notice Users who have opted into automatic emergency withdrawal
    mapping(address => bool) public userOptedIn;

    /// @notice List of users for iteration
    address[] public users;

    /// @notice Mapping to track user existence in array
    mapping(address => bool) public userExists;

    /// @notice Starting index for round-robin checking
    uint256 public checkStartIndex;

    // =============================================================
    //                        EVENTS
    // =============================================================

    event AutomationEnabled(bool enabled);
    event UserOptedIn(address indexed user);
    event UserOptedOut(address indexed user);
    event EmergencyWithdrawalTriggered(address indexed user, uint256 positionIndex, uint256 requestId);
    event BatchProcessingCompleted(uint256 usersChecked, uint256 withdrawalsTriggered);
    event VaultUpdated(address indexed oldVault, address indexed newVault);

    // =============================================================
    //                        ERRORS
    // =============================================================

    error AutomationDisabled();
    error UserNotOptedIn();
    error InvalidPosition();
    error ZeroAddress();
    error VaultNotSet();

    // =============================================================
    //                    CONSTRUCTOR
    // =============================================================

    constructor(address _vault) OwnedThreeStep(msg.sender) {
        if (_vault != address(0)) {
            vault = ICollateralVault(_vault);
        }
        automationEnabled = true;
    }

    // =============================================================
    //                   ADMIN FUNCTIONS
    // =============================================================

    /// @notice Set or update the vault contract address
    /// @dev Only owner can call this function
    /// @param _vault Address of the CollateralVault contract
    function setVault(address _vault) external onlyOwner {
        if (_vault == address(0)) revert ZeroAddress();

        address oldVault = address(vault);
        vault = ICollateralVault(_vault);

        emit VaultUpdated(oldVault, _vault);
    }

    /// @notice Enable or disable the automation
    /// @dev Only owner can call this function
    /// @param enabled Whether automation should be active
    function setAutomationEnabled(bool enabled) external onlyOwner {
        automationEnabled = enabled;
        emit AutomationEnabled(enabled);
    }

    /// @notice Emergency function to trigger withdrawal for a specific user
    /// @dev Only owner can call this in emergency situations
    /// @param user User to withdraw for
    /// @param requestId Request ID to withdraw
    function adminEmergencyWithdraw(address user, uint256 requestId) external onlyOwner {
        if (address(vault) == address(0)) revert VaultNotSet();
        vault.emergencyWithdraw(user, requestId);
    }

    // =============================================================
    //                   CHAINLINK AUTOMATION
    // =============================================================

    /// @notice Chainlink Automation checkUpkeep function
    /// @dev Checks if any users have positions eligible for emergency withdrawal
    /// @param checkData Unused for this implementation
    /// @return upkeepNeeded Whether automation should trigger performUpkeep
    /// @return performData Encoded data for positions to process
    function checkUpkeep(bytes calldata checkData)
        external
        view
        override
        returns (bool upkeepNeeded, bytes memory performData)
    {
        if (!automationEnabled || address(vault) == address(0)) {
            return (false, "");
        }

        // Check a subset of users starting from checkStartIndex
        uint256 totalUsers = users.length;
        if (totalUsers == 0) {
            return (false, "");
        }

        address[] memory eligibleUsers = new address[](MAX_POSITIONS_PER_UPKEEP);
        uint256[] memory eligiblePositions = new uint256[](MAX_POSITIONS_PER_UPKEEP);
        uint256 eligibleCount = 0;
        uint256 usersChecked = 0;
        uint256 startIndex = checkStartIndex;

        // Round-robin check users to distribute gas cost across multiple blocks
        for (uint256 i = 0; i < totalUsers && usersChecked < MAX_POSITIONS_PER_UPKEEP; i++) {
            uint256 userIndex = (startIndex + i) % totalUsers;
            address user = users[userIndex];

            if (!userOptedIn[user]) {
                usersChecked++;
                continue;
            }

            // Check if user has positions eligible for emergency withdrawal
            (uint256[] memory indices, uint256[] memory timeRemaining) = vault.getEmergencyWithdrawablePositions(user);

            for (uint256 j = 0; j < indices.length && eligibleCount < MAX_POSITIONS_PER_UPKEEP; j++) {
                if (timeRemaining[j] == 0) {
                    // Position is ready for emergency withdrawal
                    eligibleUsers[eligibleCount] = user;
                    eligiblePositions[eligibleCount] = indices[j];
                    eligibleCount++;
                }
            }

            usersChecked++;

            // Break if we have enough positions to process
            if (eligibleCount >= MAX_POSITIONS_PER_UPKEEP) {
                break;
            }
        }

        if (eligibleCount > 0) {
            // Build result arrays
            address[] memory resultUsers = new address[](eligibleCount);
            uint256[] memory resultPositions = new uint256[](eligibleCount);

            for (uint256 i = 0; i < eligibleCount; i++) {
                resultUsers[i] = eligibleUsers[i];
                resultPositions[i] = eligiblePositions[i];
            }

            return (true, abi.encode(resultUsers, resultPositions, startIndex + usersChecked));
        }

        return (false, "");
    }

    /// @notice Chainlink Automation performUpkeep function
    /// @dev Executes emergency withdrawals for eligible positions
    /// @param performData Encoded data containing users and positions to process
    function performUpkeep(bytes calldata performData) external override {
        if (!automationEnabled) revert AutomationDisabled();
        if (address(vault) == address(0)) revert VaultNotSet();

        (address[] memory eligibleUsers, uint256[] memory eligiblePositions, uint256 newStartIndex) =
            abi.decode(performData, (address[], uint256[], uint256));

        uint256 withdrawalsTriggered = 0;

        for (uint256 i = 0; i < eligibleUsers.length; i++) {
            address user = eligibleUsers[i];
            uint256 positionIndex = eligiblePositions[i];

            // Double-check user opted in and position is valid
            if (!userOptedIn[user]) continue;

            // Verify position is still eligible (avoid race conditions)
            (bool canWithdraw,) = vault.canEmergencyWithdraw(user, positionIndex);
            if (!canWithdraw) continue;

            try vault.emergencyWithdraw(user, vault.getUserDepositInfo(user, positionIndex).requestId) {
                withdrawalsTriggered++;
                emit EmergencyWithdrawalTriggered(
                    user, positionIndex, vault.getUserDepositInfo(user, positionIndex).requestId
                );
            } catch {
                // Log failed withdrawal but continue processing others
                continue;
            }
        }

        // Update starting index for next round - ensure it advances at least by 1
        if (users.length > 0) {
            uint256 nextIndex = newStartIndex % users.length;
            // If we wrapped back to the same starting position, advance by 1
            checkStartIndex = (nextIndex == checkStartIndex) ? (checkStartIndex + 1) % users.length : nextIndex;
        }

        emit BatchProcessingCompleted(eligibleUsers.length, withdrawalsTriggered);
    }

    // =============================================================
    //                    USER MANAGEMENT
    // =============================================================

    /// @notice Opt into automatic emergency withdrawal service
    /// @dev Users must explicitly opt in to automation
    function optInToAutomation() external {
        if (!userOptedIn[msg.sender]) {
            userOptedIn[msg.sender] = true;

            if (!userExists[msg.sender]) {
                users.push(msg.sender);
                userExists[msg.sender] = true;
            }

            emit UserOptedIn(msg.sender);
        }
    }

    /// @notice Opt out of automatic emergency withdrawal service
    function optOutOfAutomation() external {
        userOptedIn[msg.sender] = false;
        emit UserOptedOut(msg.sender);
    }

    /// @notice Check if user has opted into automation
    function isUserOptedIn(address user) external view returns (bool) {
        return userOptedIn[user];
    }

    /// @notice Get total number of users in the system
    function getTotalUsers() external view returns (uint256) {
        return users.length;
    }

    /// @notice Get list of all opted-in users
    function getOptedInUsers() external view returns (address[] memory) {
        uint256 optedInCount = 0;

        // Count opted-in users
        for (uint256 i = 0; i < users.length; i++) {
            if (userOptedIn[users[i]]) {
                optedInCount++;
            }
        }

        // Build result array
        address[] memory optedInUsers = new address[](optedInCount);
        uint256 index = 0;

        for (uint256 i = 0; i < users.length; i++) {
            if (userOptedIn[users[i]]) {
                optedInUsers[index] = users[i];
                index++;
            }
        }

        return optedInUsers;
    }

    // =============================================================
    //                      VIEW FUNCTIONS
    // =============================================================

    /// @notice Get current automation configuration
    function getAutomationInfo()
        external
        view
        returns (
            address vaultAddress,
            bool enabled,
            uint256 totalUsers,
            uint256 optedInUsers,
            uint256 currentStartIndex
        )
    {
        uint256 optedIn = 0;
        for (uint256 i = 0; i < users.length; i++) {
            if (userOptedIn[users[i]]) {
                optedIn++;
            }
        }

        return (address(vault), automationEnabled, users.length, optedIn, checkStartIndex);
    }
}
