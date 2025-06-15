// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "./interfaces/IAIStablecoin.sol";
import "lib/solbase/src/auth/OwnedThreeStep.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/utils/ReentrancyGuard.sol";

/// @title IAIController Interface
interface IAIController {
    function submitAIRequest(address user, bytes calldata basketData, uint256 collateralValue)
        external
        payable
        returns (uint256 requestId);
}

/// @title CollateralVault - Enhanced Collateral Management with Manual Processing
/// @notice Manages collateral deposits and AI-driven minting with improved error handling
/// @dev Integrates with AIController for AI processing and manual recovery mechanisms
contract CollateralVault is OwnedThreeStep, ReentrancyGuard {
    /// @notice Core contract interfaces
    IAIStablecoin public aiusd;
    IAIController public aiController;

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

    /// @notice Mappings
    mapping(address => TokenInfo) public supportedTokens;
    mapping(address => Position) public positions;
    mapping(address => string) private tokenSymbols;

    /// @notice Events
    event CollateralDeposited(address indexed user, address[] tokens, uint256[] amounts, uint256 totalValue);
    event AIRequestSubmitted(address indexed user, uint256 indexed requestId, uint256 collateralValue);
    event AIUSDMinted(address indexed user, uint256 amount, uint256 ratio, uint256 confidence);
    event CollateralWithdrawn(address indexed user, uint256 amount);
    event EmergencyWithdrawal(address indexed user, uint256 indexed requestId, uint256 timestamp);
    event TokenAdded(address indexed token, uint256 priceUSD, uint8 decimals);
    event TokenPriceUpdated(address indexed token, uint256 newPriceUSD);
    event ControllerUpdated(address indexed oldController, address indexed newController);

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
    error OnlyAIController();
    error ZeroAmount();
    error InvalidPrice();
    error ZeroAddress();

    /// @notice Modifiers
    modifier onlyAIController() {
        if (msg.sender != address(aiController)) revert OnlyAIController();
        _;
    }

    modifier nonZeroAmount(uint256 amount) {
        if (amount == 0) revert ZeroAmount();
        _;
    }

    /// @notice Initialize the vault
    constructor(address _aiusd, address _aiController) OwnedThreeStep(msg.sender) {
        aiusd = IAIStablecoin(_aiusd);
        aiController = IAIController(_aiController);
    }

    /// @notice Receive function to accept ETH refunds
    receive() external payable { }

    /// @notice Deposit collateral and submit AI request
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

        // Store position
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

        // Submit AI request with callback (forwards ETH for ORA fee)
        address originalUser = msg.sender;
        uint256 balanceBefore = address(this).balance - msg.value;

        uint256 requestId = aiController.submitAIRequest{ value: msg.value }(msg.sender, basketData, totalValueUSD);

        // Update position with request ID
        positions[msg.sender].requestId = requestId;

        emit AIRequestSubmitted(msg.sender, requestId, totalValueUSD);

        // Check if we received any refund and forward it to user
        uint256 balanceAfter = address(this).balance;
        if (balanceAfter > balanceBefore) {
            uint256 refundAmount = balanceAfter - balanceBefore;
            payable(originalUser).transfer(refundAmount);
        }
    }

    /// @notice Processes the AI assessment callback and mints AIUSD
    /// @dev Called by AI controller when assessment is complete
    /// @param user Address of the user who deposited collateral
    /// @param requestId ID of the completed AI assessment request
    /// @param mintAmount Amount of AIUSD to mint
    /// @param ratio Approved collateral ratio in basis points
    /// @param confidence AI confidence score for the assessment
    function processAICallback(address user, uint256 requestId, uint256 mintAmount, uint256 ratio, uint256 confidence)
        external
        onlyAIController
    {
        Position storage position = positions[user];
        if (!position.hasPendingRequest) revert NoPendingRequest();
        if (position.requestId != requestId) revert RequestIdMismatch();

        // Update position
        position.aiusdMinted = mintAmount;
        position.collateralRatio = ratio;
        position.hasPendingRequest = false;

        // Mint AIUSD to user
        aiusd.mint(user, mintAmount);

        emit AIUSDMinted(user, mintAmount, ratio, confidence);
    }

    /// @notice Emergency withdrawal function for stuck requests
    /// @dev Called by AI controller when user requests emergency withdrawal
    /// @param user Address of the user requesting withdrawal
    /// @param requestId ID of the request to withdraw from
    function emergencyWithdraw(address user, uint256 requestId) external onlyAIController {
        Position storage position = positions[user];
        if (!position.hasPendingRequest) revert NoPendingRequest();
        if (position.requestId != requestId) revert RequestIdMismatch();

        // Return all collateral to user
        for (uint256 i = 0; i < position.tokens.length; i++) {
            IERC20(position.tokens[i]).transfer(user, position.amounts[i]);
        }

        // Clear position
        delete positions[user];

        emit EmergencyWithdrawal(user, requestId, block.timestamp);
    }

    /// @notice User-initiated emergency withdrawal (after sufficient time has passed)
    /// @dev Allows users to withdraw directly if controller is unresponsive
    function userEmergencyWithdraw() external {
        Position storage position = positions[msg.sender];
        if (!position.hasPendingRequest) revert NoPendingRequest();

        // Require 4 hours to pass before allowing direct withdrawal
        require(block.timestamp >= position.timestamp + 4 hours, "Must wait 4 hours");

        // Return all collateral to user
        for (uint256 i = 0; i < position.tokens.length; i++) {
            IERC20(position.tokens[i]).transfer(msg.sender, position.amounts[i]);
        }

        uint256 requestId = position.requestId;

        // Clear position
        delete positions[msg.sender];

        emit EmergencyWithdrawal(msg.sender, requestId, block.timestamp);
    }

    /// @notice Allows users to withdraw collateral by burning AIUSD
    /// @dev Burns AIUSD and returns proportional amount of collateral
    /// @param amount Amount of AIUSD to burn
    function withdrawCollateral(uint256 amount) external nonZeroAmount(amount) {
        Position storage position = positions[msg.sender];
        if (position.aiusdMinted == 0) revert NoPosition();
        if (position.hasPendingRequest) revert PendingAIRequest();
        if (amount > position.aiusdMinted) revert InsufficientAIUSD();

        // Calculate withdrawal ratio
        uint256 withdrawalRatio = (amount * 1e18) / position.aiusdMinted;

        // Burn AIUSD from user
        aiusd.burnFrom(msg.sender, amount);

        // Transfer proportional collateral back to user
        for (uint256 i = 0; i < position.tokens.length; i++) {
            uint256 withdrawAmount = (position.amounts[i] * withdrawalRatio) / 1e18;
            if (withdrawAmount > 0) {
                IERC20(position.tokens[i]).transfer(msg.sender, withdrawAmount);
                position.amounts[i] -= withdrawAmount;
            }
        }

        // Update position
        position.aiusdMinted -= amount;
        position.totalValueUSD = (position.totalValueUSD * (1e18 - withdrawalRatio)) / 1e18;

        // If fully withdrawn, clear position
        if (position.aiusdMinted == 0) {
            delete positions[msg.sender];
        }

        emit CollateralWithdrawn(msg.sender, amount);
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

    /// @notice Update the AI controller address (owner only)
    /// @param newController Address of the new AI controller
    function updateController(address newController) external onlyOwner {
        if (newController == address(0)) revert ZeroAddress();
        address oldController = address(aiController);
        aiController = IAIController(newController);
        emit ControllerUpdated(oldController, newController);
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

    /// @notice Check if user can perform emergency withdrawal
    /// @param user Address to check
    /// @return canWithdraw Whether emergency withdrawal is available
    /// @return timeRemaining Time remaining until withdrawal is available
    function canEmergencyWithdraw(address user) external view returns (bool canWithdraw, uint256 timeRemaining) {
        Position memory position = positions[user];

        if (!position.hasPendingRequest) {
            return (false, 0);
        }

        uint256 timeElapsed = block.timestamp - position.timestamp;
        uint256 requiredTime = 4 hours;

        if (timeElapsed >= requiredTime) {
            return (true, 0);
        } else {
            return (false, requiredTime - timeElapsed);
        }
    }

    /// @notice Get user's position status for manual processing
    /// @param user Address to check
    /// @return hasPosition Whether user has a position
    /// @return isPending Whether request is pending
    /// @return requestId The request ID
    /// @return timeElapsed Time since request was made
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
}
