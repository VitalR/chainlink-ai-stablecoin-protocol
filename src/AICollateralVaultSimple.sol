// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { IERC20 } from "@openzeppelin/token/ERC20/IERC20.sol";
import { OwnedThreeStep } from "@solbase/auth/OwnedThreeStep.sol";
import { AISimplePromptController } from "./AISimplePromptController.sol";
import { AIStablecoin } from "./AIStablecoin.sol";

/// @title IAIStablecoin Interface
interface IAIStablecoin {
    function mint(address to, uint256 amount) external;
    function burn(uint256 amount) external;
    function burnFrom(address account, uint256 amount) external;
}

/// @title IAISimplePromptController Interface
interface IAISimplePromptController {
    function submitAIRequest(address user, bytes calldata basketData, uint256 collateralValue)
        external
        payable
        returns (uint256 requestId);
}

/// @title AICollateralVaultSimple - SimplePrompt Pattern Vault
/// @notice Manages collateral deposits with event-based AI processing
/// @dev Uses SimplePrompt pattern - deposits create pending positions, off-chain agent finalizes mints
contract AICollateralVaultSimple is OwnedThreeStep {
    /// @notice Core contract interfaces
    IAIStablecoin public aiusd;
    IAISimplePromptController public aiController;

    /// @notice Token information
    struct TokenInfo {
        uint256 priceUSD; // Price in USD with 18 decimals
        uint8 decimals; // Token decimals
        bool supported; // Whether token is currently accepted
    }

    /// @notice User position information
    struct Position {
        address[] tokens; // Array of deposited token addresses
        uint256[] amounts; // Corresponding amounts of each token
        uint256 totalValueUSD; // Total value in USD (18 decimals)
        uint256 aiusdMinted; // Amount of AIUSD minted against position
        uint256 collateralRatio; // Current collateral ratio in basis points
        uint256 requestId; // ID of the AI assessment request
        bool hasPendingRequest; // Whether an AI assessment is in progress
        uint256 timestamp; // When the position was created
    }

    /// @notice Pending mint information (for SimplePrompt pattern)
    struct PendingMint {
        address user;
        uint256 requestId;
        uint256 mintAmount;
        uint256 ratio;
        uint256 confidence;
        uint256 timestamp;
        bool processed;
    }

    /// @notice Mappings
    mapping(address => TokenInfo) public supportedTokens;
    mapping(address => Position) public positions;
    mapping(uint256 => PendingMint) public pendingMints;
    mapping(address => string) private tokenSymbols;

    /// @notice Authorized processors (off-chain agents or processor contracts)
    mapping(address => bool) public authorizedProcessors;

    /// @notice Configuration
    uint256 public constant TIMEOUT_PERIOD = 1 hours; // Time after which users can cancel
    uint256 public constant MIN_CONFIDENCE = 50; // Minimum confidence threshold

    /// @notice Events
    event CollateralDeposited(address indexed user, address[] tokens, uint256[] amounts, uint256 totalValue);
    event AIRequestSubmitted(address indexed user, uint256 indexed requestId, uint256 collateralValue);
    event PendingMintCreated(uint256 indexed requestId, address indexed user, uint256 mintAmount, uint256 ratio);
    event AIUSDMinted(address indexed user, uint256 amount, uint256 ratio, uint256 confidence);
    event CollateralWithdrawn(address indexed user, uint256 amount);
    event TokenAdded(address indexed token, uint256 priceUSD, uint8 decimals);
    event TokenPriceUpdated(address indexed token, uint256 newPriceUSD);
    event ProcessorUpdated(address indexed processor, bool authorized);
    event RequestCancelled(address indexed user, uint256 indexed requestId);
    event RequestTimeout(address indexed user, uint256 indexed requestId);

    /// @notice Custom errors
    error TokenNotSupported();
    error InsufficientAIUSD();
    error NoPosition();
    error PendingAIRequest();
    error TransferFailed();
    error ArrayLengthMismatch();
    error EmptyBasket();
    error ZeroValueBasket();
    error NoPendingRequest();
    error RequestIdMismatch();
    error OnlyAuthorizedProcessor();
    error ZeroAmount();
    error InvalidPrice();
    error ZeroAddress();
    error RequestAlreadyProcessed();
    error RequestNotFound();
    error RequestNotTimedOut();
    error ConfidenceTooLow();

    /// @notice Modifiers
    modifier onlyAuthorizedProcessor() {
        if (!authorizedProcessors[msg.sender]) revert OnlyAuthorizedProcessor();
        _;
    }

    modifier nonZeroAmount(uint256 amount) {
        if (amount == 0) revert ZeroAmount();
        _;
    }

    /// @notice Initialize the vault
    constructor(address _aiusd, address _aiController) OwnedThreeStep(msg.sender) {
        aiusd = IAIStablecoin(_aiusd);
        aiController = IAISimplePromptController(_aiController);
    }

    /// @notice Receive function to accept ETH refunds
    receive() external payable { }

    /// @notice Deposit collateral and submit AI request (SimplePrompt pattern)
    /// @param tokens Array of token addresses to deposit
    /// @param amounts Array of token amounts to deposit
    function depositBasket(address[] calldata tokens, uint256[] calldata amounts) external payable {
        if (tokens.length != amounts.length) revert ArrayLengthMismatch();
        if (tokens.length == 0) revert EmptyBasket();
        if (positions[msg.sender].hasPendingRequest) revert PendingAIRequest();

        uint256 totalValueUSD = 0;

        // Transfer tokens and calculate total value
        for (uint256 i = 0; i < tokens.length; i++) {
            TokenInfo memory tokenInfo = supportedTokens[tokens[i]];
            if (!tokenInfo.supported) revert TokenNotSupported();

            // Transfer token from user
            bool success = IERC20(tokens[i]).transferFrom(msg.sender, address(this), amounts[i]);
            if (!success) revert TransferFailed();

            // Calculate USD value
            uint256 tokenValueUSD = _calculateUSDValue(tokens[i], amounts[i]);
            totalValueUSD += tokenValueUSD;
        }

        if (totalValueUSD == 0) revert ZeroValueBasket();

        // Store position with pending status
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

        // Create basket data for AI analysis
        bytes memory basketData = _encodeBasketData(tokens, amounts, totalValueUSD);

        // Submit AI request (SimplePrompt pattern - only emits events)
        address originalUser = msg.sender;
        uint256 balanceBefore = address(this).balance - msg.value;

        uint256 requestId = aiController.submitAIRequest{ value: msg.value }(msg.sender, basketData, totalValueUSD);

        // Update position with request ID
        positions[msg.sender].requestId = requestId;

        emit AIRequestSubmitted(msg.sender, requestId, totalValueUSD);

        // Forward any refund to user
        uint256 balanceAfter = address(this).balance;
        if (balanceAfter > balanceBefore) {
            uint256 refundAmount = balanceAfter - balanceBefore;
            payable(originalUser).transfer(refundAmount);
        }
    }

    /// @notice Process AI result and create pending mint (called by authorized processor)
    /// @param user Address of the user who deposited collateral
    /// @param requestId The AI request ID
    /// @param aiOutput Raw AI output from the oracle
    function processAIResult(address user, uint256 requestId, bytes calldata aiOutput)
        external
        onlyAuthorizedProcessor
    {
        Position storage position = positions[user];
        if (!position.hasPendingRequest) revert NoPendingRequest();
        if (position.requestId != requestId) revert RequestIdMismatch();

        // Check if already processed
        if (pendingMints[requestId].timestamp != 0) revert RequestAlreadyProcessed();

        // Parse AI response
        (uint256 ratio, uint256 confidence) = _parseResponse(string(aiOutput));

        // Validate confidence
        if (confidence < MIN_CONFIDENCE) revert ConfidenceTooLow();

        // Apply safety bounds
        ratio = _applySafetyBounds(ratio, confidence);

        // Calculate mint amount
        uint256 mintAmount = (position.totalValueUSD * 10_000) / ratio;

        // Create pending mint
        pendingMints[requestId] = PendingMint({
            user: user,
            requestId: requestId,
            mintAmount: mintAmount,
            ratio: ratio,
            confidence: confidence,
            timestamp: block.timestamp,
            processed: false
        });

        emit PendingMintCreated(requestId, user, mintAmount, ratio);
    }

    /// @notice Finalize mint after AI processing (called by authorized processor or user)
    /// @param requestId The request ID to finalize
    function finalizeMint(uint256 requestId) external {
        PendingMint storage pendingMint = pendingMints[requestId];
        if (pendingMint.timestamp == 0) revert RequestNotFound();
        if (pendingMint.processed) revert RequestAlreadyProcessed();

        address user = pendingMint.user;
        Position storage position = positions[user];

        // Update position
        position.aiusdMinted = pendingMint.mintAmount;
        position.collateralRatio = pendingMint.ratio;
        position.hasPendingRequest = false;

        // Mark as processed
        pendingMint.processed = true;

        // Mint AIUSD
        aiusd.mint(user, pendingMint.mintAmount);

        emit AIUSDMinted(user, pendingMint.mintAmount, pendingMint.ratio, pendingMint.confidence);
    }

    /// @notice Process and finalize in one call (convenience function)
    /// @param user Address of the user who deposited collateral
    /// @param requestId The AI request ID
    /// @param aiOutput Raw AI output from the oracle
    function processAndFinalize(address user, uint256 requestId, bytes calldata aiOutput)
        external
        onlyAuthorizedProcessor
    {
        this.processAIResult(user, requestId, aiOutput);
        this.finalizeMint(requestId);
    }

    /// @notice Cancel request if timed out (emergency function)
    /// @param requestId The request ID to cancel
    function cancelTimedOutRequest(uint256 requestId) external {
        Position storage position = positions[msg.sender];
        if (position.requestId != requestId) revert RequestIdMismatch();
        if (block.timestamp < position.timestamp + TIMEOUT_PERIOD) revert RequestNotTimedOut();

        // Return collateral to user
        for (uint256 i = 0; i < position.tokens.length; i++) {
            IERC20(position.tokens[i]).transfer(msg.sender, position.amounts[i]);
        }

        // Clear position
        delete positions[msg.sender];

        emit RequestTimeout(msg.sender, requestId);
    }

    /// @notice Get pending requests that need processing (view function for processors)
    /// @param startIndex Starting index for pagination
    /// @param count Number of requests to return
    /// @return requestIds Array of request IDs that need processing
    /// @return users Array of corresponding user addresses
    function getPendingRequests(uint256 startIndex, uint256 count)
        external
        view
        returns (uint256[] memory requestIds, address[] memory users)
    {
        // This is a simplified implementation - in production you'd want a more efficient data structure
        uint256[] memory tempRequestIds = new uint256[](count);
        address[] memory tempUsers = new address[](count);
        uint256 found = 0;
        uint256 checked = 0;

        // Note: This is inefficient for large datasets. Consider using an array to track pending requests.
        for (uint256 i = 1; found < count && checked < 1000; i++) {
            // Limit to prevent gas issues
            if (pendingMints[i].timestamp == 0 && pendingMints[i].user != address(0)) {
                if (checked >= startIndex) {
                    tempRequestIds[found] = i;
                    tempUsers[found] = pendingMints[i].user;
                    found++;
                }
                checked++;
            }
        }

        // Resize arrays to actual found count
        requestIds = new uint256[](found);
        users = new address[](found);
        for (uint256 i = 0; i < found; i++) {
            requestIds[i] = tempRequestIds[i];
            users[i] = tempUsers[i];
        }
    }

    /// @notice Check if a request can be processed
    /// @param requestId The request ID to check
    /// @return canProcess Whether the request can be processed
    /// @return reason Reason if it cannot be processed
    function canProcessRequest(uint256 requestId) external view returns (bool canProcess, string memory reason) {
        if (pendingMints[requestId].timestamp != 0) {
            return (false, "Already processed");
        }

        // Find the user for this request ID
        address user = address(0);
        for (uint256 i = 1; i <= 1000; i++) {
            // Limit search
            if (positions[address(uint160(i))].requestId == requestId) {
                user = address(uint160(i));
                break;
            }
        }

        if (user == address(0)) {
            return (false, "Request not found");
        }

        Position memory position = positions[user];
        if (!position.hasPendingRequest) {
            return (false, "No pending request");
        }

        if (block.timestamp > position.timestamp + TIMEOUT_PERIOD) {
            return (false, "Request timed out");
        }

        return (true, "");
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

    /// @notice Apply safety bounds to AI ratio
    function _applySafetyBounds(uint256 aiRatio, uint256 confidence) internal pure returns (uint256) {
        uint256 minRatio = 13_000; // 130% in basis points
        uint256 maxRatio = 17_000; // 170% in basis points

        // Adjust minimum based on confidence
        if (confidence < 60) {
            minRatio = 14_000; // 140% for very low confidence
        } else if (confidence < 80) {
            minRatio = 13_500; // 135% for medium confidence
        }

        // Apply bounds
        if (aiRatio < minRatio) return minRatio;
        if (aiRatio > maxRatio) return maxRatio;

        return aiRatio;
    }

    /// @notice Calculate USD value of token amount
    function _calculateUSDValue(address token, uint256 amount) internal view returns (uint256) {
        TokenInfo memory tokenInfo = supportedTokens[token];
        return (amount * tokenInfo.priceUSD) / (10 ** tokenInfo.decimals);
    }

    /// @notice Encode basket data for AI analysis
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

    /// @notice Helper functions for string parsing
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

    /// @notice Admin functions
    function addToken(address token, uint256 priceUSD, uint8 decimals, string calldata symbol) external onlyOwner {
        if (token == address(0)) revert ZeroAddress();
        if (priceUSD == 0) revert InvalidPrice();

        supportedTokens[token] = TokenInfo({ priceUSD: priceUSD, decimals: decimals, supported: true });

        tokenSymbols[token] = symbol;
        emit TokenAdded(token, priceUSD, decimals);
    }

    function updateTokenPrice(address token, uint256 newPriceUSD) external onlyOwner {
        if (!supportedTokens[token].supported) revert TokenNotSupported();
        if (newPriceUSD == 0) revert InvalidPrice();

        supportedTokens[token].priceUSD = newPriceUSD;
        emit TokenPriceUpdated(token, newPriceUSD);
    }

    function setAuthorizedProcessor(address processor, bool authorized) external onlyOwner {
        if (processor == address(0)) revert ZeroAddress();
        authorizedProcessors[processor] = authorized;
        emit ProcessorUpdated(processor, authorized);
    }

    /// @notice View functions
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

    function getPendingMint(uint256 requestId) external view returns (PendingMint memory) {
        return pendingMints[requestId];
    }
}
