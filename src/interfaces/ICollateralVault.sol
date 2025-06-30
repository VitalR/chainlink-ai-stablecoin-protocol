// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { IRiskOracleController } from "./IRiskOracleController.sol";

/// @title ICollateralVault - Interface for CollateralVault contract
/// @notice Interface for external contracts to interact with the CollateralVault
interface ICollateralVault {
    /// @notice User collateral position tracking struct
    struct Position {
        address[] tokens;
        uint256[] amounts;
        uint256 totalValueUSD;
        uint256 aiusdMinted;
        uint256 collateralRatio;
        uint256 requestId;
        bool hasPendingRequest;
        uint256 timestamp;
        uint16 index;
    }

    // =============================================================
    //                        CORE FUNCTIONS
    // =============================================================

    /// @notice Deposit multi-token collateral basket and initiate AI risk assessment
    /// @dev Transfers tokens, calculates total value, and submits for AI evaluation
    /// @param tokens Array of ERC20 token addresses to deposit
    /// @param amounts Corresponding amounts for each token deposit
    function depositBasket(address[] calldata tokens, uint256[] calldata amounts) external payable;

    /// @notice Deposit multi-token collateral basket with specific AI engine selection
    /// @dev Transfers tokens, calculates total value, and submits for AI evaluation with chosen engine
    /// @param tokens Array of ERC20 token addresses to deposit
    /// @param amounts Corresponding amounts for each token deposit
    /// @param engine AI engine to use (ALGO, BEDROCK, or TEST_TIMEOUT for testing)
    function depositBasket(address[] calldata tokens, uint256[] calldata amounts, IRiskOracleController.Engine engine)
        external
        payable;

    /// @notice Withdraw collateral from a specific position by burning equivalent AIUSD tokens
    function withdrawFromPosition(uint256 positionIndex, uint256 amount) external;

    /// @notice Controller-initiated emergency withdrawal for stuck requests
    function emergencyWithdraw(address user, uint256 requestId) external;

    /// @notice User-initiated emergency withdrawal after timeout period (auto-find oldest stuck position)
    function userEmergencyWithdraw() external;

    /// @notice User-initiated emergency withdrawal for a specific position
    function userEmergencyWithdraw(uint256 positionIndex) external;

    // =============================================================
    //                        VIEW FUNCTIONS
    // =============================================================

    /// @notice Get specific user deposit information by index
    function getUserDepositInfo(address _user, uint256 _index) external view returns (Position memory position);

    /// @notice Retrieves all active deposit positions for the caller
    function getDepositPositions() external view returns (Position[] memory activePositions);

    /// @notice Get summary of all user positions
    function getPositionSummary(address user)
        external
        view
        returns (uint256 totalPositions, uint256 activePositions, uint256 totalValueUSD, uint256 totalAIUSDMinted);

    /// @notice Get all positions eligible for emergency withdrawal
    function getEmergencyWithdrawablePositions(address user)
        external
        view
        returns (uint256[] memory eligibleIndices, uint256[] memory timeRemaining);

    /// @notice Check emergency withdrawal eligibility and timing for all positions
    function canEmergencyWithdraw(address user) external view returns (bool canWithdraw, uint256 timeRemaining);

    /// @notice Check emergency withdrawal eligibility and timing for a specific position
    function canEmergencyWithdraw(address user, uint256 positionIndex)
        external
        view
        returns (bool canWithdraw, uint256 timeRemaining);

    /// @notice Get comprehensive position status for monitoring and support
    function getPositionStatus(address user)
        external
        view
        returns (bool hasPosition, bool isPending, uint256 requestId, uint256 timeElapsed);

    /// @notice Current position count for each user
    function userPositionCount(address user) external view returns (uint256);

    /// @notice Emergency withdrawal delay (configurable, default 4 hours)
    function emergencyWithdrawalDelay() external view returns (uint256);

    // =============================================================
    //                        EVENTS
    // =============================================================

    event CollateralDeposited(address indexed user, address[] tokens, uint256[] amounts, uint256 totalValue);
    event AIRequestSubmitted(address indexed user, uint256 indexed requestId, uint256 collateralValue);
    event AIUSDMinted(address indexed user, uint256 amount, uint256 ratio, uint256 confidence);
    event CollateralWithdrawn(address indexed user, uint256 amount);
    event EmergencyWithdrawal(address indexed user, uint256 indexed requestId, uint256 timestamp);
}
