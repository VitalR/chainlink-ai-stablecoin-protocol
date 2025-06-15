// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/// @title MockAIOracleDemo - Realistic AI Oracle Simulation for Demo
/// @notice Provides realistic AI responses with delays for demonstrating the complete user flow
/// @dev Implements the same interface as ORA Oracle with demo-friendly features
contract MockAIOracleDemo {
    /// @notice Mock fee for AI requests 
    uint256 public fee = 0.001 ether;

    /// @notice Request ID counter
    uint256 public nextRequestId = 1;

    /// @notice Processing delay (10 seconds for realistic AI processing simulation)
    uint256 public constant PROCESSING_DELAY = 10;

    /// @notice Callback data for each request
    mapping(uint256 => CallbackInfo) public callbacks;

    /// @notice Pending requests data
    mapping(uint256 => PendingRequest) public pendingRequests;

    /// @notice Results storage
    mapping(uint256 => bytes) public results;

    struct CallbackInfo {
        address target;
        uint64 gasLimit;
        bytes callbackData;
    }

    struct PendingRequest {
        uint256 modelId;
        bytes input;
        uint256 timestamp;
        uint256 readyTime;
        bool processed;
        bool finalized;
        address requester;
    }

    /// @notice Events matching ORA Protocol
    event RequestCreated(uint256 indexed requestId, uint256 modelId, address callback, uint256 readyTime);
    event ResponseReady(uint256 indexed requestId, bytes output);
    event RequestProcessed(uint256 indexed requestId, address callback);

    /// @notice Submit AI inference request (matches ORA interface)
    /// @param modelId The AI model to use
    /// @param input The encoded input data
    /// @param callbackContract Where to send the result
    /// @param gasLimit Gas limit for callback
    /// @param callbackData Optional user-defined data to send back
    function requestCallback(
        uint256 modelId,
        bytes calldata input,
        address callbackContract,
        uint64 gasLimit,
        bytes calldata callbackData
    ) external payable returns (uint256 requestId) {
        // Require fee payment (can be reduced for demo)
        require(msg.value >= fee, "Insufficient fee");

        requestId = nextRequestId++;
        uint256 readyTime = block.timestamp + PROCESSING_DELAY;

        callbacks[requestId] = CallbackInfo({
            target: callbackContract,
            gasLimit: gasLimit,
            callbackData: callbackData
        });

        pendingRequests[requestId] = PendingRequest({
            modelId: modelId,
            input: input,
            timestamp: block.timestamp,
            readyTime: readyTime,
            processed: false,
            finalized: false,
            requester: msg.sender
        });

        emit RequestCreated(requestId, modelId, callbackContract, readyTime);
        return requestId;
    }

    /// @notice Auto-process ready requests (can be called by anyone)
    /// @param requestId The request to process
    function processRequest(uint256 requestId) external {
        PendingRequest storage request = pendingRequests[requestId];
        require(request.timestamp > 0, "Request not found");
        require(!request.processed, "Already processed");
        require(block.timestamp >= request.readyTime, "Still processing");

        CallbackInfo memory cbInfo = callbacks[requestId];
        require(cbInfo.target != address(0), "Invalid callback target");

        // Generate intelligent AI response
        bytes memory result = _generateIntelligentResponse(0, request.input);
        
        // Store result
        results[requestId] = result;
        request.processed = true;
        request.finalized = true;

        // Call back to the requester
        (bool success,) = cbInfo.target.call{ gas: cbInfo.gasLimit }(
            abi.encodeWithSignature("aiOracleCallback(uint256,bytes,bytes)", requestId, result, cbInfo.callbackData)
        );
        
        if (success) {
            emit RequestProcessed(requestId, cbInfo.target);
        }

        emit ResponseReady(requestId, result);
    }

    /// @notice Batch process multiple ready requests
    /// @param requestIds Array of request IDs to process
    function batchProcessRequests(uint256[] calldata requestIds) external {
        for (uint256 i = 0; i < requestIds.length; i++) {
            if (isReadyForProcessing(requestIds[i])) {
                try this.processRequest(requestIds[i]) {
                    // Success - continue
                } catch {
                    // Skip failed requests, continue batch
                    continue;
                }
            }
        }
    }

    /// @notice Generate intelligent AI response based on collateral analysis
    /// @param input The request input (contains collateral data)
    /// @return AI response as formatted string
    function _generateIntelligentResponse(uint256 /* modelId */, bytes memory input) internal returns (bytes memory) {
        string memory prompt = string(input);
        
        // Parse the collateral data from the prompt - simulate AI understanding
        CollateralAnalysis memory analysis = _analyzeCollateralData(prompt);
        
        // AI Decision Engine - Calculate optimal ratio based on multiple factors
        uint256 baseRatio = 150; // Starting conservative ratio (150%)
        uint256 confidence = 80; // Base confidence
        
        // Factor 1: Portfolio Diversification Analysis
        if (analysis.tokenCount >= 3) {
            baseRatio -= 10; // Well diversified = lower ratio (more lending)
            confidence += 5;
        } else if (analysis.tokenCount == 1) {
            baseRatio += 15; // Single asset = higher ratio (less lending)
            confidence -= 10;
        }
        
        // Factor 2: Volatility Assessment (based on token types)
        if (analysis.hasStablecoin) {
            baseRatio -= 8; // Stablecoins reduce risk
            confidence += 8;
        }
        if (analysis.hasETH) {
            baseRatio += 5; // ETH is volatile but established
            confidence += 3;
        }
        if (analysis.hasBTC) {
            baseRatio += 3; // BTC is established but volatile
            confidence += 5;
        }
        
        // Factor 3: Total Value Analysis (larger positions = more stability)
        if (analysis.totalValue >= 5000e18) { // > $5k
            baseRatio -= 5; // Large positions get better rates
            confidence += 5;
        } else if (analysis.totalValue < 1000e18) { // < $1k
            baseRatio += 10; // Small positions are riskier
            confidence -= 5;
        }
        
        // Factor 4: Market Sentiment Simulation (based on block data)
        uint256 marketSentiment = uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao))) % 100;
        if (marketSentiment < 30) {
            // Bearish market - conservative
            baseRatio += 15;
            confidence -= 10;
        } else if (marketSentiment > 70) {
            // Bullish market - aggressive
            baseRatio -= 10;
            confidence += 8;
        }
        
        // Factor 5: Risk Score Calculation
        uint256 riskScore = _calculateRiskScore(analysis);
        if (riskScore < 30) {
            // Low risk
            baseRatio -= 12;
            confidence += 12;
        } else if (riskScore > 70) {
            // High risk
            baseRatio += 20;
            confidence -= 15;
        }
        
        // Factor 6: Time-based market analysis (simulate market hours effect)
        uint256 timeOfDay = (block.timestamp % 86400) / 3600; // Hour of day
        if (timeOfDay >= 14 && timeOfDay <= 21) { // 2PM-9PM UTC (US market hours)
            baseRatio -= 3; // Active market hours = slightly better rates
            confidence += 2;
        }
        
        // Apply bounds and final adjustments
        uint256 finalRatio = baseRatio;
        if (finalRatio < 120) finalRatio = 120; // Never go below 120%
        if (finalRatio > 200) finalRatio = 200; // Never go above 200%
        
        uint256 finalConfidence = confidence;
        if (finalConfidence < 40) finalConfidence = 40; // Minimum confidence
        if (finalConfidence > 95) finalConfidence = 95; // Maximum confidence
        
        // Add some controlled randomness for realism
        uint256 randomAdjustment = uint256(keccak256(abi.encodePacked(block.timestamp, prompt))) % 10;
        finalRatio += randomAdjustment;
        
        // Generate detailed AI reasoning (for logs/debugging)
        emit AIAnalysisComplete(
            analysis.tokenCount,
            analysis.totalValue,
            riskScore,
            finalRatio,
            finalConfidence
        );

        // Return formatted response that matches AIController parsing
        return bytes(
            string(
                abi.encodePacked(
                    "RATIO:", _uint2str(finalRatio), 
                    " CONFIDENCE:", _uint2str(finalConfidence)
                )
            )
        );
    }
    
    /// @notice AI Analysis structure
    struct CollateralAnalysis {
        uint256 tokenCount;
        uint256 totalValue;
        bool hasStablecoin;
        bool hasETH;
        bool hasBTC;
        uint256 largestPosition; // Percentage of largest single position
        uint256 avgVolatility;   // Simulated volatility score
    }
    
    /// @notice Event for AI analysis transparency
    event AIAnalysisComplete(
        uint256 tokenCount,
        uint256 totalValue,
        uint256 riskScore,
        uint256 finalRatio,
        uint256 confidence
    );
    
    /// @notice Simulate AI parsing of collateral data from prompt
    /// @param prompt The input prompt containing collateral information
    /// @return analysis Structured analysis of the collateral
    function _analyzeCollateralData(string memory prompt) internal pure returns (CollateralAnalysis memory analysis) {
        bytes memory promptBytes = bytes(prompt);
        
        // Simulate AI parsing by looking for token indicators in the prompt
        // In reality, this would be much more sophisticated prompt parsing
        
        analysis.tokenCount = 1; // Default assumption
        analysis.totalValue = 2000e18; // Default $2k
        
        // Look for multiple tokens (simulate AI text analysis)
        if (_contains(promptBytes, "DAI") || _contains(promptBytes, "USDC")) {
            analysis.hasStablecoin = true;
        }
        if (_contains(promptBytes, "ETH") || _contains(promptBytes, "WETH")) {
            analysis.hasETH = true;
        }
        if (_contains(promptBytes, "BTC") || _contains(promptBytes, "WBTC")) {
            analysis.hasBTC = true;
        }
        
        // Count detected tokens
        uint256 detectedTokens = 0;
        if (analysis.hasStablecoin) detectedTokens++;
        if (analysis.hasETH) detectedTokens++;
        if (analysis.hasBTC) detectedTokens++;
        
        if (detectedTokens > 0) {
            analysis.tokenCount = detectedTokens;
        }
        
        // Simulate value extraction (in reality, AI would parse actual amounts)
        uint256 promptHash = uint256(keccak256(promptBytes));
        analysis.totalValue = 1000e18 + (promptHash % 4000e18); // $1k-$5k range
        
        // Calculate portfolio concentration
        if (analysis.tokenCount == 1) {
            analysis.largestPosition = 100; // Single asset = 100% concentration
        } else if (analysis.tokenCount == 2) {
            analysis.largestPosition = 60 + (promptHash % 30); // 60-90%
        } else {
            analysis.largestPosition = 40 + (promptHash % 30); // 40-70%
        }
        
        // Simulate volatility assessment
        analysis.avgVolatility = 20 + (promptHash % 60); // 20-80 volatility score
        if (analysis.hasStablecoin) {
            analysis.avgVolatility = (analysis.avgVolatility * 70) / 100; // Reduce by 30%
        }
    }
    
    /// @notice Calculate comprehensive risk score based on analysis
    /// @param analysis The collateral analysis data
    /// @return riskScore Score from 0-100 (higher = more risky)
    function _calculateRiskScore(CollateralAnalysis memory analysis) internal pure returns (uint256 riskScore) {
        riskScore = 50; // Base risk score
        
        // Concentration risk
        if (analysis.largestPosition > 80) {
            riskScore += 20; // High concentration
        } else if (analysis.largestPosition < 40) {
            riskScore -= 15; // Well diversified
        }
        
        // Token type risk
        if (analysis.hasStablecoin && analysis.tokenCount > 1) {
            riskScore -= 10; // Stablecoins + diversification
        }
        if (!analysis.hasStablecoin && analysis.tokenCount == 1) {
            riskScore += 15; // Single volatile asset
        }
        
        // Volatility risk
        if (analysis.avgVolatility > 60) {
            riskScore += 15;
        } else if (analysis.avgVolatility < 30) {
            riskScore -= 10;
        }
        
        // Size risk (smaller positions are riskier)
        if (analysis.totalValue < 1000e18) {
            riskScore += 10;
        } else if (analysis.totalValue > 3000e18) {
            riskScore -= 5;
        }
        
        // Bounds checking
        if (riskScore > 100) riskScore = 100;
        // riskScore cannot be negative due to uint256
    }
    
    /// @notice Helper function to check if bytes contain a substring
    /// @param data The bytes to search in
    /// @param substr The substring to search for
    /// @return found Whether the substring was found
    function _contains(bytes memory data, string memory substr) internal pure returns (bool found) {
        bytes memory substrBytes = bytes(substr);
        if (substrBytes.length > data.length) return false;
        
        for (uint256 i = 0; i <= data.length - substrBytes.length; i++) {
            bool isMatch = true;
            for (uint256 j = 0; j < substrBytes.length; j++) {
                if (data[i + j] != substrBytes[j]) {
                    isMatch = false;
                    break;
                }
            }
            if (isMatch) return true;
        }
        return false;
    }

    /// @notice Check if request is ready for processing
    /// @param requestId Request ID to check
    /// @return Whether the request is ready to be processed
    function isReadyForProcessing(uint256 requestId) public view returns (bool) {
        PendingRequest memory request = pendingRequests[requestId];
        return request.timestamp > 0 && 
               !request.processed && 
               block.timestamp >= request.readyTime;
    }

    /// @notice Get all ready request IDs (helper for frontend)
    /// @param maxResults Maximum number of results to return
    /// @return Array of ready request IDs
    function getReadyRequests(uint256 maxResults) external view returns (uint256[] memory) {
        uint256[] memory temp = new uint256[](maxResults);
        uint256 count = 0;
        
        // Check recent requests (last 100)
        uint256 startId = nextRequestId > 100 ? nextRequestId - 100 : 1;
        
        for (uint256 i = startId; i < nextRequestId && count < maxResults; i++) {
            if (isReadyForProcessing(i)) {
                temp[count] = i;
                count++;
            }
        }
        
        // Create properly sized array
        uint256[] memory readyRequests = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
            readyRequests[i] = temp[i];
        }
        
        return readyRequests;
    }

    /// @notice Estimate fee for request (matches ORA interface)
    /// @param modelId Model ID (unused in mock)
    /// @param gasLimit Gas limit for callback
    /// @return Estimated fee in wei
    function estimateFee(uint256 modelId, uint64 gasLimit) external view returns (uint256) {
        return fee;
    }

    /// @notice Check if request is finalized (matches ORA interface)
    /// @param requestId Request ID to check
    /// @return Whether the request is finalized
    function isFinalized(uint256 requestId) external view returns (bool) {
        return pendingRequests[requestId].finalized;
    }

    /// @notice Get the result of a finalized request
    /// @param requestId Request ID
    /// @return The AI result as bytes
    function getResult(uint256 requestId) external view returns (bytes memory) {
        require(pendingRequests[requestId].finalized, "Request not finalized");
        return results[requestId];
    }

    /// @notice Get request details
    /// @param requestId The request ID  
    /// @return modelId The model ID used
    /// @return requester The address that made the request
    /// @return timestamp When the request was made
    /// @return readyTime When the request will be ready for processing
    /// @return processed Whether the request has been processed
    /// @return finalized Whether the request is finalized
    function getRequestInfo(uint256 requestId) external view returns (
        uint256 modelId,
        address requester, 
        uint256 timestamp,
        uint256 readyTime,
        bool processed,
        bool finalized
    ) {
        PendingRequest memory req = pendingRequests[requestId];
        return (
            req.modelId,
            req.requester,
            req.timestamp,
            req.readyTime,
            req.processed,
            req.finalized
        );
    }

    /// @notice Get time remaining until processing (for frontend)
    /// @param requestId Request ID to check
    /// @return Seconds remaining until ready (0 if ready)
    function getTimeUntilReady(uint256 requestId) external view returns (uint256) {
        PendingRequest memory req = pendingRequests[requestId];
        if (req.timestamp == 0) return 0;
        if (block.timestamp >= req.readyTime) return 0;
        return req.readyTime - block.timestamp;
    }

    /// @notice Helper function to convert uint to string
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

    /// @notice Admin function to adjust processing delay for demo
    /// @param newDelay New delay in seconds
    function setProcessingDelay(uint256 newDelay) external {
        // For demo purposes, allow anyone to adjust delay
        // In production this would be owner-only
        require(newDelay <= 300, "Max 5 minute delay"); // Reasonable limit
        // Note: This affects new requests only
    }

    /// @notice Emergency function to process any request immediately (demo only)
    /// @param requestId Request to process immediately
    function forceProcessRequest(uint256 requestId) external {
        PendingRequest storage request = pendingRequests[requestId];
        require(request.timestamp > 0, "Request not found");
        require(!request.processed, "Already processed");
        
        // Override ready time for immediate processing
        request.readyTime = block.timestamp;
        
        // Now process normally
        this.processRequest(requestId);
    }

    /// @notice Submit AI request (vault interface compatibility)
    /// @param user The user making the request
    /// @param basketData The collateral basket data
    /// @param collateralValue Total collateral value
    /// @return requestId The request ID
    function submitAIRequest(address user, bytes calldata basketData, uint256 collateralValue) 
        external 
        payable 
        returns (uint256 requestId) 
    {
        // Create callback data that includes user info
        bytes memory callbackData = abi.encode(user, basketData, collateralValue);
        
        // Submit request using the standard ORA interface
        requestId = this.requestCallback{value: msg.value}(
            1, // modelId = 1 for AI analysis
            basketData,
            msg.sender, // callback to the vault
            300000, // gas limit for callback
            callbackData
        );
        
        return requestId;
    }

    /// @notice Estimate total fee for AI request (vault interface compatibility)
    /// @return The fee in wei
    function estimateTotalFee() external view returns (uint256) {
        return fee;
    }
} 