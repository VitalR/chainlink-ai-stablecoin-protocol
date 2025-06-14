// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { AIOracleCallbackReceiver } from "OAO/contracts/AIOracleCallbackReceiver.sol";
import { IAIOracle } from "OAO/contracts/IAIOracle.sol";
import { AIOracle } from "OAO/contracts/AIOracle.sol";
import { OwnedThreeStep } from "@solbase/auth/OwnedThreeStep.sol";

/// @title AIControllerCallback - Direct ORA OAO Integration with Callbacks
/// @notice Manages AI-driven collateral ratio optimization with automatic processing
contract AIControllerCallback is OwnedThreeStep, AIOracleCallbackReceiver {
    /// @notice Custom errors for access control
    error UnauthorizedCaller();
    error ZeroAddressCaller();

    /// @notice Custom errors for request handling
    error InsufficientFee();
    error RequestIdMismatch();
    error AlreadyProcessed();
    error RequestFailed();
    error CallbackFailed();

    /// @notice Custom errors for configuration
    error InvalidModelId();
    error InvalidFee();
    error InvalidPromptTemplate();

    /// @notice Mapping of authorized callers
    mapping(address => bool) public authorizedCallers;

    /// @notice State management - map internal request IDs to request info
    mapping(uint256 => RequestInfo) public requests;
    uint256 private requestCounter = 1;

    /// @notice Request information
    struct RequestInfo {
        address vault;
        address user;
        bytes basketData;
        uint256 collateralValue;
        uint256 timestamp;
        bool processed;
        uint256 internalRequestId; // Our internal ID for tracking
    }

    /// @notice Events
    event AIRequestSubmitted(
        uint256 indexed internalRequestId, uint256 indexed oracleRequestId, address indexed user, address vault
    );
    event AIResultProcessed(
        uint256 indexed internalRequestId,
        uint256 indexed oracleRequestId,
        uint256 ratio,
        uint256 confidence,
        uint256 mintAmount
    );
    event AuthorizedCallerUpdated(address indexed caller, bool authorized);
    event FeeUpdated(uint256 fee);
    event ModelIdUpdated(uint256 modelId);
    event PromptTemplateUpdated(string newTemplate);

    /// @notice Configuration
    uint256 public modelId = 11; // Default model
    uint64 public callbackGasLimit = 500_000; // Gas for callback
    uint256 public flatFee = 0; // Additional flat fee on top of oracle fee

    /// @notice Updateable prompt template for AI requests
    string public promptTemplate =
        "Analyze this DeFi collateral basket for OPTIMAL LOW ratio. Maximize capital efficiency while ensuring safety. Consider volatility, correlation, liquidity. Respond: RATIO:XXX CONFIDENCE:YY (130-170%, 0-100%).";

    /// @notice Initializes the contract
    constructor(address _oracle, uint256 _modelId, uint64 _callbackGasLimit)
        OwnedThreeStep(msg.sender)
        AIOracleCallbackReceiver(IAIOracle(_oracle))
    {
        modelId = _modelId;
        callbackGasLimit = _callbackGasLimit;
    }

    /// @notice Estimate total fee required for AI request
    /// @return Total fee including oracle fee and flat fee
    function estimateTotalFee() public view returns (uint256) {
        // Get the fee from the oracle contract
        return AIOracle(address(aiOracle)).fee() + flatFee;
    }

    /// @notice Submit AI request with automatic callback processing
    /// @param user The user who deposited collateral
    /// @param basketData Encoded collateral basket information
    /// @param collateralValue Total USD value of collateral
    /// @return internalRequestId Our internal identifier for this AI request
    function submitAIRequest(address user, bytes calldata basketData, uint256 collateralValue)
        external
        payable
        returns (uint256 internalRequestId)
    {
        if (!authorizedCallers[msg.sender]) revert UnauthorizedCaller();

        uint256 requiredFee = estimateTotalFee();
        if (msg.value < requiredFee) revert InsufficientFee();

        internalRequestId = requestCounter++;

        // Create AI prompt
        string memory prompt = _createPrompt(basketData, collateralValue);
        bytes memory input = bytes(prompt);

        // Submit to ORA OAO with callback
        aiOracle.requestCallback{ value: requiredFee }(
            modelId, input, address(this), this.aiOracleCallback.selector, callbackGasLimit
        );

        // Store request info using internal request ID as key (since we don't get oracle ID back)
        requests[internalRequestId] = RequestInfo({
            vault: msg.sender,
            user: user,
            basketData: basketData,
            collateralValue: collateralValue,
            timestamp: block.timestamp,
            processed: false,
            internalRequestId: internalRequestId
        });

        emit AIRequestSubmitted(internalRequestId, 0, user, msg.sender); // Oracle ID not available

        // Refund excess (ORA protocol pattern)
        if (msg.value > requiredFee) {
            payable(msg.sender).transfer(msg.value - requiredFee);
        }

        return internalRequestId;
    }

    /// @notice ORA callback - automatically processes AI result and triggers minting
    /// @dev This is called by ORA OAO when AI processing completes
    /// @param _modelId The model ID used
    /// @param input The input that was sent
    /// @param output AI model output
    function aiOracleCallback(uint256 _modelId, bytes calldata input, bytes calldata output)
        external
        onlyAIOracleCallback
    {
        // Find the matching request by input (since we don't have oracle request ID)
        uint256 matchingRequestId = _findRequestByInput(input);
        if (matchingRequestId == 0) revert RequestIdMismatch();

        RequestInfo storage request = requests[matchingRequestId];
        if (request.processed) revert AlreadyProcessed();

        // Parse AI response
        (uint256 ratio, uint256 confidence) = _parseResponse(string(output));

        // Apply benefit-focused safety bounds (130-170% range)
        ratio = _applySafetyBounds(ratio, confidence);

        // Calculate mint amount (ratio is in basis points)
        uint256 mintAmount = (request.collateralValue * 10_000) / ratio;

        // Mark as processed
        request.processed = true;

        // Automatically trigger minting in vault
        _triggerMinting(request.vault, request.user, matchingRequestId, mintAmount, ratio, confidence);

        emit AIResultProcessed(matchingRequestId, 0, ratio, confidence, mintAmount); // Oracle ID not available
    }

    /// @notice Find request by input data (helper function)
    function _findRequestByInput(bytes calldata input) internal view returns (uint256) {
        // Simple approach: iterate through recent requests to find matching input
        // In production, you might want a more efficient lookup mechanism
        for (uint256 i = 1; i < requestCounter; i++) {
            if (requests[i].timestamp > 0 && !requests[i].processed) {
                // Create expected prompt and compare
                bytes memory basketDataMemory = requests[i].basketData;
                string memory expectedPrompt = _createPrompt(basketDataMemory, requests[i].collateralValue);
                if (keccak256(input) == keccak256(bytes(expectedPrompt))) {
                    return i;
                }
            }
        }
        return 0;
    }

    /// @notice Check if a request has been processed (replaces isFinalized)
    /// @param internalRequestId Our internal request ID
    /// @return Whether the request has been processed
    function isRequestProcessed(uint256 internalRequestId) external view returns (bool) {
        return requests[internalRequestId].processed;
    }

    /// @notice Apply benefit-focused safety bounds (130-170% range)
    /// @dev Optimized for capital efficiency while maintaining reasonable safety
    function _applySafetyBounds(uint256 aiRatio, uint256 confidence) internal pure returns (uint256) {
        uint256 minRatio = 13_000; // 130% in basis points
        uint256 maxRatio = 17_000; // 170% in basis points

        // Adjust minimum based on confidence
        if (confidence < 60) {
            minRatio = 14_000; // 140% for very low confidence
        } else if (confidence < 80) {
            minRatio = 13_500; // 135% for medium confidence
        }
        // High confidence (80+): Use aggressive 130% minimum for maximum efficiency

        // Apply bounds
        if (aiRatio < minRatio) return minRatio;
        if (aiRatio > maxRatio) return maxRatio;

        return aiRatio;
    }

    /// @notice Create AI prompt for risk assessment
    function _createPrompt(bytes memory basketData, uint256 collateralValue) internal view returns (string memory) {
        // Emphasize capital efficiency and smart ratio optimization
        return string(
            abi.encodePacked(
                "Analyze this DeFi collateral basket for OPTIMAL LOW ratio. ",
                "Maximize capital efficiency while ensuring safety. ",
                "Consider volatility, correlation, liquidity. ",
                "Respond: RATIO:XXX CONFIDENCE:YY (130-170%, 0-100%). ",
                "Value: $",
                _uint2str(collateralValue / 1e18),
                " Data: ",
                string(basketData)
            )
        );
    }

    /// @notice Parse AI response for ratio and confidence
    function _parseResponse(string memory response) internal pure returns (uint256 ratio, uint256 confidence) {
        // Default values
        ratio = 15_000; // 150% in basis points
        confidence = 50;

        bytes memory data = bytes(response);

        // Parse RATIO:XXX
        for (uint256 i = 0; i < data.length - 6; i++) {
            if (_matches(data, i, "RATIO:")) {
                uint256 parsedRatio = _extractNumber(data, i + 6, 3);
                if (parsedRatio >= 125 && parsedRatio <= 200) {
                    ratio = parsedRatio * 100; // Convert to basis points
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

    /// @notice Trigger minting in the vault via callback
    function _triggerMinting(
        address vault,
        address user,
        uint256 internalRequestId,
        uint256 mintAmount,
        uint256 ratio,
        uint256 confidence
    ) internal {
        (bool success,) = vault.call(
            abi.encodeWithSignature(
                "processAICallback(address,uint256,uint256,uint256,uint256)",
                user,
                internalRequestId,
                mintAmount,
                ratio,
                confidence
            )
        );
        if (!success) revert CallbackFailed();
    }

    /// @notice Helper function to check if a pattern matches in a bytes array
    function _matches(bytes memory data, uint256 start, string memory pattern) internal pure returns (bool) {
        bytes memory p = bytes(pattern);
        if (start + p.length > data.length) return false;

        for (uint256 i = 0; i < p.length; i++) {
            if (data[start + i] != p[i]) return false;
        }
        return true;
    }

    /// @notice Helper function to extract a number from a bytes array
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

    /// @notice Helper function to convert a uint256 to a string
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

    /// @notice Set authorized caller
    function setAuthorizedCaller(address caller, bool authorized) external onlyOwner {
        if (caller == address(0)) revert ZeroAddressCaller();
        authorizedCallers[caller] = authorized;
        emit AuthorizedCallerUpdated(caller, authorized);
    }

    /// @notice Update model ID
    function updateModelId(uint256 newModelId) external onlyOwner {
        if (newModelId == 0) revert InvalidModelId();
        modelId = newModelId;
        emit ModelIdUpdated(newModelId);
    }

    /// @notice Update flat fee
    function updateFlatFee(uint256 newFee) external onlyOwner {
        flatFee = newFee;
        emit FeeUpdated(newFee);
    }

    /// @notice Update callback gas limit
    function updateCallbackGasLimit(uint64 newGasLimit) external onlyOwner {
        callbackGasLimit = newGasLimit;
    }

    /// @notice Update prompt template
    function updatePromptTemplate(string calldata newTemplate) external onlyOwner {
        if (bytes(newTemplate).length == 0 || bytes(newTemplate).length > 200) revert InvalidPromptTemplate();
        promptTemplate = newTemplate;
        emit PromptTemplateUpdated(newTemplate);
    }

    /// @notice Get request info by internal request ID
    /// @param internalRequestId Our internal request ID
    /// @return Request information
    function getRequestInfo(uint256 internalRequestId) external view returns (RequestInfo memory) {
        return requests[internalRequestId];
    }
}
