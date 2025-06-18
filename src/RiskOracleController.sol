// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { AggregatorV3Interface } from "@chainlink/contracts/shared/interfaces/AggregatorV3Interface.sol";
import { FunctionsClient } from "@chainlink/functions/v1_3_0/FunctionsClient.sol";
import { FunctionsRequest } from "@chainlink/functions/v1_0_0/libraries/FunctionsRequest.sol";
import { OwnedThreeStep } from "@solbase/auth/OwnedThreeStep.sol";

/// @title RiskOracleController - AI-Powered Risk Assessment Engine
/// @notice Integrates Chainlink Functions with Amazon Bedrock AI for dynamic collateral ratio determination
/// @dev Handles AI-powered risk assessment using Chainlink Functions for optimal collateral ratios with comprehensive
/// safety mechanisms
contract RiskOracleController is OwnedThreeStep, FunctionsClient {
    using FunctionsRequest for FunctionsRequest.Request;

    // =============================================================
    //                      CONSTANTS
    // =============================================================

    /// @notice Safety ratio bounds in basis points (100_00 = 100%)
    uint256 public constant MAX_BPS = 10_000; // 10,000 = 100%
    uint256 public constant MIN_COLLATERAL_RATIO = 10_000; // 100% - absolute minimum to prevent undercollateralization
    uint256 public constant SAFETY_MIN_RATIO = 13_000; // 130% - safety minimum for high confidence
    uint256 public constant SAFETY_MAX_RATIO = 17_000; // 170% - safety maximum

    /// @notice Circuit breaker configuration constants
    uint256 public constant MAX_FAILURES = 5;
    uint256 public constant FAILURE_RESET_TIME = 1 hours;

    /// @notice Manual processing timing constants
    uint256 public constant MANUAL_PROCESSING_DELAY = 30 minutes;
    uint256 public constant EMERGENCY_WITHDRAWAL_DELAY = 2 hours;
    uint256 public constant DEFAULT_CONSERVATIVE_RATIO = 16_000; // 160% in basis points

    // =============================================================
    //                   CONFIGURABLE STATE
    // =============================================================

    /// @notice Manual processing strategies for stuck or failed AI requests
    /// @param PROCESS_WITH_OFFCHAIN_AI Use external AI response for minting decisions
    /// @param EMERGENCY_WITHDRAWAL Return all collateral without minting any tokens
    /// @param FORCE_DEFAULT_MINT Mint tokens using conservative predefined ratio
    enum ManualStrategy {
        PROCESS_WITH_OFFCHAIN_AI,
        EMERGENCY_WITHDRAWAL,
        FORCE_DEFAULT_MINT
    }

    /// @notice Enhanced request tracking for comprehensive AI assessment lifecycle
    /// @param vault Address of the CollateralVault that initiated the request
    /// @param user Address of the user who deposited collateral
    /// @param basketData Encoded collateral basket information for AI analysis
    /// @param collateralValue Total USD value of deposited collateral (18 decimals)
    /// @param timestamp Request creation timestamp for timeout management
    /// @param processed Whether the AI assessment has been completed
    /// @param internalRequestId Internal identifier for request tracking
    /// @param retryCount Number of retry attempts for failed requests
    /// @param manualProcessingRequested Whether user requested manual intervention
    /// @param manualRequestTime Timestamp when manual processing was requested
    struct RequestInfo {
        address vault;
        address user;
        uint256 internalRequestId;
        uint256 collateralValue;
        uint256 timestamp;
        uint256 manualRequestTime;
        uint8 retryCount;
        bool processed;
        bool manualProcessingRequested;
        bytes basketData;
    }

    /// @notice Chainlink Functions configuration for AI request processing
    bytes32 public donId;
    uint64 public subscriptionId;
    uint32 public gasLimit = 300_000;
    uint256 public failureCount = 0;
    uint256 public lastFailureTime = 0;
    uint256 private requestCounter = 1;
    bool public processingPaused = false;

    /// @notice AI source code for Chainlink Functions processing
    string public aiSourceCode;

    /// @notice State mappings for system operation and access control
    /// @dev Maps token symbols to their Chainlink price feed contracts for real-time pricing
    mapping(string => AggregatorV3Interface) public priceFeeds;

    /// @dev Maps addresses to manual processing authorization status
    mapping(address => bool) public authorizedManualProcessors;

    /// @dev Maps Chainlink request IDs to complete request information and status
    mapping(bytes32 => RequestInfo) public requests;

    /// @dev Maps internal request IDs to Chainlink request IDs for dual tracking
    mapping(uint256 => bytes32) public internalToChainlinkId;

    /// @dev Maps vault addresses to authorization status for AI request submission
    mapping(address => bool) public authorizedCallers;

    // =============================================================
    //                    EVENTS & ERRORS
    // =============================================================

    /// @notice Core AI processing events
    event AIRequestSubmitted(
        uint256 indexed internalRequestId, bytes32 indexed chainlinkRequestId, address indexed user, address vault
    );
    event AIResultProcessed(
        uint256 indexed internalRequestId,
        bytes32 indexed chainlinkRequestId,
        uint256 ratio,
        uint256 confidence,
        uint256 mintAmount
    );
    event CallbackFailed(uint256 indexed internalRequestId, string reason);

    /// @notice System management events
    event CircuitBreakerTripped(uint256 failureCount, uint256 timestamp);
    event ProcessingPaused(bool paused);
    event RequestRetried(uint256 indexed internalRequestId, uint8 retryCount);

    /// @notice Manual processing events
    event ManualProcessingRequested(uint256 indexed internalRequestId, address indexed user, uint256 timestamp);
    event ManualProcessingCompleted(
        uint256 indexed internalRequestId,
        address indexed processor,
        ManualStrategy strategy,
        uint256 ratio,
        uint256 mintAmount
    );
    event EmergencyWithdrawal(uint256 indexed internalRequestId, address indexed user, uint256 timestamp);
    event OffChainAIProcessed(
        uint256 indexed internalRequestId,
        address indexed processor,
        string aiResponse,
        uint256 ratio,
        uint256 confidence
    );

    /// @notice Configuration events
    event PriceFeedUpdated(string indexed token, address indexed priceFeed);
    event ChainlinkConfigUpdated(bytes32 donId, uint64 subscriptionId, uint32 gasLimit);

    /// @notice Access control errors
    error UnauthorizedCaller();
    error ZeroAddressCaller();
    error UnauthorizedManualProcessor();

    /// @notice Request processing errors
    error RequestIdMismatch();
    error AlreadyProcessed();
    error RequestFailed();
    error CallbackError();
    error ProcessingError();
    error RequestNotFound();
    error RequestNotExpired();

    /// @notice Configuration errors
    error InvalidSubscriptionId();
    error InvalidFee();
    error InvalidPromptTemplate();
    error InvalidManualStrategy();
    error InvalidPriceFeed();

    /// @notice System protection errors
    error InsufficientFee();
    error CircuitBreakerError();

    // =============================================================
    //                  DEPLOYMENT & INITIALIZATION
    // =============================================================

    /// @notice Deploy and initialize the AI Risk Assessment Controller
    /// @dev Sets up Chainlink Functions integration and owner authorization
    /// @param _functionsRouter Address of the Chainlink Functions router contract
    /// @param _donId Decentralized Oracle Network identifier for Chainlink Functions
    /// @param _subscriptionId Chainlink Functions subscription ID for request billing
    /// @param _aiSourceCode JavaScript source code for AI processing via Chainlink Functions
    constructor(address _functionsRouter, bytes32 _donId, uint64 _subscriptionId, string memory _aiSourceCode)
        OwnedThreeStep(msg.sender)
        FunctionsClient(_functionsRouter)
    {
        donId = _donId;
        subscriptionId = _subscriptionId;
        aiSourceCode = _aiSourceCode;

        // Owner is automatically authorized for manual processing
        authorizedManualProcessors[msg.sender] = true;
    }

    // =============================================================
    //                     ACCESS CONTROL
    // =============================================================

    /// @notice Restrict function access to authorized vault contracts
    modifier onlyAuthorizedCaller() {
        if (!authorizedCallers[msg.sender]) revert UnauthorizedCaller();
        _;
    }

    /// @notice Ensure system is not paused for normal operations
    modifier whenNotPaused() {
        if (processingPaused) revert ProcessingError();
        _;
    }

    /// @notice Circuit breaker protection against cascading failures
    modifier circuitBreakerCheck() {
        if (failureCount >= MAX_FAILURES) {
            if (block.timestamp < lastFailureTime + FAILURE_RESET_TIME) {
                revert CircuitBreakerError();
            } else {
                failureCount = 0;
            }
        }
        _;
    }

    /// @notice Restrict manual processing to authorized operators
    modifier onlyAuthorizedManualProcessor() {
        if (!authorizedManualProcessors[msg.sender] && msg.sender != owner) {
            revert UnauthorizedManualProcessor();
        }
        _;
    }

    // =============================================================
    //                        CORE LOGIC
    // =============================================================

    /// @notice Submit collateral basket for AI-powered risk assessment
    /// @dev Creates Chainlink Functions request with collateral data and current market prices
    /// @param user Address of the user who deposited collateral
    /// @param basketData Encoded information about the collateral basket composition
    /// @param collateralValue Total USD value of the deposited collateral (18 decimals)
    /// @return internalRequestId Unique identifier for tracking this AI assessment request
    function submitAIRequest(address user, bytes calldata basketData, uint256 collateralValue)
        external
        payable
        onlyAuthorizedCaller
        whenNotPaused
        circuitBreakerCheck
        returns (uint256 internalRequestId)
    {
        internalRequestId = requestCounter++;

        // Prepare Chainlink Functions request with AI source code
        FunctionsRequest.Request memory req;
        req.initializeRequestForInlineJavaScript(aiSourceCode);

        // Package arguments for AI analysis: basket composition, value, and market prices
        string[] memory args = new string[](3);
        args[0] = string(basketData);
        args[1] = _uint2str(collateralValue);
        args[2] = _getCurrentPricesJson();
        req.setArgs(args);

        // Submit request to Chainlink Functions network
        bytes32 chainlinkRequestId = _sendRequest(req.encodeCBOR(), subscriptionId, gasLimit, donId);

        // Store comprehensive request information for tracking and processing
        requests[chainlinkRequestId] = RequestInfo({
            vault: msg.sender,
            user: user,
            basketData: basketData,
            collateralValue: collateralValue,
            timestamp: block.timestamp,
            processed: false,
            internalRequestId: internalRequestId,
            retryCount: 0,
            manualProcessingRequested: false,
            manualRequestTime: 0
        });

        // Maintain bidirectional mapping for request identification
        internalToChainlinkId[internalRequestId] = chainlinkRequestId;

        emit AIRequestSubmitted(internalRequestId, chainlinkRequestId, user, msg.sender);

        return internalRequestId;
    }

    /// @notice Process completed AI assessment and trigger AIUSD minting
    /// @dev Called exclusively by Chainlink Functions upon AI evaluation completion
    /// @param requestId Chainlink request identifier for the completed assessment
    /// @param response AI-generated response containing risk assessment and ratio recommendation
    /// @param err Any error information returned by the Chainlink Functions execution
    function _fulfillRequest(bytes32 requestId, bytes memory response, bytes memory err) internal override {
        RequestInfo storage request = requests[requestId];

        if (request.internalRequestId == 0) {
            emit CallbackFailed(0, "Request not found");
            return;
        }

        if (request.processed) {
            emit CallbackFailed(request.internalRequestId, "Already processed");
            return;
        }

        if (err.length > 0) {
            _handleCallbackFailure(request.internalRequestId, string(err));
            return;
        }

        try this._processAIResponse(requestId, response) {
            // Success handled in _processAIResponse
        } catch Error(string memory reason) {
            _handleCallbackFailure(request.internalRequestId, reason);
        } catch {
            _handleCallbackFailure(request.internalRequestId, "Unknown error in processing");
        }
    }

    /// @notice Parse and apply AI assessment results with safety bounds
    /// @dev External function to enable try/catch error handling for AI response processing
    /// @param requestId Chainlink request identifier
    /// @param response Raw AI response containing ratio and confidence data
    function _processAIResponse(bytes32 requestId, bytes memory response) external {
        require(msg.sender == address(this), "Only self");

        RequestInfo storage request = requests[requestId];

        // Validate request exists and is in correct state
        if (request.internalRequestId == 0) revert RequestNotFound();
        if (request.processed) revert AlreadyProcessed();
        if (request.vault == address(0)) revert RequestNotFound();

        string memory responseStr = string(response);

        // Extract AI recommendations and apply safety constraints
        (uint256 ratio, uint256 confidence) = _parseResponse(responseStr);
        ratio = _applySafetyBounds(ratio, confidence);

        // Prevent division by zero - should never happen due to safety bounds, but extra protection
        if (ratio == 0) {
            _handleCallbackFailure(request.internalRequestId, "Invalid ratio calculated");
            return;
        }

        // Calculate AIUSD mint amount using basis points mathematics
        // mintAmount = collateralValue * BASIS_POINTS_SCALE / ratio
        // Example: $20,000 collateral at 150% ratio = $20,000 * 10,000 / 15,000 = $13,333 AIUSD
        uint256 mintAmount = (request.collateralValue * MAX_BPS) / ratio;

        // Execute minting through vault callback BEFORE marking as processed
        _triggerMintingSafe(request.vault, request.user, request.internalRequestId, mintAmount, ratio, confidence);

        // Only mark as processed after successful minting attempt
        request.processed = true;

        emit AIResultProcessed(request.internalRequestId, requestId, ratio, confidence, mintAmount);
    }

    /// @notice User-initiated request for manual processing of stuck AI assessment
    /// @dev Allows users to escalate requests that have exceeded normal processing time
    /// @param internalRequestId Internal identifier of the request requiring manual intervention
    function requestManualProcessing(uint256 internalRequestId) external {
        bytes32 chainlinkRequestId = internalToChainlinkId[internalRequestId];
        RequestInfo storage request = requests[chainlinkRequestId];

        if (request.internalRequestId == 0) revert RequestNotFound();
        if (request.user != msg.sender) revert UnauthorizedCaller();
        if (request.processed) revert AlreadyProcessed();
        if (block.timestamp < request.timestamp + MANUAL_PROCESSING_DELAY) revert RequestNotExpired();

        request.manualProcessingRequested = true;
        request.manualRequestTime = block.timestamp;

        emit ManualProcessingRequested(internalRequestId, msg.sender, block.timestamp);
    }

    /// @notice Emergency withdrawal for users with severely delayed AI assessments
    /// @dev Returns all collateral without minting when AI processing fails completely
    /// @param internalRequestId Internal identifier of the request requiring emergency withdrawal
    function emergencyWithdraw(uint256 internalRequestId) external {
        bytes32 chainlinkRequestId = internalToChainlinkId[internalRequestId];
        RequestInfo storage request = requests[chainlinkRequestId];

        if (request.internalRequestId == 0) revert RequestNotFound();
        if (request.user != msg.sender) revert UnauthorizedCaller();
        if (request.processed) revert AlreadyProcessed();
        if (block.timestamp < request.timestamp + EMERGENCY_WITHDRAWAL_DELAY) revert RequestNotExpired();

        request.processed = true;
        _triggerEmergencyWithdrawal(request.vault, request.user, internalRequestId);

        emit EmergencyWithdrawal(internalRequestId, msg.sender, block.timestamp);
    }

    // =============================================================
    //                     MANAGER LOGIC
    // =============================================================

    /// @notice Configure Chainlink price feeds for real-time token valuation
    /// @dev Maps token symbols to their corresponding Chainlink aggregator contracts
    /// @param tokens Array of token symbols (e.g., ["ETH", "WBTC", "DAI", "USDC"])
    /// @param feeds Array of Chainlink price feed contract addresses
    function setPriceFeeds(string[] calldata tokens, address[] calldata feeds) external onlyOwner {
        require(tokens.length == feeds.length, "Array length mismatch");

        for (uint256 i = 0; i < tokens.length; i++) {
            if (feeds[i] == address(0)) revert InvalidPriceFeed();
            priceFeeds[tokens[i]] = AggregatorV3Interface(feeds[i]);
            emit PriceFeedUpdated(tokens[i], feeds[i]);
        }
    }

    /// @notice Update Chainlink Functions configuration for AI processing
    /// @dev Allows modification of DON ID, subscription, gas limits, and AI source code
    /// @param _donId New Decentralized Oracle Network identifier
    /// @param _subscriptionId New Chainlink Functions subscription ID
    /// @param _gasLimit New gas limit for AI processing functions
    /// @param _aiSourceCode Updated JavaScript source code for AI analysis
    function updateChainlinkConfig(
        bytes32 _donId,
        uint64 _subscriptionId,
        uint32 _gasLimit,
        string calldata _aiSourceCode
    ) external onlyOwner {
        donId = _donId;
        subscriptionId = _subscriptionId;
        gasLimit = _gasLimit;
        aiSourceCode = _aiSourceCode;

        emit ChainlinkConfigUpdated(_donId, _subscriptionId, _gasLimit);
    }

    /// @notice Process stuck requests using external AI assessment or predefined strategies
    /// @dev Authorized operators can resolve failed AI requests through multiple recovery methods
    /// @param internalRequestId Internal identifier of the request requiring manual processing
    /// @param offChainAIResponse External AI response for PROCESS_WITH_OFFCHAIN_AI strategy
    /// @param strategy Manual processing strategy to apply for request resolution
    function processWithOffChainAI(
        uint256 internalRequestId,
        string calldata offChainAIResponse,
        ManualStrategy strategy
    ) external onlyAuthorizedManualProcessor {
        bytes32 chainlinkRequestId = internalToChainlinkId[internalRequestId];
        RequestInfo storage request = requests[chainlinkRequestId];

        if (request.internalRequestId == 0) revert RequestNotFound();
        if (request.processed) revert AlreadyProcessed();

        if (!request.manualProcessingRequested) {
            if (msg.sender != owner && block.timestamp < request.timestamp + MANUAL_PROCESSING_DELAY) {
                revert RequestNotExpired();
            }
        }

        uint256 ratio;
        uint256 confidence;
        uint256 mintAmount;

        if (strategy == ManualStrategy.PROCESS_WITH_OFFCHAIN_AI) {
            (ratio, confidence) = _parseResponse(offChainAIResponse);
            ratio = _applySafetyBounds(ratio, confidence);
            mintAmount = (request.collateralValue * MAX_BPS) / ratio;

            emit OffChainAIProcessed(internalRequestId, msg.sender, offChainAIResponse, ratio, confidence);
        } else if (strategy == ManualStrategy.EMERGENCY_WITHDRAWAL) {
            ratio = 0;
            confidence = 0;
            mintAmount = 0;
            _triggerEmergencyWithdrawal(request.vault, request.user, internalRequestId);
            emit EmergencyWithdrawal(internalRequestId, request.user, block.timestamp);
        } else if (strategy == ManualStrategy.FORCE_DEFAULT_MINT) {
            ratio = DEFAULT_CONSERVATIVE_RATIO;
            confidence = 50;
            mintAmount = (request.collateralValue * MAX_BPS) / ratio;
        } else {
            revert InvalidManualStrategy();
        }

        request.processed = true;

        if (strategy != ManualStrategy.EMERGENCY_WITHDRAWAL) {
            _triggerMintingSafe(request.vault, request.user, internalRequestId, mintAmount, ratio, confidence);
        }

        emit ManualProcessingCompleted(internalRequestId, msg.sender, strategy, ratio, mintAmount);
        emit AIResultProcessed(internalRequestId, chainlinkRequestId, ratio, confidence, mintAmount);
    }

    /// @notice Emergency system controls for circuit breaker management
    /// @dev Pauses all AI processing during system emergencies or maintenance
    function pauseProcessing() external onlyOwner {
        processingPaused = true;
        emit ProcessingPaused(true);
    }

    /// @notice Resume normal AI processing operations
    /// @dev Resets failure counters and re-enables AI assessment requests
    function resumeProcessing() external onlyOwner {
        processingPaused = false;
        failureCount = 0;
        emit ProcessingPaused(false);
    }

    /// @notice Reset circuit breaker failure tracking
    /// @dev Clears failure count and timestamps to restore normal operation
    function resetCircuitBreaker() external onlyOwner {
        failureCount = 0;
        lastFailureTime = 0;
    }

    /// @notice Authorize vault contracts for AI request submission
    /// @dev Controls which contracts can submit collateral for AI assessment
    /// @param caller Address of the vault contract to authorize or deauthorize
    /// @param authorized Whether the caller should be granted AI request permissions
    function setAuthorizedCaller(address caller, bool authorized) external onlyOwner {
        if (caller == address(0)) revert ZeroAddressCaller();
        authorizedCallers[caller] = authorized;
    }

    /// @notice Authorize operators for manual request processing
    /// @dev Controls which addresses can perform manual intervention on stuck requests
    /// @param processor Address to grant or revoke manual processing authorization
    /// @param authorized Whether the processor should be granted manual processing permissions
    function setAuthorizedManualProcessor(address processor, bool authorized) external onlyOwner {
        if (processor == address(0)) revert ZeroAddressCaller();
        authorizedManualProcessors[processor] = authorized;
    }

    // =============================================================
    //                  EXTERNAL VIEW FUNCTIONS
    // =============================================================

    /// @notice Estimate total fee required for AI request processing
    /// @dev Returns zero as Chainlink Functions uses subscription billing model
    /// @return Total fee in wei (always 0 for subscription-based billing)
    function estimateTotalFee() public pure returns (uint256) {
        return 0; // Chainlink Functions uses subscription model
    }

    /// @notice Retrieve comprehensive information about a specific AI assessment request
    /// @param internalRequestId Internal identifier of the request to query
    /// @return Complete RequestInfo struct with all tracking and status information
    function getRequestInfo(uint256 internalRequestId) external view returns (RequestInfo memory) {
        bytes32 chainlinkRequestId = internalToChainlinkId[internalRequestId];
        return requests[chainlinkRequestId];
    }

    /// @notice Get current system status and circuit breaker state
    /// @return paused Whether AI processing is currently paused
    /// @return failures Current consecutive failure count
    /// @return lastFailure Timestamp of the most recent processing failure
    /// @return circuitBreakerActive Whether circuit breaker is currently blocking requests
    function getSystemStatus()
        external
        view
        returns (bool paused, uint256 failures, uint256 lastFailure, bool circuitBreakerActive)
    {
        return (
            processingPaused,
            failureCount,
            lastFailureTime,
            failureCount >= MAX_FAILURES && block.timestamp < lastFailureTime + FAILURE_RESET_TIME
        );
    }

    /// @notice Get the latest price from Chainlink price feed for a specific token
    /// @param token Symbol of the token to query (e.g., "ETH", "WBTC")
    /// @return Latest price from the corresponding Chainlink price aggregator
    function getLatestPrice(string calldata token) external view returns (int256) {
        AggregatorV3Interface priceFeed = priceFeeds[token];
        if (address(priceFeed) == address(0)) revert InvalidPriceFeed();

        (, int256 price,,,) = priceFeed.latestRoundData();
        return price;
    }

    // =============================================================
    //                INTERNAL/PRIVATE VIEW FUNCTIONS
    // =============================================================

    /// @notice Generate current market prices in JSON format for AI analysis
    /// @dev Provides real-time pricing data to enhance AI risk assessment accuracy
    /// @return JSON string containing current prices for supported tokens
    function _getCurrentPricesJson() internal view returns (string memory) {
        // This would be expanded based on your supported tokens
        // For now, returning a simple structure
        return '{"ETH": 2000, "WBTC": 30000, "DAI": 1, "USDC": 1}';
    }

    /// @notice Execute AIUSD minting through vault callback with error handling
    /// @param vault Address of the CollateralVault to trigger minting
    /// @param user Address of the user receiving minted AIUSD
    /// @param internalRequestId Internal request identifier for tracking
    /// @param mintAmount Amount of AIUSD tokens to mint
    /// @param ratio Applied collateral ratio in basis points
    /// @param confidence AI confidence score for the assessment
    function _triggerMintingSafe(
        address vault,
        address user,
        uint256 internalRequestId,
        uint256 mintAmount,
        uint256 ratio,
        uint256 confidence
    ) internal {
        bytes memory callData = abi.encodeWithSignature(
            "processAICallback(address,uint256,uint256,uint256,uint256)",
            user,
            internalRequestId,
            mintAmount,
            ratio,
            confidence
        );

        (bool success, bytes memory returnData) = vault.call{ gas: 200_000 }(callData);

        if (!success) {
            emit CallbackFailed(internalRequestId, _getRevertReason(returnData));
            _handleCallbackFailure(internalRequestId, _getRevertReason(returnData));
        }
    }

    /// @notice Execute emergency withdrawal through vault callback
    /// @param vault Address of the CollateralVault to trigger withdrawal
    /// @param user Address of the user receiving returned collateral
    /// @param internalRequestId Internal request identifier for tracking
    function _triggerEmergencyWithdrawal(address vault, address user, uint256 internalRequestId) internal {
        bytes memory callData = abi.encodeWithSignature("emergencyWithdraw(address,uint256)", user, internalRequestId);
        (bool success, bytes memory returnData) = vault.call{ gas: 200_000 }(callData);
        if (!success) {
            emit CallbackFailed(internalRequestId, _getRevertReason(returnData));
        }
    }

    /// @notice Handle AI processing failures with circuit breaker logic
    /// @param requestId Internal request identifier for the failed request
    /// @param reason Human-readable reason for the processing failure
    function _handleCallbackFailure(uint256 requestId, string memory reason) internal {
        failureCount++;
        lastFailureTime = block.timestamp;

        emit CallbackFailed(requestId, reason);

        if (failureCount >= MAX_FAILURES) {
            processingPaused = true;
            emit CircuitBreakerTripped(failureCount, block.timestamp);
        }
    }

    /// @notice Parse AI response to extract collateral ratio and confidence scores
    /// @param response Raw AI response string containing structured assessment data
    /// @return ratio Extracted collateral ratio in basis points
    /// @return confidence Extracted AI confidence score (0-100)
    function _parseResponse(string memory response) internal pure returns (uint256 ratio, uint256 confidence) {
        ratio = 15_000; // 150% default in basis points
        confidence = 50;

        bytes memory data = bytes(response);

        // Parse RATIO:XXX (expecting percentage, convert to basis points)
        for (uint256 i = 0; i < data.length - 6; i++) {
            if (_matches(data, i, "RATIO:")) {
                uint256 parsedRatio = _extractNumber(data, i + 6, 3);
                // Accept any parsed ratio > 0 and convert percentage to basis points
                if (parsedRatio > 0) {
                    ratio = parsedRatio * 100; // Convert percentage to basis points (130% -> 13,000)
                }
                break;
            }
        }

        // Parse CONFIDENCE:YY
        for (uint256 i = 0; i < data.length - 11; i++) {
            if (_matches(data, i, "CONFIDENCE:")) {
                confidence = _extractNumber(data, i + 11, 2);
                if (confidence > 100) confidence = 50;
                break;
            }
        }
    }

    /// @notice Apply safety bounds to AI-recommended ratio with confidence adjustments
    /// @param aiRatio AI-recommended collateral ratio in basis points
    /// @param confidence AI confidence score affecting minimum ratio requirements
    /// @return Adjusted ratio within safe operational bounds
    function _applySafetyBounds(uint256 aiRatio, uint256 confidence) internal pure returns (uint256) {
        uint256 minRatio = SAFETY_MIN_RATIO; // 130% in basis points
        uint256 maxRatio = SAFETY_MAX_RATIO; // 170% in basis points

        // Adjust minimum ratio based on confidence (lower confidence = higher minimum)
        if (confidence < 60) {
            minRatio = 14_000; // 140% for low confidence
        } else if (confidence < 80) {
            minRatio = 13_500; // 135% for medium confidence
        }

        // Ensure we never go below 100% collateralization (prevent undercollateralization)
        if (aiRatio < MIN_COLLATERAL_RATIO) return minRatio;
        if (aiRatio < minRatio) return minRatio;
        if (aiRatio > maxRatio) return maxRatio;

        return aiRatio;
    }

    /// @notice Extract revert reason from failed external call return data
    /// @param returnData Raw return data from failed external call
    /// @return Human-readable error message or default fallback
    function _getRevertReason(bytes memory returnData) internal pure returns (string memory) {
        if (returnData.length < 68) return "Unknown error";
        assembly {
            returnData := add(returnData, 0x04)
        }
        return abi.decode(returnData, (string));
    }

    /// @notice Check if byte sequence matches expected pattern at specific position
    /// @param data Byte array to search within
    /// @param start Starting position for pattern matching
    /// @param pattern String pattern to match against
    /// @return Whether the pattern matches at the specified position
    function _matches(bytes memory data, uint256 start, string memory pattern) internal pure returns (bool) {
        bytes memory p = bytes(pattern);
        if (start + p.length > data.length) return false;
        for (uint256 i = 0; i < p.length; i++) {
            if (data[start + i] != p[i]) return false;
        }
        return true;
    }

    /// @notice Extract numeric value from byte sequence with maximum digit limit
    /// @param data Byte array containing numeric characters
    /// @param start Starting position for number extraction
    /// @param maxDigits Maximum number of digits to process
    /// @return Extracted numeric value as uint256
    function _extractNumber(bytes memory data, uint256 start, uint256 maxDigits) internal pure returns (uint256) {
        uint256 value = 0;
        uint256 end = start + maxDigits;
        if (end > data.length) end = data.length;
        for (uint256 i = start; i < end; i++) {
            if (data[i] >= "0" && data[i] <= "9") {
                value = value * 10 + (uint8(data[i]) - 48);
            }
        }
        return value;
    }

    /// @notice Convert unsigned integer to decimal string representation
    /// @param _i Integer value to convert to string
    /// @return String representation of the input integer
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
