// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { AggregatorV3Interface } from "@chainlink/contracts/shared/interfaces/AggregatorV3Interface.sol";
import { IERC20 } from "@openzeppelin/token/ERC20/IERC20.sol";
import { ReentrancyGuard } from "@openzeppelin/utils/ReentrancyGuard.sol";
import { OwnedThreeStep } from "@solbase/auth/OwnedThreeStep.sol";
import { SafeERC20 } from "@openzeppelin/token/ERC20/utils/SafeERC20.sol";

import { IAIStablecoin } from "./interfaces/IAIStablecoin.sol";
import { IRiskOracleController } from "./interfaces/IRiskOracleController.sol";

/// @title CollateralVault - AI-Powered Collateral Management System
/// @notice Manages multi-token collateral deposits with AI-driven risk assessment and AIUSD minting
/// @dev Integrates with Chainlink + Amazon Bedrock AI for dynamic collateral ratio calculations
contract CollateralVault is OwnedThreeStep, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // =============================================================
    //                        CONSTANTS
    // =============================================================

    /// @notice Maximum basis points (100.00%)
    uint256 public constant MAX_BPS = 10_000;

    /// @notice Default emergency withdrawal delay (4 hours)
    uint256 public constant DEFAULT_EMERGENCY_DELAY = 4 hours;

    // =============================================================
    //                  CONFIGURATION & STORAGE
    // =============================================================

    /// @notice Core contract interfaces
    IAIStablecoin public aiusd;
    IRiskOracleController public riskOracleController;

    /// @notice Token configuration and pricing information
    /// @param priceUSD Current USD price with 18 decimal precision
    /// @param decimals Token decimal places for proper scaling
    /// @param supported Whether the token is currently accepted as collateral
    struct TokenInfo {
        uint256 priceUSD;
        uint8 decimals;
        bool supported;
    }

    /// @notice User collateral position tracking
    /// @param tokens Array of deposited token contract addresses
    /// @param amounts Corresponding deposit amounts for each token
    /// @param totalValueUSD Aggregate USD value of the collateral basket
    /// @param aiusdMinted Total AIUSD tokens minted against this position
    /// @param collateralRatio Current position ratio in basis points (10000 = 100%)
    /// @param requestId Active AI assessment request identifier
    /// @param hasPendingRequest Whether an AI evaluation is currently in progress
    /// @param timestamp Position creation timestamp for emergency withdrawal timing
    /// @param index Index of the deposit position
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

    /// @notice User collateral position storage by account address and position index
    /// @dev Maps each user to their deposit information for each position index
    mapping(address user => mapping(uint256 index => Position)) private positions;

    /// @notice Current position count for each user
    /// @dev Tracks the next available position index for each user
    mapping(address => uint256) public userPositionCount;

    /// @notice State mappings for token configuration and user positions
    /// @dev Maps token addresses to their configuration data for collateral acceptance
    mapping(address => TokenInfo) public supportedTokens;

    /// @notice Token symbol lookup for AI analysis and display purposes
    /// @dev Maps token contract addresses to their human-readable symbol strings for AI processing (e.g., "WETH",
    /// "USDC", "DAI")
    mapping(address => string) private tokenSymbols;

    /// @notice Optional price feed addresses for dynamic pricing
    /// @dev Maps token addresses to their Chainlink-compatible price feed contracts
    mapping(address => address) public tokenPriceFeeds;

    /// @notice Emergency withdrawal delay (configurable, default 4 hours)
    uint256 public emergencyWithdrawalDelay;

    /// @notice Authorized automation contracts for emergency withdrawals
    mapping(address => bool) public authorizedAutomation;

    /// @notice Token configuration for constructor initialization
    /// @param token Address of the ERC20 token contract
    /// @param priceUSD Initial USD price with 18 decimal precision
    /// @param decimals Token decimal places for proper scaling
    /// @param symbol Token symbol for AI analysis and display
    /// @param priceFeed Optional Chainlink price feed address (address(0) for static pricing)
    struct TokenConfig {
        address token;
        uint256 priceUSD;
        uint8 decimals;
        string symbol;
        address priceFeed;
    }

    // =============================================================
    //                    EVENTS & ERRORS
    // =============================================================

    /// @notice Core operation events
    event CollateralDeposited(address indexed user, address[] tokens, uint256[] amounts, uint256 totalValue);
    event AIRequestSubmitted(address indexed user, uint256 indexed requestId, uint256 collateralValue);
    event AIUSDMinted(address indexed user, uint256 amount, uint256 ratio, uint256 confidence);
    event CollateralWithdrawn(address indexed user, uint256 amount);
    event EmergencyWithdrawal(address indexed user, uint256 indexed requestId, uint256 timestamp);

    /// @notice Administrative events
    event TokenAdded(address indexed token, uint256 priceUSD, uint8 decimals);
    event TokenPriceUpdated(address indexed token, uint256 newPriceUSD);
    event ControllerUpdated(address indexed oldController, address indexed newController);
    event TokenPriceFeedUpdated(address indexed token, address indexed priceFeed);
    event EmergencyWithdrawalDelayUpdated(uint256 oldDelay, uint256 newDelay);
    event AutomationAuthorized(address indexed automation, bool authorized);

    /// @notice Validation errors
    error TokenNotSupported();
    error InsufficientAIUSD();
    error NoPosition();
    error PendingAIRequest();
    error ArrayLengthMismatch();
    error EmptyBasket();
    error ZeroValueBasket();
    error ZeroAmount();
    error InvalidPrice();
    error ZeroAddress();

    /// @notice Operation errors
    error TransferFailed();
    error NoPendingRequest();
    error RequestIdMismatch();

    /// @notice Access control errors
    error OnlyRiskOracleController();

    // =============================================================
    //                     ACCESS CONTROL
    // =============================================================

    /// @notice Restrict function access to the risk oracle controller
    modifier onlyRiskOracleController() {
        if (msg.sender != address(riskOracleController)) revert OnlyRiskOracleController();
        _;
    }

    /// @notice Restrict function access to authorized controllers or automation contracts
    modifier onlyAuthorizedEmergencyWithdraw() {
        if (msg.sender != address(riskOracleController) && !authorizedAutomation[msg.sender]) {
            revert OnlyRiskOracleController();
        }
        _;
    }

    /// @notice Ensure non-zero amounts for operations
    modifier nonZeroAmount(uint256 amount) {
        if (amount == 0) revert ZeroAmount();
        _;
    }

    // =============================================================
    //                  DEPLOYMENT & INITIALIZATION
    // =============================================================

    /// @notice Deploy and initialize the CollateralVault with optional automation and tokens
    /// @dev Sets up core contract dependencies, automation authorization, and initial token support
    /// @param _aiusd Address of the AIStablecoin token contract
    /// @param _riskOracleController Address of the AI risk assessment controller
    /// @param _automationContract Optional automation contract to authorize (address(0) to skip)
    /// @param _initialTokens Array of token configurations to add during deployment
    constructor(
        address _aiusd,
        address _riskOracleController,
        address _automationContract,
        TokenConfig[] memory _initialTokens
    ) OwnedThreeStep(msg.sender) {
        // Set core contract references
        aiusd = IAIStablecoin(_aiusd);
        riskOracleController = IRiskOracleController(_riskOracleController);
        emergencyWithdrawalDelay = DEFAULT_EMERGENCY_DELAY;

        // Authorize automation contract if provided
        if (_automationContract != address(0)) {
            authorizedAutomation[_automationContract] = true;
            emit AutomationAuthorized(_automationContract, true);
        }

        // Add initial tokens if provided
        for (uint256 i = 0; i < _initialTokens.length; i++) {
            TokenConfig memory config = _initialTokens[i];

            if (config.token == address(0)) continue; // Skip invalid tokens

            // Add token with initial configuration
            supportedTokens[config.token] =
                TokenInfo({ priceUSD: config.priceUSD, decimals: config.decimals, supported: true });

            tokenSymbols[config.token] = config.symbol;

            // Set price feed if provided
            if (config.priceFeed != address(0)) {
                tokenPriceFeeds[config.token] = config.priceFeed;
                emit TokenPriceFeedUpdated(config.token, config.priceFeed);
            }

            emit TokenAdded(config.token, config.priceUSD, config.decimals);
        }
    }

    /// @notice Accept ETH refunds from failed operations
    receive() external payable { }

    // =============================================================
    //                        CORE LOGIC
    // =============================================================

    /// @notice Deposit multi-token collateral basket and initiate AI risk assessment
    /// @dev Transfers tokens, calculates total value, and submits for AI evaluation
    /// @param tokens Array of ERC20 token addresses to deposit
    /// @param amounts Corresponding amounts for each token deposit
    function depositBasket(address[] calldata tokens, uint256[] calldata amounts) external payable {
        if (tokens.length != amounts.length) revert ArrayLengthMismatch();
        if (tokens.length == 0) revert EmptyBasket();
        if (positions[msg.sender][userPositionCount[msg.sender]].hasPendingRequest) revert PendingAIRequest();

        uint256 totalValueUSD = 0;

        // Transfer tokens and calculate aggregate USD value
        for (uint256 i = 0; i < tokens.length; i++) {
            TokenInfo memory tokenInfo = supportedTokens[tokens[i]];
            if (!tokenInfo.supported) revert TokenNotSupported();

            // Execute token transfer from user to vault
            bool success = IERC20(tokens[i]).transferFrom(msg.sender, address(this), amounts[i]);
            if (!success) revert TransferFailed();

            // Accumulate USD-denominated value
            uint256 tokenValueUSD = _calculateUSDValue(tokens[i], amounts[i]);
            totalValueUSD += tokenValueUSD;
        }

        if (totalValueUSD == 0) revert ZeroValueBasket();

        // Initialize user position with collateral data
        positions[msg.sender][userPositionCount[msg.sender]] = Position({
            tokens: tokens,
            amounts: amounts,
            totalValueUSD: totalValueUSD,
            aiusdMinted: 0,
            collateralRatio: 0,
            requestId: 0,
            hasPendingRequest: true,
            timestamp: block.timestamp,
            index: uint16(userPositionCount[msg.sender])
        });

        emit CollateralDeposited(msg.sender, tokens, amounts, totalValueUSD);

        // Prepare basket data for AI analysis
        bytes memory basketData = _encodeBasketData(tokens, amounts, totalValueUSD);

        // Submit for AI risk assessment via Chainlink Functions
        address originalUser = msg.sender;
        uint256 balanceBefore = address(this).balance - msg.value;

        uint256 requestId =
            riskOracleController.submitAIRequest{ value: msg.value }(msg.sender, basketData, totalValueUSD);

        // Associate request with user position
        positions[msg.sender][userPositionCount[msg.sender]].requestId = requestId;

        emit AIRequestSubmitted(msg.sender, requestId, totalValueUSD);

        // Handle potential ETH refunds (minimal with subscription model)
        uint256 balanceAfter = address(this).balance;
        if (balanceAfter > balanceBefore) {
            uint256 refundAmount = balanceAfter - balanceBefore;
            payable(originalUser).transfer(refundAmount);
        }

        // Update position count
        userPositionCount[msg.sender]++;
    }

    /// @notice Process completed AI assessment and mint AIUSD tokens
    /// @dev Called exclusively by RiskOracleController upon AI evaluation completion
    /// @param user Address of the collateral depositor
    /// @param requestId Identifier of the completed assessment request
    /// @param mintAmount Approved AIUSD tokens to mint based on AI analysis
    /// @param ratio Determined collateral ratio in basis points
    /// @param confidence AI model confidence score for the assessment
    function processAICallback(address user, uint256 requestId, uint256 mintAmount, uint256 ratio, uint256 confidence)
        external
        onlyRiskOracleController
    {
        // Find the position that matches this requestId
        uint256 positionIndex;
        bool found = false;
        uint256 totalPositions = userPositionCount[user];

        for (uint256 i = 0; i < totalPositions; i++) {
            if (positions[user][i].requestId == requestId && positions[user][i].hasPendingRequest) {
                positionIndex = i;
                found = true;
                break;
            }
        }

        if (!found) revert NoPendingRequest();

        // Get the position storage reference after finding it
        Position storage position = positions[user][positionIndex];

        // Finalize position with AI assessment results
        position.aiusdMinted = mintAmount;
        position.collateralRatio = ratio;
        position.hasPendingRequest = false;

        // Execute AIUSD token minting to user
        aiusd.mint(user, mintAmount);

        emit AIUSDMinted(user, mintAmount, ratio, confidence);
    }

    /// @notice Controller-initiated emergency withdrawal for stuck requests
    /// @dev Returns all collateral when AI processing fails or times out
    /// @param user Address of the user requiring emergency withdrawal
    /// @param requestId Identifier of the problematic request
    function emergencyWithdraw(address user, uint256 requestId) external onlyAuthorizedEmergencyWithdraw {
        // Find the position that matches this requestId
        uint256 positionIndex;
        bool found = false;
        uint256 totalPositions = userPositionCount[user];

        for (uint256 i = 0; i < totalPositions; i++) {
            if (positions[user][i].requestId == requestId && positions[user][i].hasPendingRequest) {
                positionIndex = i;
                found = true;
                break;
            }
        }

        if (!found) revert NoPendingRequest();

        Position storage position = positions[user][positionIndex];

        // Return all deposited collateral to user
        for (uint256 i = 0; i < position.tokens.length; i++) {
            IERC20(position.tokens[i]).transfer(user, position.amounts[i]);
        }

        // Clear user position completely
        delete positions[user][positionIndex];

        emit EmergencyWithdrawal(user, requestId, block.timestamp);
    }

    /// @notice User-initiated emergency withdrawal after timeout period (auto-find oldest stuck position)
    /// @dev Allows direct withdrawal when controller becomes unresponsive (4+ hours)
    /// @dev Automatically finds the oldest position with a stuck/pending request
    function userEmergencyWithdraw() external {
        uint256 targetIndex = _findOldestPendingPosition(msg.sender);

        // Check if this position is past the timeout
        Position storage position = positions[msg.sender][targetIndex];
        require(block.timestamp >= position.timestamp + emergencyWithdrawalDelay, "Must wait");

        _executeEmergencyWithdrawal(msg.sender, targetIndex);
    }

    /// @notice User-initiated emergency withdrawal for a specific position
    /// @dev Allows direct withdrawal when controller becomes unresponsive (4+ hours)
    /// @param positionIndex Index of the specific position to emergency withdraw from
    function userEmergencyWithdraw(uint256 positionIndex) external {
        Position storage position = positions[msg.sender][positionIndex];
        if (!position.hasPendingRequest) revert NoPendingRequest();
        if (position.timestamp == 0) revert NoPosition();

        // Enforce minimum waiting period for emergency access
        require(block.timestamp >= position.timestamp + emergencyWithdrawalDelay, "Must wait");

        _executeEmergencyWithdrawal(msg.sender, positionIndex);
    }

    /// @notice Internal function to execute emergency withdrawal logic
    /// @param user Address of the user
    /// @param positionIndex Index of the position to withdraw from
    function _executeEmergencyWithdrawal(address user, uint256 positionIndex) internal {
        Position storage position = positions[user][positionIndex];

        // Return all collateral directly to user
        for (uint256 i = 0; i < position.tokens.length; i++) {
            IERC20(position.tokens[i]).transfer(user, position.amounts[i]);
        }

        uint256 requestId = position.requestId;

        // Clear position and emit withdrawal event
        delete positions[user][positionIndex];

        emit EmergencyWithdrawal(user, requestId, block.timestamp);
    }

    /// @notice Find the oldest position with a pending request (regardless of timeout)
    /// @param user Address to search positions for
    /// @return positionIndex Index of the oldest pending position
    function _findOldestPendingPosition(address user) internal view returns (uint256 positionIndex) {
        uint256 totalPositions = userPositionCount[user];
        uint256 oldestTimestamp = type(uint256).max;
        uint256 targetIndex = type(uint256).max;

        // Find the oldest position that has a pending request
        for (uint256 i = 0; i < totalPositions; i++) {
            Position storage pos = positions[user][i];
            if (pos.hasPendingRequest && pos.timestamp > 0 && pos.timestamp < oldestTimestamp) {
                oldestTimestamp = pos.timestamp;
                targetIndex = i;
            }
        }

        if (targetIndex == type(uint256).max) {
            revert NoPendingRequest();
        }

        return targetIndex;
    }

    /// @notice Withdraw collateral from a specific position by burning equivalent AIUSD tokens
    /// @dev Burns user's AIUSD and returns proportional collateral amounts from the specified position
    /// @param positionIndex Index of the position to withdraw from
    /// @param amount AIUSD token amount to burn for collateral redemption
    function withdrawFromPosition(uint256 positionIndex, uint256 amount) external nonZeroAmount(amount) {
        Position storage position = positions[msg.sender][positionIndex];
        if (position.aiusdMinted == 0) revert NoPosition();
        if (position.hasPendingRequest) revert PendingAIRequest();
        if (amount > position.aiusdMinted) revert InsufficientAIUSD();

        // Calculate proportional withdrawal ratio
        uint256 withdrawalRatio = (amount * 1e18) / position.aiusdMinted;

        // Burn AIUSD tokens from user balance
        aiusd.burnFrom(msg.sender, amount);

        // Transfer proportional collateral back to user
        for (uint256 i = 0; i < position.tokens.length; i++) {
            uint256 withdrawAmount = (position.amounts[i] * withdrawalRatio) / 1e18;
            if (withdrawAmount > 0) {
                IERC20(position.tokens[i]).transfer(msg.sender, withdrawAmount);
                position.amounts[i] -= withdrawAmount;
            }
        }

        // Update position accounting
        position.aiusdMinted -= amount;
        position.totalValueUSD = (position.totalValueUSD * (1e18 - withdrawalRatio)) / 1e18;

        // Clear position if fully redeemed
        if (position.aiusdMinted == 0) {
            delete positions[msg.sender][position.index];
        }

        emit CollateralWithdrawn(msg.sender, amount);
    }

    // =============================================================
    //                     MANAGER LOGIC
    // =============================================================

    /// @notice Add a new supported collateral token with pricing
    /// @dev Only callable by contract owner for token whitelist management
    /// @param token ERC20 token contract address
    /// @param priceUSD Current USD price with 18 decimal precision
    /// @param decimals Token decimal places for value calculations
    /// @param symbol Human-readable token symbol for AI analysis
    function addToken(address token, uint256 priceUSD, uint8 decimals, string calldata symbol) external onlyOwner {
        if (token == address(0)) revert ZeroAddress();
        if (priceUSD == 0) revert InvalidPrice();

        supportedTokens[token] = TokenInfo({ priceUSD: priceUSD, decimals: decimals, supported: true });

        tokenSymbols[token] = symbol;
        emit TokenAdded(token, priceUSD, decimals);
    }

    /// @notice Update the USD price for a supported token
    /// @dev Maintains current pricing for accurate collateral valuations
    /// @param token Address of the token to update
    /// @param newPriceUSD Updated price in USD with 18 decimal places
    function updateTokenPrice(address token, uint256 newPriceUSD) external onlyOwner {
        if (!supportedTokens[token].supported) revert TokenNotSupported();
        if (newPriceUSD == 0) revert InvalidPrice();

        supportedTokens[token].priceUSD = newPriceUSD;
        emit TokenPriceUpdated(token, newPriceUSD);
    }

    /// @notice Update the risk oracle controller contract address
    /// @dev Allows upgrading AI assessment backend while preserving user positions
    /// @param newController Address of the replacement RiskOracleController
    function updateController(address newController) external onlyOwner {
        if (newController == address(0)) revert ZeroAddress();
        address oldController = address(riskOracleController);
        riskOracleController = IRiskOracleController(newController);
        emit ControllerUpdated(oldController, newController);
    }

    /// @notice Set price feed for a token to enable dynamic pricing
    /// @dev Allows using external price oracles instead of static vault prices
    /// @param token Address of the token to set price feed for
    /// @param priceFeed Address of the Chainlink-compatible price feed (0 to disable)
    function setTokenPriceFeed(address token, address priceFeed) external onlyOwner {
        if (!supportedTokens[token].supported) revert TokenNotSupported();

        tokenPriceFeeds[token] = priceFeed;
        emit TokenPriceFeedUpdated(token, priceFeed);
    }

    /// @notice Update the emergency withdrawal delay
    /// @dev Allows changing the delay for emergency withdrawals
    /// @param newDelay New delay in seconds
    function updateEmergencyWithdrawalDelay(uint256 newDelay) external onlyOwner {
        uint256 oldDelay = emergencyWithdrawalDelay;
        emergencyWithdrawalDelay = newDelay;
        emit EmergencyWithdrawalDelayUpdated(oldDelay, newDelay);
    }

    /// @notice Authorize automation contract for emergency withdrawals
    /// @dev Allows automation contracts to call emergencyWithdraw on behalf of users
    /// @param automation Address of the automation contract
    /// @param authorized Whether the automation should be authorized
    function setAutomationAuthorized(address automation, bool authorized) external onlyOwner {
        if (automation == address(0)) revert ZeroAddress();
        authorizedAutomation[automation] = authorized;
        emit AutomationAuthorized(automation, authorized);
    }

    // =============================================================
    //                  EXTERNAL VIEW FUNCTIONS
    // =============================================================

    /// @notice Retrieve complete user position information
    /// @param user Address to query position data for
    /// @return tokens Array of deposited token addresses
    /// @return amounts Corresponding token amounts in position
    /// @return totalValueUSD Aggregate USD value of collateral
    /// @return aiusdMinted Total AIUSD tokens minted against position
    /// @return collateralRatio Current position ratio in basis points
    /// @return requestId Active or last AI request identifier
    /// @return hasPendingRequest Whether AI assessment is in progress
    function getPosition(address user)
        external
        view
        returns (
            address[] memory tokens,
            uint256[] memory amounts,
            uint256 totalValueUSD,
            uint256 aiusdMinted,
            uint256 collateralRatio,
            uint256 requestId,
            bool hasPendingRequest
        )
    {
        Position memory position = positions[user][userPositionCount[user] - 1];
        return (
            position.tokens,
            position.amounts,
            position.totalValueUSD,
            position.aiusdMinted,
            position.collateralRatio,
            position.requestId,
            position.hasPendingRequest
        );
    }

    /// @notice Check emergency withdrawal eligibility and timing for all positions
    /// @param user Address to evaluate for emergency withdrawal access
    /// @return canWithdraw Whether immediate emergency withdrawal is permitted for any position
    /// @return timeRemaining Seconds until the oldest pending position becomes available (0 if any position is ready)
    function canEmergencyWithdraw(address user) external view returns (bool canWithdraw, uint256 timeRemaining) {
        uint256 totalPositions = userPositionCount[user];
        uint256 shortestTimeRemaining = type(uint256).max;
        bool hasEligiblePosition = false;
        bool hasPendingPosition = false;

        // Check all positions for emergency withdrawal eligibility
        for (uint256 i = 0; i < totalPositions; i++) {
            Position storage position = positions[user][i];

            if (position.hasPendingRequest && position.timestamp > 0) {
                hasPendingPosition = true;
                uint256 timeElapsed = block.timestamp - position.timestamp;

                if (timeElapsed >= emergencyWithdrawalDelay) {
                    // At least one position is ready for emergency withdrawal
                    return (true, 0);
                } else {
                    uint256 remaining = emergencyWithdrawalDelay - timeElapsed;
                    if (remaining < shortestTimeRemaining) {
                        shortestTimeRemaining = remaining;
                    }
                }
            }
        }

        if (!hasPendingPosition) {
            return (false, 0);
        }

        return (false, shortestTimeRemaining);
    }

    /// @notice Check emergency withdrawal eligibility and timing for a specific position
    /// @param user Address to evaluate for emergency withdrawal access
    /// @param positionIndex Index of the specific position to check
    /// @return canWithdraw Whether immediate emergency withdrawal is permitted for this position
    /// @return timeRemaining Seconds until this position becomes available for emergency withdrawal (0 if ready)
    function canEmergencyWithdraw(address user, uint256 positionIndex)
        external
        view
        returns (bool canWithdraw, uint256 timeRemaining)
    {
        if (positionIndex >= userPositionCount[user]) {
            return (false, 0); // Position doesn't exist
        }

        Position storage position = positions[user][positionIndex];

        if (!position.hasPendingRequest || position.timestamp == 0) {
            return (false, 0); // No pending request or invalid position
        }

        uint256 timeElapsed = block.timestamp - position.timestamp;

        if (timeElapsed >= emergencyWithdrawalDelay) {
            return (true, 0); // Ready for emergency withdrawal
        } else {
            return (false, emergencyWithdrawalDelay - timeElapsed); // Still waiting
        }
    }

    /// @notice Get comprehensive position status for monitoring and support
    /// @param user Address to analyze position status for
    /// @return hasPosition Whether the user maintains an active position
    /// @return isPending Whether an AI assessment request is currently pending
    /// @return requestId The active or most recent request identifier
    /// @return timeElapsed Seconds since the position was created
    function getPositionStatus(address user)
        external
        view
        returns (bool hasPosition, bool isPending, uint256 requestId, uint256 timeElapsed)
    {
        Position memory position = positions[user][userPositionCount[user] - 1];

        hasPosition = position.timestamp > 0;
        isPending = position.hasPendingRequest;
        requestId = position.requestId;
        timeElapsed = hasPosition ? block.timestamp - position.timestamp : 0;
    }

    /// @notice Get specific user deposit information by index
    /// @param _user Address of the user to query
    /// @param _index Index of the position to retrieve
    /// @return position The Position struct containing all deposit information
    function getUserDepositInfo(address _user, uint256 _index) external view returns (Position memory position) {
        return positions[_user][_index];
    }

    /// @notice Retrieves all active deposit positions for the caller
    /// @dev Iterates over all positions made by the caller and returns a memory array of active Position structs
    /// @return activePositions Array of Position structs with non-zero AIUSD minted amounts
    function getDepositPositions() external view returns (Position[] memory activePositions) {
        uint256 totalPositions = userPositionCount[msg.sender];

        // First pass: count active positions
        uint256 activeCount = 0;
        for (uint256 i = 0; i < totalPositions; i++) {
            if (positions[msg.sender][i].timestamp > 0) {
                activeCount++;
            }
        }

        // Second pass: populate active positions array
        activePositions = new Position[](activeCount);
        uint256 currentIndex = 0;

        for (uint256 i = 0; i < totalPositions; i++) {
            Position memory position = positions[msg.sender][i];
            if (position.timestamp > 0) {
                activePositions[currentIndex] = position;
                currentIndex++;
            }
        }

        return activePositions;
    }

    /// @notice Get summary of all user positions
    /// @param user Address to analyze
    /// @return totalPositions Total number of positions created
    /// @return activePositions Number of positions with remaining collateral
    /// @return totalValueUSD Combined USD value across all active positions
    /// @return totalAIUSDMinted Total AIUSD minted across all positions
    function getPositionSummary(address user)
        external
        view
        returns (uint256 totalPositions, uint256 activePositions, uint256 totalValueUSD, uint256 totalAIUSDMinted)
    {
        totalPositions = userPositionCount[user];

        for (uint256 i = 0; i < totalPositions; i++) {
            Position memory position = positions[user][i];
            if (position.timestamp > 0) {
                activePositions++;
                totalValueUSD += position.totalValueUSD;
                totalAIUSDMinted += position.aiusdMinted;
            }
        }

        return (totalPositions, activePositions, totalValueUSD, totalAIUSDMinted);
    }

    /// @notice Get all positions eligible for emergency withdrawal
    /// @param user Address to check positions for
    /// @return eligibleIndices Array of position indices that can be emergency withdrawn
    /// @return timeRemaining Array of seconds remaining before each position becomes eligible (0 if already eligible)
    function getEmergencyWithdrawablePositions(address user)
        external
        view
        returns (uint256[] memory eligibleIndices, uint256[] memory timeRemaining)
    {
        uint256 totalPositions = userPositionCount[user];
        uint256[] memory tempIndices = new uint256[](totalPositions);
        uint256[] memory tempTimeRemaining = new uint256[](totalPositions);
        uint256 eligibleCount = 0;

        // Find all positions with pending requests
        for (uint256 i = 0; i < totalPositions; i++) {
            Position storage pos = positions[user][i];
            if (pos.hasPendingRequest && pos.timestamp > 0) {
                tempIndices[eligibleCount] = i;

                uint256 timeElapsed = block.timestamp - pos.timestamp;
                if (timeElapsed >= emergencyWithdrawalDelay) {
                    tempTimeRemaining[eligibleCount] = 0; // Already eligible
                } else {
                    tempTimeRemaining[eligibleCount] = emergencyWithdrawalDelay - timeElapsed;
                }
                eligibleCount++;
            }
        }

        // Resize arrays to actual count
        eligibleIndices = new uint256[](eligibleCount);
        timeRemaining = new uint256[](eligibleCount);

        for (uint256 i = 0; i < eligibleCount; i++) {
            eligibleIndices[i] = tempIndices[i];
            timeRemaining[i] = tempTimeRemaining[i];
        }

        return (eligibleIndices, timeRemaining);
    }

    // =============================================================
    //                INTERNAL/PRIVATE VIEW FUNCTIONS
    // =============================================================

    /// @notice Calculate USD value for a token amount using stored pricing
    /// @param token Address of the token to value
    /// @param amount Raw token amount to convert
    /// @return USD value with 18 decimal precision
    function _calculateUSDValue(address token, uint256 amount) internal view returns (uint256) {
        TokenInfo memory tokenInfo = supportedTokens[token];

        // Check if token has a price feed configured
        address priceFeed = tokenPriceFeeds[token];
        if (priceFeed != address(0)) {
            // Use dynamic pricing from price feed
            try AggregatorV3Interface(priceFeed).latestRoundData() returns (
                uint80, /* roundId */
                int256 price,
                uint256, /* startedAt */
                uint256 updatedAt,
                uint80 /* answeredInRound */
            ) {
                // Validate price data
                if (price > 0 && block.timestamp - updatedAt <= 3600) {
                    // 1 hour staleness check
                    // Convert from 8 decimals to 18 decimals and calculate USD value
                    uint256 priceUSD = uint256(price) * 1e10; // 8 decimals -> 18 decimals
                    return (amount * priceUSD) / (10 ** tokenInfo.decimals);
                }
            } catch {
                // Price feed failed, fall back to static price
            }
        }

        // Use static vault price as fallback
        return (amount * tokenInfo.priceUSD) / (10 ** tokenInfo.decimals);
    }

    /// @notice Encode collateral basket data for AI analysis
    /// @param tokens Array of token addresses in the basket
    /// @param amounts Corresponding token amounts
    /// @param totalValue Aggregate USD value (unused but kept for interface compatibility)
    /// @return Formatted basket data as bytes for AI processing
    function _encodeBasketData(address[] memory tokens, uint256[] memory amounts, uint256 totalValue)
        internal
        view
        returns (bytes memory)
    {
        string memory data = "";
        for (uint256 i = 0; i < tokens.length; i++) {
            string memory symbol = tokenSymbols[tokens[i]];
            if (bytes(symbol).length == 0) symbol = "UNKNOWN";

            data = string(abi.encodePacked(data, symbol, ":", _uint2str(amounts[i]), i < tokens.length - 1 ? "," : ""));
        }
        return bytes(data);
    }

    /// @notice Convert unsigned integer to decimal string representation
    /// @param _i Integer value to convert
    /// @return String representation of the integer
    function _uint2str(uint256 _i) internal pure returns (string memory) {
        if (_i == 0) return "0";

        uint256 j = _i;
        uint256 len;
        while (j != 0) {
            len++;
            j /= 10;
        }

        bytes memory bstr = new bytes(len);
        uint256 k = len;
        while (_i != 0) {
            k = k - 1;
            uint8 temp = (48 + uint8(_i - _i / 10 * 10));
            bytes1 b1 = bytes1(temp);
            bstr[k] = b1;
            _i /= 10;
        }
        return string(bstr);
    }
}
