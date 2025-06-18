// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/// @title MockChainlinkFunctionsRouter - Mock for testing Chainlink Functions
/// @notice Simulates Chainlink Functions router behavior for testing
contract MockChainlinkFunctionsRouter {
    uint256 private requestCounter = 1;

    mapping(bytes32 => address) public requestCallbacks;
    mapping(uint256 => bytes32) public internalToChainlinkId; // Track internal ID to Chainlink ID mapping

    event RequestSent(bytes32 indexed id);

    /// @notice Mock sendRequest function
    function sendRequest(
        uint64, // subscriptionId
        bytes calldata, // data
        uint16, // dataVersion
        uint32, // callbackGasLimit
        bytes32 // donId
    ) external returns (bytes32 requestId) {
        requestId = keccak256(abi.encodePacked(block.timestamp, requestCounter));
        requestCallbacks[requestId] = msg.sender;
        
        // Store mapping of internal ID to Chainlink ID
        internalToChainlinkId[requestCounter] = requestId;
        
        requestCounter++;

        emit RequestSent(requestId);
        return requestId;
    }

    /// @notice Simulate callback for testing
    function simulateCallback(uint256 internalRequestId, bytes memory response, bytes memory err) external {
        // Get the actual Chainlink request ID
        bytes32 requestId = internalToChainlinkId[internalRequestId];
        
        if (requestId == bytes32(0)) {
            revert("Request ID not found");
        }
        
        address callback = requestCallbacks[requestId];

        if (callback != address(0)) {
            // Call the handleOracleFulfillment function (correct Chainlink Functions method)
            (bool success,) =
                callback.call(abi.encodeWithSignature("handleOracleFulfillment(bytes32,bytes,bytes)", requestId, response, err));
            require(success, "Callback failed");
        }
    }
}
 