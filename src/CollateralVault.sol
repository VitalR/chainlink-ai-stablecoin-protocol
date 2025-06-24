// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { AggregatorV3Interface } from "@chainlink/contracts/shared/interfaces/AggregatorV3Interface.sol";
import { IERC20 } from "@openzeppelin/token/ERC20/IERC20.sol";
import { ReentrancyGuard } from "@openzeppelin/utils/ReentrancyGuard.sol";
import { OwnedThreeStep } from "@solbase/auth/OwnedThreeStep.sol";
import { SafeERC20 } from "@openzeppelin/token/ERC20/SafeERC20.sol";

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
    struct Position {
        address[] tokens;
        uint256[] amounts;
        uint256 totalValueUSD;
        uint256 aiusdMinted;
        uint256 collateralRatio;
        uint256 requestId;
        bool hasPendingRequest;
        uint256 timestamp;
    }

    /// @notice State mappings for token configuration and user positions
    /// @dev Maps token addresses to their configuration data for collateral acceptance
    mapping(address => TokenInfo) public supportedTokens;

    /// @notice User collateral position storage by account address
    /// @dev Maps user addresses to their complete collateral position data including tokens, amounts, and AI assessment
    /// results
    mapping(address => Position) public positions;

    /// @notice Token symbol lookup for AI analysis and display purposes
    /// @dev Maps token contract addresses to their human-readable symbol strings for AI processing (e.g., "WETH",
    /// "USDC", "DAI")
    mapping(address => string) private tokenSymbols;

    /// @notice Optional price feed addresses for dynamic pricing
    /// @dev Maps token addresses to their Chainlink-compatible price feed contracts
    mapping(address => address) public tokenPriceFeeds;

    /// @notice Emergency withdrawal delay (configurable, default 4 hours)
    uint256 public emergencyWithdrawalDelay;

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

    /// @notice Emitted when tokens are successfully deposited for collateralization
    event CollateralDeposited(address indexed user, address indexed token, uint256 amount, uint256 requestId);

    /// @notice Emitted when AIUSD tokens are burned for collateral withdrawal
    event CollateralWithdrawn(address indexed user, uint256 aiusdBurned, uint256 requestId);

    /// @notice Emitted when emergency withdrawal occurs for pending requests
    event EmergencyWithdrawal(address indexed user, uint256 requestId, uint256 timestamp);

    /// @notice Emitted when a token price feed is updated
    event TokenPriceFeedUpdated(address indexed token, address indexed priceFeed);

    /// @notice Emitted when emergency withdrawal delay is updated
    event EmergencyWithdrawalDelayUpdated(uint256 oldDelay, uint256 newDelay);

    // =============================================================
    //                     ACCESS CONTROL
    // =============================================================

    /// @notice Restrict function access to the risk oracle controller
    modifier onlyRiskOracleController() {
        if (msg.sender != address(riskOracleController)) revert OnlyRiskOracleController();
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

    /// @notice Deploy and initialize the CollateralVault
    /// @dev Sets up core contract dependencies and ownership
    /// @param _aiusd Address of the AIStablecoin token contract
    /// @param _riskOracleController Address of the AI risk assessment controller
    constructor(address _aiusd, address _riskOracleController) OwnedThreeStep(msg.sender) {
        aiusd = IAIStablecoin(_aiusd);
        riskOracleController = IRiskOracleController(_riskOracleController);
        emergencyWithdrawalDelay = DEFAULT_EMERGENCY_DELAY;
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
        if (positions[msg.sender].hasPendingRequest) revert PendingAIRequest();

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
        positions[msg.sender] = Position({
            tokens: tokens,
            amounts: amounts,
            totalValueUSD: totalValueUSD,
            aiusdMinted: 0,
            collateralRatio: 0,
            requestId: 0,
            hasPendingRequest: true,
            timestamp: block.timestamp
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
        positions[msg.sender].requestId = requestId;

        emit AIRequestSubmitted(msg.sender, requestId, totalValueUSD);

        // Handle potential ETH refunds (minimal with subscription model)
        uint256 balanceAfter = address(this).balance;
        if (balanceAfter > balanceBefore) {
            uint256 refundAmount = balanceAfter - balanceBefore;
            payable(originalUser).transfer(refundAmount);
        }
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
        Position storage position = positions[user];
        if (!position.hasPendingRequest) revert NoPendingRequest();
        if (position.requestId != requestId) revert RequestIdMismatch();

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
    function emergencyWithdraw(address user, uint256 requestId) external onlyRiskOracleController {
        Position storage position = positions[user];
        if (!position.hasPendingRequest) revert NoPendingRequest();
        if (position.requestId != requestId) revert RequestIdMismatch();

        // Return all deposited collateral to user
        for (uint256 i = 0; i < position.tokens.length; i++) {
            IERC20(position.tokens[i]).transfer(user, position.amounts[i]);
        }

        // Clear user position completely
        delete positions[user];

        emit EmergencyWithdrawal(user, requestId, block.timestamp);
    }

    /// @notice User-initiated emergency withdrawal after timeout period
    /// @dev Allows direct withdrawal when controller becomes unresponsive (4+ hours)
    function userEmergencyWithdraw() external {
        Position storage position = positions[msg.sender];
        if (!position.hasPendingRequest) revert NoPendingRequest();

        // Enforce minimum waiting period for emergency access
        require(block.timestamp >= position.timestamp + emergencyWithdrawalDelay, "Must wait");

        // Return all collateral directly to user
        for (uint256 i = 0; i < position.tokens.length; i++) {
            IERC20(position.tokens[i]).transfer(msg.sender, position.amounts[i]);
        }

        uint256 requestId = position.requestId;

        // Clear position and emit withdrawal event
        delete positions[msg.sender];

        emit EmergencyWithdrawal(msg.sender, requestId, block.timestamp);
    }

    /// @notice Withdraw collateral by burning equivalent AIUSD tokens
    /// @dev Burns user's AIUSD and returns proportional collateral amounts
    /// @param amount AIUSD token amount to burn for collateral redemption
    function withdrawCollateral(uint256 amount) external nonZeroAmount(amount) {
        Position storage position = positions[msg.sender];
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
            delete positions[msg.sender];
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
        Position memory position = positions[user];
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

    /// @notice Check emergency withdrawal eligibility and timing
    /// @param user Address to evaluate for emergency withdrawal access
    /// @return canWithdraw Whether immediate emergency withdrawal is permitted
    /// @return timeRemaining Seconds until emergency withdrawal becomes available
    function canEmergencyWithdraw(address user) external view returns (bool canWithdraw, uint256 timeRemaining) {
        Position memory position = positions[user];

        if (!position.hasPendingRequest) {
            return (false, 0);
        }

        uint256 timeElapsed = block.timestamp - position.timestamp;
        uint256 requiredTime = emergencyWithdrawalDelay;

        if (timeElapsed >= requiredTime) {
            return (true, 0);
        } else {
            return (false, requiredTime - timeElapsed);
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
        Position memory position = positions[user];

        hasPosition = position.timestamp > 0;
        isPending = position.hasPendingRequest;
        requestId = position.requestId;
        timeElapsed = hasPosition ? block.timestamp - position.timestamp : 0;
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
                if (price > 0 && block.timestamp - updatedAt <= 3600) { // 1 hour staleness check
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
