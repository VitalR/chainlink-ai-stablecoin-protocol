// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/// @title MockAIOracle - Simulates ORA OAO for Testing
/// @notice Provides deterministic AI responses for testing the full flow
/// @dev Implements the same interface as ORA Oracle
contract MockAIOracle {
    /// @notice Mock fee for AI requests (matches real AIOracle)
    uint256 public fee = 0.001 ether;

    /// @notice Request ID counter
    uint256 public nextRequestId = 1;

    /// @notice Callback data for each request
    mapping(uint256 => CallbackInfo) public callbacks;

    /// @notice Pending requests data
    mapping(uint256 => PendingRequest) public pendingRequests;

    struct CallbackInfo {
        address target;
        bytes4 functionSelector;
        uint64 gasLimit;
        bytes callbackData;
    }

    struct PendingRequest {
        uint256 modelId;
        bytes input;
        uint256 timestamp;
        bool processed;
        bool finalized;
    }

    /// @notice Events matching ORA Protocol
    event RequestCreated(uint256 indexed requestId, uint256 modelId, address callback);
    event ResponseReady(uint256 indexed requestId, bytes output);

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
        requestId = nextRequestId++;

        callbacks[requestId] = CallbackInfo({
            target: callbackContract,
            functionSelector: bytes4(keccak256("aiOracleCallback(uint256,bytes,bytes)")),
            gasLimit: gasLimit,
            callbackData: callbackData
        });

        pendingRequests[requestId] = PendingRequest({
            modelId: modelId,
            input: input,
            timestamp: block.timestamp,
            processed: false,
            finalized: false
        });

        emit RequestCreated(requestId, modelId, callbackContract);
        return requestId;
    }

    /// @notice Simulate AI processing (callable by anyone for demo)
    /// @param requestId The request to process
    function processRequest(uint256 requestId) external {
        PendingRequest storage request = pendingRequests[requestId];
        require(!request.processed, "Already processed");
        require(callbacks[requestId].target != address(0), "Invalid request");

        // Generate mock AI response
        bytes memory result = _generateMockResponse(request.modelId, request.input);

        request.processed = true;
        request.finalized = true;

        CallbackInfo memory cbInfo = callbacks[requestId];

        // Call back to the requester using aiOracleCallback
        (bool success,) = cbInfo.target.call{ gas: cbInfo.gasLimit }(
            abi.encodeWithSelector(cbInfo.functionSelector, requestId, result, cbInfo.callbackData)
        );
        require(success, "Callback failed");

        emit ResponseReady(requestId, result);
    }

    /// @notice Generate deterministic AI response based on input
    /// @param modelId The model type
    /// @param input The request input (prompt string)
    /// @return AI response as string
    function _generateMockResponse(uint256 modelId, bytes memory input) internal view returns (bytes memory) {
        string memory prompt = string(input);

        // Parse the prompt to extract value information
        uint256 mockRatio;
        uint256 mockConfidence;

        // Simulate AI decision based on "market conditions"
        uint256 randomness = uint256(keccak256(abi.encodePacked(block.timestamp, prompt))) % 100;

        if (randomness < 30) {
            // Good market conditions - aggressive ratio
            mockRatio = 135; // 135%
            mockConfidence = 90;
        } else if (randomness < 70) {
            // Normal conditions
            mockRatio = 150; // 150%
            mockConfidence = 80;
        } else {
            // Conservative conditions
            mockRatio = 165; // 165%
            mockConfidence = 70;
        }

        // Return formatted response that matches expected parsing
        return
            bytes(string(abi.encodePacked("RATIO:", _uint2str(mockRatio), " CONFIDENCE:", _uint2str(mockConfidence))));
    }

    /// @notice Estimate fee for request (matches ORA interface)
    /// @param modelId Model ID
    /// @param gasLimit Gas limit for callback
    /// @return Estimated fee in wei
    function estimateFee(uint256 modelId, uint64 gasLimit) external pure returns (uint256) {
        // Mock fee calculation
        return 0.001 ether + (gasLimit * 1 gwei);
    }

    /// @notice Check if request is finalized (matches ORA interface)
    /// @param requestId Request ID to check
    /// @return Whether the request is finalized
    function isFinalized(uint256 requestId) external view returns (bool) {
        return pendingRequests[requestId].finalized;
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

    /// @notice Get request details (for debugging)
    function getRequest(uint256 requestId)
        external
        view
        returns (uint256 modelId, address callback, uint256 timestamp, bool processed)
    {
        PendingRequest memory req = pendingRequests[requestId];
        return (req.modelId, callbacks[requestId].target, req.timestamp, req.processed);
    }
}
