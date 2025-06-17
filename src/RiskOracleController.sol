// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { FunctionsClient } from "lib/chainlink/contracts/src/v0.8/functions/dev/v1_0_0/FunctionsClient.sol";
import { FunctionsRequest } from "lib/chainlink/contracts/src/v0.8/functions/dev/v1_0_0/libraries/FunctionsRequest.sol";
import { AggregatorV3Interface } from "lib/chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "./interfaces/IAIStablecoin.sol";
import "lib/solbase/src/auth/OwnedThreeStep.sol";

/// @title RiskOracleController - Chainlink Functions AI Risk Assessment Controller
/// @notice Handles AI-powered risk assessment using Chainlink Functions for optimal collateral ratios
/// @dev Integrates with Chainlink Functions and Data Feeds for comprehensive risk analysis
contract RiskOracleController is OwnedThreeStep, FunctionsClient {
    using FunctionsRequest for FunctionsRequest.Request;

    /// @notice Custom errors
    error UnauthorizedCaller();
    error ZeroAddressCaller();
    error InsufficientFee();
    error RequestIdMismatch();
    error AlreadyProcessed();
    error RequestFailed();
    error CallbackError();
    error InvalidSubscriptionId();
    error InvalidFee();
    error InvalidPromptTemplate();
    error CircuitBreakerError();
    error RequestNotFound();
    error ProcessingError();
    error RequestNotExpired();
    error InvalidManualStrategy();
    error UnauthorizedManualProcessor();
    error InvalidPriceFeed();

    /// @notice Manual processing strategies
    enum ManualStrategy {
        PROCESS_WITH_OFFCHAIN_AI, // Use off-chain AI response to mint
        EMERGENCY_WITHDRAWAL, // Return collateral without minting
        FORCE_DEFAULT_MINT // Mint with conservative default ratio

    }

    /// @notice Circuit breaker for emergency stops
    bool public processingPaused = false;
    uint256 public failureCount = 0;
    uint256 public constant MAX_FAILURES = 5;
    uint256 public lastFailureTime = 0;
    uint256 public constant FAILURE_RESET_TIME = 1 hours;

    /// @notice Manual processing configuration
    uint256 public constant MANUAL_PROCESSING_DELAY = 30 minutes;
    uint256 public constant EMERGENCY_WITHDRAWAL_DELAY = 2 hours;
    uint256 public constant DEFAULT_CONSERVATIVE_RATIO = 16_000; // 160%

    /// @notice Chainlink Functions configuration
    bytes32 public donId;
    uint64 public subscriptionId;
    uint32 public gasLimit = 300_000;
    string public aiSourceCode;

    /// @notice Price feeds for different tokens
    mapping(string => AggregatorV3Interface) public priceFeeds;

    /// @notice Authorized manual processors
    mapping(address => bool) public authorizedManualProcessors;

    /// @notice Request tracking
    mapping(bytes32 => RequestInfo) public requests; // Chainlink request ID -> RequestInfo
    mapping(uint256 => bytes32) public internalToChainlinkId; // Internal ID -> Chainlink ID
    uint256 private requestCounter = 1;

    /// @notice Enhanced request information
    struct RequestInfo {
        address vault;
        address user;
        bytes basketData;
        uint256 collateralValue;
        uint256 timestamp;
        bool processed;
        uint256 internalRequestId;
        uint8 retryCount;
        bool manualProcessingRequested;
        uint256 manualRequestTime;
    }

    /// @notice Authorized callers (vaults)
    mapping(address => bool) public authorizedCallers;

    /// @notice Events
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
    event CircuitBreakerTripped(uint256 failureCount, uint256 timestamp);
    event ProcessingPaused(bool paused);
    event RequestRetried(uint256 indexed internalRequestId, uint8 retryCount);
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
    event PriceFeedUpdated(string indexed token, address indexed priceFeed);
    event ChainlinkConfigUpdated(bytes32 donId, uint64 subscriptionId, uint32 gasLimit);

    /// @notice Modifiers
    modifier onlyAuthorizedCaller() {
        if (!authorizedCallers[msg.sender]) revert UnauthorizedCaller();
        _;
    }

    modifier whenNotPaused() {
        if (processingPaused) revert ProcessingError();
        _;
    }

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

    modifier onlyAuthorizedManualProcessor() {
        if (!authorizedManualProcessors[msg.sender] && msg.sender != owner) {
            revert UnauthorizedManualProcessor();
        }
        _;
    }

    /// @notice Initialize the contract
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

    /// @notice Set up price feeds for tokens
    /// @param tokens Array of token symbols (e.g., ["ETH", "WBTC", "DAI"])
    /// @param feeds Array of corresponding Chainlink price feed addresses
    function setPriceFeeds(string[] calldata tokens, address[] calldata feeds) external onlyOwner {
        require(tokens.length == feeds.length, "Array length mismatch");

        for (uint256 i = 0; i < tokens.length; i++) {
            if (feeds[i] == address(0)) revert InvalidPriceFeed();
            priceFeeds[tokens[i]] = AggregatorV3Interface(feeds[i]);
            emit PriceFeedUpdated(tokens[i], feeds[i]);
        }
    }

    /// @notice Update Chainlink Functions configuration
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

    /// @notice Estimate total fee required for AI request (now free with subscription)
    function estimateTotalFee() public pure returns (uint256) {
        return 0; // Chainlink Functions uses subscription model
    }

    /// @notice Submit AI request using Chainlink Functions
    /// @param user The user who deposited collateral
    /// @param basketData Encoded collateral basket information
    /// @param collateralValue Total USD value of collateral
    /// @return internalRequestId Our internal identifier for this AI request
    function submitAIRequest(address user, bytes calldata basketData, uint256 collateralValue)
        external
        payable
        onlyAuthorizedCaller
        whenNotPaused
        circuitBreakerCheck
        returns (uint256 internalRequestId)
    {
        internalRequestId = requestCounter++;

        // Create Functions request
        FunctionsRequest.Request memory req;
        req.initializeRequestForInlineJavaScript(aiSourceCode);

        // Prepare arguments: [basketData, collateralValue, currentPrices]
        string[] memory args = new string[](3);
        args[0] = string(basketData);
        args[1] = _uint2str(collateralValue);
        args[2] = _getCurrentPricesJson();
        req.setArgs(args);

        // Submit the request
        bytes32 chainlinkRequestId = _sendRequest(req.encodeCBOR(), subscriptionId, gasLimit, donId);

        // Store request info
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

        // Store mapping
        internalToChainlinkId[internalRequestId] = chainlinkRequestId;

        emit AIRequestSubmitted(internalRequestId, chainlinkRequestId, user, msg.sender);

        return internalRequestId;
    }

    /// @notice Chainlink Functions callback
    /// @param requestId The Chainlink request ID
    /// @param response The AI response from Chainlink Functions
    /// @param err Any error that occurred
    function fulfillRequest(bytes32 requestId, bytes memory response, bytes memory err) internal override {
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

    /// @notice Process AI response (external to handle try/catch)
    function _processAIResponse(bytes32 requestId, bytes memory response) external {
        require(msg.sender == address(this), "Only self");

        RequestInfo storage request = requests[requestId];
        string memory responseStr = string(response);

        // Parse AI response
        (uint256 ratio, uint256 confidence) = _parseResponse(responseStr);
        ratio = _applySafetyBounds(ratio, confidence);

        // Calculate mint amount
        uint256 mintAmount = (request.collateralValue * 10_000) / ratio;

        // Mark as processed
        request.processed = true;

        // Trigger minting
        _triggerMintingSafe(request.vault, request.user, request.internalRequestId, mintAmount, ratio, confidence);

        emit AIResultProcessed(request.internalRequestId, requestId, ratio, confidence, mintAmount);
    }

    /// @notice Get current prices for all supported tokens in JSON format
    function _getCurrentPricesJson() internal view returns (string memory) {
        // This would be expanded based on your supported tokens
        // For now, returning a simple structure
        return '{"ETH": 2000, "WBTC": 30000, "DAI": 1, "USDC": 1}';
    }

    /// @notice Trigger minting in the vault
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

    /// @notice Handle callback failures
    function _handleCallbackFailure(uint256 requestId, string memory reason) internal {
        failureCount++;
        lastFailureTime = block.timestamp;

        emit CallbackFailed(requestId, reason);

        if (failureCount >= MAX_FAILURES) {
            processingPaused = true;
            emit CircuitBreakerTripped(failureCount, block.timestamp);
        }
    }

    /// @notice User requests manual processing for stuck request
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

    /// @notice Process request with off-chain AI response
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
            mintAmount = (request.collateralValue * 10_000) / ratio;

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
            mintAmount = (request.collateralValue * 10_000) / ratio;
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

    /// @notice Emergency withdrawal
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

    /// @notice Trigger emergency withdrawal in vault
    function _triggerEmergencyWithdrawal(address vault, address user, uint256 internalRequestId) internal {
        bytes memory callData = abi.encodeWithSignature("emergencyWithdraw(address,uint256)", user, internalRequestId);
        (bool success, bytes memory returnData) = vault.call{ gas: 200_000 }(callData);
        if (!success) {
            emit CallbackFailed(internalRequestId, _getRevertReason(returnData));
        }
    }

    /// @notice Parse AI response (same logic as before)
    function _parseResponse(string memory response) internal pure returns (uint256 ratio, uint256 confidence) {
        ratio = 15_000; // 150% default
        confidence = 50;

        bytes memory data = bytes(response);

        // Parse RATIO:XXX
        for (uint256 i = 0; i < data.length - 6; i++) {
            if (_matches(data, i, "RATIO:")) {
                uint256 parsedRatio = _extractNumber(data, i + 6, 3);
                if (parsedRatio >= 125 && parsedRatio <= 200) {
                    ratio = parsedRatio * 100;
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

    /// @notice Apply safety bounds to AI ratio
    function _applySafetyBounds(uint256 aiRatio, uint256 confidence) internal pure returns (uint256) {
        uint256 minRatio = 13_000; // 130%
        uint256 maxRatio = 17_000; // 170%

        if (confidence < 60) {
            minRatio = 14_000; // 140% for low confidence
        } else if (confidence < 80) {
            minRatio = 13_500; // 135% for medium confidence
        }

        if (aiRatio < minRatio) return minRatio;
        if (aiRatio > maxRatio) return maxRatio;
        return aiRatio;
    }

    /// @notice Extract revert reason from return data
    function _getRevertReason(bytes memory returnData) internal pure returns (string memory) {
        if (returnData.length < 68) return "Unknown error";
        assembly {
            returnData := add(returnData, 0x04)
        }
        return abi.decode(returnData, (string));
    }

    /// @notice Emergency functions
    function pauseProcessing() external onlyOwner {
        processingPaused = true;
        emit ProcessingPaused(true);
    }

    function resumeProcessing() external onlyOwner {
        processingPaused = false;
        failureCount = 0;
        emit ProcessingPaused(false);
    }

    function resetCircuitBreaker() external onlyOwner {
        failureCount = 0;
        lastFailureTime = 0;
    }

    /// @notice Configuration functions
    function setAuthorizedCaller(address caller, bool authorized) external onlyOwner {
        if (caller == address(0)) revert ZeroAddressCaller();
        authorizedCallers[caller] = authorized;
    }

    function setAuthorizedManualProcessor(address processor, bool authorized) external onlyOwner {
        if (processor == address(0)) revert ZeroAddressCaller();
        authorizedManualProcessors[processor] = authorized;
    }

    /// @notice Helper functions
    function _matches(bytes memory data, uint256 start, string memory pattern) internal pure returns (bool) {
        bytes memory p = bytes(pattern);
        if (start + p.length > data.length) return false;
        for (uint256 i = 0; i < p.length; i++) {
            if (data[start + i] != p[i]) return false;
        }
        return true;
    }

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

    /// @notice View functions
    function getRequestInfo(uint256 internalRequestId) external view returns (RequestInfo memory) {
        bytes32 chainlinkRequestId = internalToChainlinkId[internalRequestId];
        return requests[chainlinkRequestId];
    }

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

    /// @notice Get the latest price from Chainlink price feed
    function getLatestPrice(string calldata token) external view returns (int256) {
        AggregatorV3Interface priceFeed = priceFeeds[token];
        if (address(priceFeed) == address(0)) revert InvalidPriceFeed();

        (, int256 price,,,) = priceFeed.latestRoundData();
        return price;
    }
}
