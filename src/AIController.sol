// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "./interfaces/IAIOracle.sol";
import "./interfaces/IAIStablecoin.sol";
import "./interfaces/AIOracleCallbackReceiver.sol";
import "lib/solbase/src/auth/OwnedThreeStep.sol";

/// @title AIController - Enhanced AI Controller with Manual Processing
/// @notice Handles AI requests with improved error handling and manual processing capabilities
/// @dev Integrates with ORA Oracle and provides multiple recovery mechanisms
contract AIController is OwnedThreeStep, AIOracleCallbackReceiver {
    /// @notice Custom errors
    error UnauthorizedCaller();
    error ZeroAddressCaller();
    error InsufficientFee();
    error RequestIdMismatch();
    error AlreadyProcessed();
    error RequestFailed();
    error CallbackError();
    error InvalidModelId();
    error InvalidFee();
    error InvalidPromptTemplate();
    error CircuitBreakerError();
    error RequestNotFound();
    error ProcessingError();
    error RequestNotExpired();
    error InvalidManualStrategy();
    error UnauthorizedManualProcessor();

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
    uint256 public constant MANUAL_PROCESSING_DELAY = 30 minutes; // Users can request manual processing after 30 min
    uint256 public constant EMERGENCY_WITHDRAWAL_DELAY = 2 hours; // Emergency withdrawal after 2 hours
    uint256 public constant DEFAULT_CONSERVATIVE_RATIO = 16_000; // 160% for force mint

    /// @notice Authorized manual processors (can be community members, DAO, etc.)
    mapping(address => bool) public authorizedManualProcessors;

    /// @notice Flexible gas configuration
    struct GasConfig {
        uint64 minGasLimit;
        uint64 maxGasLimit;
        uint64 defaultGasLimit;
        uint64 emergencyGasLimit;
    }

    GasConfig public gasConfig = GasConfig({
        minGasLimit: 200_000,
        maxGasLimit: 1_000_000,
        defaultGasLimit: 500_000,
        emergencyGasLimit: 300_000
    });

    /// @notice Request tracking with better data structure
    mapping(uint256 => RequestInfo) public requests;
    mapping(bytes32 => uint256) public requestsByHash; // Hash-based lookup
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
        uint256 oracleRequestId; // Store oracle ID when available
        uint8 retryCount;
        bytes32 requestHash; // For faster lookups
        bool manualProcessingRequested; // User requested manual processing
        uint256 manualRequestTime; // When manual processing was requested
    }

    /// @notice Authorized callers
    mapping(address => bool) public authorizedCallers;

    /// @notice Configuration
    uint256 public modelId = 11;
    uint256 public flatFee = 0;
    uint256 public oracleFee = 0.01 ether;
    IAIOracle public oraOracle;

    /// @notice Prompt template
    string public promptTemplate =
        "Analyze this DeFi collateral basket for OPTIMAL LOW ratio. Maximize capital efficiency while ensuring safety. Consider volatility, correlation, liquidity. Respond: RATIO:XXX CONFIDENCE:YY (130-170%, 0-100%).";

    /// @notice Events
    event AIRequestSubmitted(
        uint256 indexed internalRequestId,
        uint256 indexed oracleRequestId,
        address indexed user,
        address vault,
        bytes32 requestHash
    );
    event AIResultProcessed(
        uint256 indexed internalRequestId,
        uint256 indexed oracleRequestId,
        uint256 ratio,
        uint256 confidence,
        uint256 mintAmount
    );
    event CallbackFailed(uint256 indexed internalRequestId, string reason, uint256 gasUsed);
    event CircuitBreakerTripped(uint256 failureCount, uint256 timestamp);
    event ProcessingPaused(bool paused);
    event RequestRetried(uint256 indexed internalRequestId, uint8 retryCount);

    // New manual processing events
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
                // Reset circuit breaker
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
    constructor(address _oracle, uint256 _modelId, uint256 _oracleFee)
        OwnedThreeStep(msg.sender)
        AIOracleCallbackReceiver(IAIOracle(_oracle))
    {
        modelId = _modelId;
        oracleFee = _oracleFee;
        oraOracle = IAIOracle(_oracle);

        // Owner is automatically authorized for manual processing
        authorizedManualProcessors[msg.sender] = true;
    }

    /// @notice Estimate total fee required for AI request
    function estimateTotalFee() public view returns (uint256) {
        return oracleFee + flatFee;
    }

    /// @notice Submit AI request with improved error handling
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
        uint256 requiredFee = estimateTotalFee();
        if (msg.value < requiredFee) revert InsufficientFee();

        internalRequestId = requestCounter++;

        // Create unique hash for this request
        bytes32 requestHash = keccak256(
            abi.encodePacked(msg.sender, user, basketData, collateralValue, block.timestamp, internalRequestId)
        );

        // Create AI prompt
        string memory prompt = _createPrompt(basketData, collateralValue);
        bytes memory input = bytes(prompt);

        // Prepare callback data with hash for verification
        bytes memory callbackData =
            abi.encode(msg.sender, user, basketData, collateralValue, internalRequestId, requestHash);

        // Submit to ORA with dynamic gas limit
        uint64 gasLimit = _calculateOptimalGasLimit(basketData);

        try oraOracle.requestCallback{ value: requiredFee }(modelId, input, address(this), gasLimit, callbackData)
        returns (uint256 oracleRequestId) {
            // Store request info with oracle ID
            requests[internalRequestId] = RequestInfo({
                vault: msg.sender,
                user: user,
                basketData: basketData,
                collateralValue: collateralValue,
                timestamp: block.timestamp,
                processed: false,
                internalRequestId: internalRequestId,
                oracleRequestId: oracleRequestId,
                retryCount: 0,
                requestHash: requestHash,
                manualProcessingRequested: false,
                manualRequestTime: 0
            });

            // Store hash mapping for fast lookup
            requestsByHash[requestHash] = internalRequestId;

            emit AIRequestSubmitted(internalRequestId, oracleRequestId, user, msg.sender, requestHash);

            // Refund excess
            if (msg.value > requiredFee) {
                payable(msg.sender).transfer(msg.value - requiredFee);
            }

            return internalRequestId;
        } catch Error(string memory reason) {
            _handleSubmissionFailure(reason);
            revert RequestFailed();
        }
    }

    /// @notice User requests manual processing for stuck request
    /// @param internalRequestId The request ID that's stuck
    function requestManualProcessing(uint256 internalRequestId) external {
        RequestInfo storage request = requests[internalRequestId];
        if (request.internalRequestId == 0) revert RequestNotFound();
        if (request.user != msg.sender) revert UnauthorizedCaller();
        if (request.processed) revert AlreadyProcessed();
        if (block.timestamp < request.timestamp + MANUAL_PROCESSING_DELAY) revert RequestNotExpired();

        request.manualProcessingRequested = true;
        request.manualRequestTime = block.timestamp;

        emit ManualProcessingRequested(internalRequestId, msg.sender, block.timestamp);
    }

    /// @notice Process request with off-chain AI response
    /// @param internalRequestId The request to process
    /// @param offChainAIResponse The AI response obtained off-chain
    /// @param strategy Manual processing strategy to use
    function processWithOffChainAI(
        uint256 internalRequestId,
        string calldata offChainAIResponse,
        ManualStrategy strategy
    ) external onlyAuthorizedManualProcessor {
        RequestInfo storage request = requests[internalRequestId];
        if (request.internalRequestId == 0) revert RequestNotFound();
        if (request.processed) revert AlreadyProcessed();

        // Check if manual processing was requested and enough time has passed
        if (!request.manualProcessingRequested) {
            // Allow immediate processing by owner/authorized processors if system is stuck
            if (msg.sender != owner && block.timestamp < request.timestamp + MANUAL_PROCESSING_DELAY) {
                revert RequestNotExpired();
            }
        }

        uint256 ratio;
        uint256 confidence;
        uint256 mintAmount;

        if (strategy == ManualStrategy.PROCESS_WITH_OFFCHAIN_AI) {
            // Parse the off-chain AI response
            (ratio, confidence) = _parseResponse(offChainAIResponse);
            ratio = _applySafetyBounds(ratio, confidence);
            mintAmount = (request.collateralValue * 10_000) / ratio;

            emit OffChainAIProcessed(internalRequestId, msg.sender, offChainAIResponse, ratio, confidence);
        } else if (strategy == ManualStrategy.EMERGENCY_WITHDRAWAL) {
            // Return collateral without minting
            ratio = 0;
            confidence = 0;
            mintAmount = 0;

            // Trigger withdrawal instead of minting
            _triggerEmergencyWithdrawal(request.vault, request.user, internalRequestId);

            emit EmergencyWithdrawal(internalRequestId, request.user, block.timestamp);
        } else if (strategy == ManualStrategy.FORCE_DEFAULT_MINT) {
            // Use conservative default ratio
            ratio = DEFAULT_CONSERVATIVE_RATIO; // 160%
            confidence = 50; // Medium confidence
            mintAmount = (request.collateralValue * 10_000) / ratio;
        } else {
            revert InvalidManualStrategy();
        }

        // Mark as processed
        request.processed = true;

        // Execute the chosen strategy
        if (strategy != ManualStrategy.EMERGENCY_WITHDRAWAL) {
            _triggerMintingSafe(request.vault, request.user, internalRequestId, mintAmount, ratio, confidence);
        }

        emit ManualProcessingCompleted(internalRequestId, msg.sender, strategy, ratio, mintAmount);
        emit AIResultProcessed(internalRequestId, request.oracleRequestId, ratio, confidence, mintAmount);
    }

    /// @notice Emergency withdrawal for users who don't want to proceed
    /// @param internalRequestId The request to withdraw from
    function emergencyWithdraw(uint256 internalRequestId) external {
        RequestInfo storage request = requests[internalRequestId];
        if (request.internalRequestId == 0) revert RequestNotFound();
        if (request.user != msg.sender) revert UnauthorizedCaller();
        if (request.processed) revert AlreadyProcessed();
        if (block.timestamp < request.timestamp + EMERGENCY_WITHDRAWAL_DELAY) revert RequestNotExpired();

        // Mark as processed
        request.processed = true;

        // Trigger withdrawal
        _triggerEmergencyWithdrawal(request.vault, request.user, internalRequestId);

        emit EmergencyWithdrawal(internalRequestId, msg.sender, block.timestamp);
    }

    /// @notice Trigger emergency withdrawal in vault
    function _triggerEmergencyWithdrawal(address vault, address user, uint256 internalRequestId) internal {
        bytes memory callData = abi.encodeWithSignature("emergencyWithdraw(address,uint256)", user, internalRequestId);

        (bool success, bytes memory returnData) = vault.call{ gas: gasConfig.emergencyGasLimit }(callData);

        if (!success) {
            emit CallbackFailed(internalRequestId, _getRevertReason(returnData), gasConfig.emergencyGasLimit);
        }
    }

    /// @notice Get all requests that can be manually processed
    /// @param startIndex Starting index for pagination
    /// @param count Number of requests to return
    /// @return requestIds Array of request IDs that can be manually processed
    /// @return users Array of corresponding user addresses
    /// @return timestamps Array of request timestamps
    /// @return strategies Array of available strategies for each request
    function getManualProcessingCandidates(uint256 startIndex, uint256 count)
        external
        view
        returns (
            uint256[] memory requestIds,
            address[] memory users,
            uint256[] memory timestamps,
            ManualStrategy[][] memory strategies
        )
    {
        uint256[] memory tempRequestIds = new uint256[](count);
        address[] memory tempUsers = new address[](count);
        uint256[] memory tempTimestamps = new uint256[](count);
        ManualStrategy[][] memory tempStrategies = new ManualStrategy[][](count);

        uint256 found = 0;
        uint256 checked = 0;

        for (uint256 i = startIndex + 1; found < count && i < requestCounter; i++) {
            RequestInfo memory request = requests[i];

            if (!request.processed && request.timestamp > 0) {
                uint256 timeElapsed = block.timestamp - request.timestamp;

                if (timeElapsed >= MANUAL_PROCESSING_DELAY) {
                    tempRequestIds[found] = i;
                    tempUsers[found] = request.user;
                    tempTimestamps[found] = request.timestamp;

                    // Determine available strategies
                    ManualStrategy[] memory availableStrategies;

                    if (timeElapsed >= EMERGENCY_WITHDRAWAL_DELAY) {
                        // All strategies available
                        availableStrategies = new ManualStrategy[](3);
                        availableStrategies[0] = ManualStrategy.PROCESS_WITH_OFFCHAIN_AI;
                        availableStrategies[1] = ManualStrategy.EMERGENCY_WITHDRAWAL;
                        availableStrategies[2] = ManualStrategy.FORCE_DEFAULT_MINT;
                    } else {
                        // Only AI processing and force mint available
                        availableStrategies = new ManualStrategy[](2);
                        availableStrategies[0] = ManualStrategy.PROCESS_WITH_OFFCHAIN_AI;
                        availableStrategies[1] = ManualStrategy.FORCE_DEFAULT_MINT;
                    }

                    tempStrategies[found] = availableStrategies;
                    found++;
                }
            }
            checked++;
        }

        // Resize arrays to actual found count
        requestIds = new uint256[](found);
        users = new address[](found);
        timestamps = new uint256[](found);
        strategies = new ManualStrategy[][](found);

        for (uint256 i = 0; i < found; i++) {
            requestIds[i] = tempRequestIds[i];
            users[i] = tempUsers[i];
            timestamps[i] = tempTimestamps[i];
            strategies[i] = tempStrategies[i];
        }
    }

    /// @notice Check what manual processing options are available for a request
    /// @param internalRequestId The request to check
    /// @return canProcess Whether manual processing is available
    /// @return availableStrategies Array of available strategies
    /// @return timeUntilEmergencyWithdraw Time until emergency withdrawal is available
    function getManualProcessingOptions(uint256 internalRequestId)
        external
        view
        returns (bool canProcess, ManualStrategy[] memory availableStrategies, uint256 timeUntilEmergencyWithdraw)
    {
        RequestInfo memory request = requests[internalRequestId];

        if (request.internalRequestId == 0 || request.processed) {
            return (false, new ManualStrategy[](0), 0);
        }

        uint256 timeElapsed = block.timestamp - request.timestamp;

        if (timeElapsed < MANUAL_PROCESSING_DELAY) {
            uint256 timeRemaining = MANUAL_PROCESSING_DELAY - timeElapsed;
            return (false, new ManualStrategy[](0), timeRemaining);
        }

        canProcess = true;

        if (timeElapsed >= EMERGENCY_WITHDRAWAL_DELAY) {
            // All strategies available
            availableStrategies = new ManualStrategy[](3);
            availableStrategies[0] = ManualStrategy.PROCESS_WITH_OFFCHAIN_AI;
            availableStrategies[1] = ManualStrategy.EMERGENCY_WITHDRAWAL;
            availableStrategies[2] = ManualStrategy.FORCE_DEFAULT_MINT;
            timeUntilEmergencyWithdraw = 0;
        } else {
            // Only AI processing and force mint available
            availableStrategies = new ManualStrategy[](2);
            availableStrategies[0] = ManualStrategy.PROCESS_WITH_OFFCHAIN_AI;
            availableStrategies[1] = ManualStrategy.FORCE_DEFAULT_MINT;
            timeUntilEmergencyWithdraw = EMERGENCY_WITHDRAWAL_DELAY - timeElapsed;
        }
    }

    /// @notice Improved ORA callback with better error handling
    /// @param requestId The oracle request ID
    /// @param output AI model output
    /// @param callbackData Encoded callback data
    function aiOracleCallback(uint256 requestId, bytes calldata output, bytes calldata callbackData)
        external
        onlyAIOracleCallback
        whenNotPaused
    {
        uint256 gasStart = gasleft();

        try this._processCallback(requestId, output, callbackData) {
            // Success - reset failure count
            if (failureCount > 0) {
                failureCount = 0;
            }
        } catch Error(string memory reason) {
            _handleCallbackFailure(requestId, reason, gasStart - gasleft());
        } catch {
            _handleCallbackFailure(requestId, "Unknown error", gasStart - gasleft());
        }
    }

    /// @notice Internal callback processing (separated for better error handling)
    /// @param requestId The oracle request ID
    /// @param output AI model output
    /// @param callbackData Encoded callback data
    function _processCallback(uint256 requestId, bytes calldata output, bytes calldata callbackData) external {
        require(msg.sender == address(this), "Internal function");

        // Decode callback data with hash verification
        (
            address vault,
            address user,
            bytes memory basketData,
            uint256 collateralValue,
            uint256 internalRequestId,
            bytes32 requestHash
        ) = abi.decode(callbackData, (address, address, bytes, uint256, uint256, bytes32));

        // Verify request exists and hash matches
        RequestInfo storage request = requests[internalRequestId];
        if (request.internalRequestId == 0) revert RequestNotFound();
        if (request.requestHash != requestHash) revert RequestIdMismatch();
        if (request.processed) revert AlreadyProcessed();

        // Parse AI response
        (uint256 ratio, uint256 confidence) = _parseResponse(string(output));

        // Apply safety bounds
        ratio = _applySafetyBounds(ratio, confidence);

        // Calculate mint amount
        uint256 mintAmount = (request.collateralValue * 10_000) / ratio;

        // Mark as processed
        request.processed = true;

        // Trigger minting with improved error handling
        _triggerMintingSafe(request.vault, request.user, internalRequestId, mintAmount, ratio, confidence);

        emit AIResultProcessed(internalRequestId, requestId, ratio, confidence, mintAmount);
    }

    /// @notice Safe minting with fallback mechanism
    function _triggerMintingSafe(
        address vault,
        address user,
        uint256 internalRequestId,
        uint256 mintAmount,
        uint256 ratio,
        uint256 confidence
    ) internal {
        // Use low-level call to prevent revert from breaking the callback
        bytes memory callData = abi.encodeWithSignature(
            "processAICallback(address,uint256,uint256,uint256,uint256)",
            user,
            internalRequestId,
            mintAmount,
            ratio,
            confidence
        );

        (bool success, bytes memory returnData) = vault.call{ gas: gasConfig.emergencyGasLimit }(callData);

        if (!success) {
            // Store failed mint for manual processing
            emit CallbackFailed(internalRequestId, _getRevertReason(returnData), gasConfig.emergencyGasLimit);

            // Don't revert - allow callback to complete
            // Failed mints can be processed manually later
        }
    }

    /// @notice Calculate optimal gas limit based on request complexity
    function _calculateOptimalGasLimit(bytes memory basketData) internal view returns (uint64) {
        uint256 dataSize = basketData.length;

        if (dataSize < 100) {
            return gasConfig.minGasLimit;
        } else if (dataSize > 500) {
            return gasConfig.maxGasLimit;
        } else {
            // Scale between min and max based on data size
            uint256 scaledGas =
                gasConfig.minGasLimit + ((dataSize - 100) * (gasConfig.maxGasLimit - gasConfig.minGasLimit)) / 400;
            return uint64(scaledGas);
        }
    }

    /// @notice Handle submission failures
    function _handleSubmissionFailure(string memory reason) internal {
        failureCount++;
        lastFailureTime = block.timestamp;

        if (failureCount >= MAX_FAILURES) {
            processingPaused = true;
            emit CircuitBreakerTripped(failureCount, block.timestamp);
        }
    }

    /// @notice Handle callback failures
    function _handleCallbackFailure(uint256 requestId, string memory reason, uint256 gasUsed) internal {
        failureCount++;
        lastFailureTime = block.timestamp;

        emit CallbackFailed(requestId, reason, gasUsed);

        if (failureCount >= MAX_FAILURES) {
            processingPaused = true;
            emit CircuitBreakerTripped(failureCount, block.timestamp);
        }
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
    function updateGasConfig(uint64 minGasLimit, uint64 maxGasLimit, uint64 defaultGasLimit, uint64 emergencyGasLimit)
        external
        onlyOwner
    {
        gasConfig = GasConfig(minGasLimit, maxGasLimit, defaultGasLimit, emergencyGasLimit);
    }

    function setAuthorizedCaller(address caller, bool authorized) external onlyOwner {
        if (caller == address(0)) revert ZeroAddressCaller();
        authorizedCallers[caller] = authorized;
    }

    function setAuthorizedManualProcessor(address processor, bool authorized) external onlyOwner {
        if (processor == address(0)) revert ZeroAddressCaller();
        authorizedManualProcessors[processor] = authorized;
    }

    function updateModelId(uint256 newModelId) external onlyOwner {
        if (newModelId == 0) revert InvalidModelId();
        modelId = newModelId;
    }

    function updateOracleFee(uint256 newOracleFee) external onlyOwner {
        oracleFee = newOracleFee;
    }

    function updateFlatFee(uint256 newFee) external onlyOwner {
        flatFee = newFee;
    }

    function updatePromptTemplate(string calldata newTemplate) external onlyOwner {
        if (bytes(newTemplate).length == 0 || bytes(newTemplate).length > 200) revert InvalidPromptTemplate();
        promptTemplate = newTemplate;
    }

    /// @notice Utility functions (same as original)
    function _createPrompt(bytes memory basketData, uint256 collateralValue) internal view returns (string memory) {
        return string(
            abi.encodePacked(
                promptTemplate, " Value: $", _uint2str(collateralValue / 1e18), " Data: ", string(basketData)
            )
        );
    }

    function _parseResponse(string memory response) internal pure returns (uint256 ratio, uint256 confidence) {
        // Same parsing logic as original
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

    // Helper functions (same as original)
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
        return requests[internalRequestId];
    }

    function getRequestByHash(bytes32 requestHash) external view returns (RequestInfo memory) {
        uint256 internalRequestId = requestsByHash[requestHash];
        return requests[internalRequestId];
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
}
