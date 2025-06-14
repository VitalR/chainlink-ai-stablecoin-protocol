// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { IAIOracle } from "./interfaces/IAIOracle.sol";
import { OwnedThreeStep } from "@solbase/auth/OwnedThreeStep.sol";

/// @title AISimplePromptController - Event-Based ORA Integration
/// @notice Manages AI requests using SimplePrompt pattern - emits events instead of callbacks
/// @dev This contract only submits requests and emits results, business logic handled off-chain
contract AISimplePromptController is OwnedThreeStep {
    /// @notice Custom errors
    error UnauthorizedCaller();
    error ZeroAddressCaller();
    error InsufficientFee();
    error InvalidModelId();
    error InvalidPromptTemplate();

    /// @notice Configuration
    uint256 public modelId = 11; // Default Llama3 8B model
    uint64 public callbackGasLimit = 200_000; // Lower gas limit since we only emit events
    uint256 public flatFee = 0; // Additional flat fee
    uint256 public oracleFee = 0.01 ether; // Configurable oracle fee

    /// @notice ORA Oracle interface
    IAIOracle public immutable oraOracle;

    /// @notice Authorized callers (vaults)
    mapping(address => bool) public authorizedCallers;

    /// @notice Request tracking
    mapping(uint256 => RequestInfo) public requests;
    uint256 private requestCounter = 1;

    /// @notice Request information for tracking
    struct RequestInfo {
        address vault;
        address user;
        bytes basketData;
        uint256 collateralValue;
        uint256 timestamp;
        uint256 internalRequestId;
    }

    /// @notice Events - Core SimplePrompt pattern
    event AIRequestSubmitted(
        uint256 indexed internalRequestId,
        uint256 indexed oracleRequestId,
        address indexed user,
        address vault,
        string prompt
    );

    /// @notice Event emitted when AI result is received (SimplePrompt pattern)
    event AIResult(
        uint256 indexed oracleRequestId, uint256 indexed internalRequestId, bytes output, bytes callbackData
    );

    /// @notice Configuration events
    event AuthorizedCallerUpdated(address indexed caller, bool authorized);
    event ModelIdUpdated(uint256 modelId);
    event OracleFeeUpdated(uint256 oracleFee);
    event FlatFeeUpdated(uint256 flatFee);
    event PromptTemplateUpdated(string newTemplate);

    /// @notice Prompt template for AI requests
    string public promptTemplate =
        "Analyze this DeFi collateral basket for OPTIMAL LOW ratio. Maximize capital efficiency while ensuring safety. Consider volatility, correlation, liquidity. Respond: RATIO:XXX CONFIDENCE:YY (130-170%, 0-100%).";

    /// @notice Initialize the contract
    constructor(address _oracle, uint256 _modelId, uint64 _callbackGasLimit, uint256 _oracleFee)
        OwnedThreeStep(msg.sender)
    {
        oraOracle = IAIOracle(_oracle);
        modelId = _modelId;
        callbackGasLimit = _callbackGasLimit;
        oracleFee = _oracleFee;
    }

    /// @notice Estimate total fee required for AI request
    function estimateTotalFee() public view returns (uint256) {
        return oracleFee + flatFee;
    }

    /// @notice Submit AI request using SimplePrompt pattern
    /// @param user The user who deposited collateral
    /// @param basketData Encoded collateral basket information
    /// @param collateralValue Total USD value of collateral
    /// @return internalRequestId Our internal identifier for tracking
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

        // Prepare callback data for event emission
        bytes memory callbackData = abi.encode(msg.sender, user, basketData, collateralValue, internalRequestId);

        // Submit to ORA using SimplePrompt pattern
        uint256 oracleRequestId = oraOracle.requestCallback{ value: requiredFee }(
            modelId, input, address(this), callbackGasLimit, callbackData
        );

        // Store request info for tracking
        requests[internalRequestId] = RequestInfo({
            vault: msg.sender,
            user: user,
            basketData: basketData,
            collateralValue: collateralValue,
            timestamp: block.timestamp,
            internalRequestId: internalRequestId
        });

        emit AIRequestSubmitted(internalRequestId, oracleRequestId, user, msg.sender, prompt);

        // Refund excess
        if (msg.value > requiredFee) {
            payable(msg.sender).transfer(msg.value - requiredFee);
        }

        return internalRequestId;
    }

    /// @notice ORA callback - SimplePrompt pattern (only emits events)
    /// @dev This is called by ORA when AI processing completes
    /// @param requestId The oracle request ID
    /// @param output AI model output
    /// @param callbackData Encoded callback data
    function aiOracleCallback(uint256 requestId, bytes calldata output, bytes calldata callbackData) external {
        // Verify caller is ORA oracle
        require(msg.sender == address(oraOracle), "Only oracle can call");

        // Decode callback data to get internal request ID
        (,,,, uint256 internalRequestId) = abi.decode(callbackData, (address, address, bytes, uint256, uint256));

        // Emit result event - this is the core of SimplePrompt pattern
        emit AIResult(requestId, internalRequestId, output, callbackData);
    }

    /// @notice Create AI prompt for risk assessment
    function _createPrompt(bytes memory basketData, uint256 collateralValue) internal view returns (string memory) {
        return string(
            abi.encodePacked(
                promptTemplate, " Value: $", _uint2str(collateralValue / 1e18), " Data: ", string(basketData)
            )
        );
    }

    /// @notice Helper function to convert uint256 to string
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

    /// @notice Update oracle fee
    function updateOracleFee(uint256 newOracleFee) external onlyOwner {
        oracleFee = newOracleFee;
        emit OracleFeeUpdated(newOracleFee);
    }

    /// @notice Update flat fee
    function updateFlatFee(uint256 newFee) external onlyOwner {
        flatFee = newFee;
        emit FlatFeeUpdated(newFee);
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
    function getRequestInfo(uint256 internalRequestId) external view returns (RequestInfo memory) {
        return requests[internalRequestId];
    }
}
