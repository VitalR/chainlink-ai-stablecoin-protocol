// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { IERC20 } from "@openzeppelin/token/ERC20/IERC20.sol";
import { OwnedThreeStep } from "@solbase/auth/OwnedThreeStep.sol";
import { AIControllerCallback } from "./AIControllerCallback.sol";
import { AIStablecoin } from "./AIStablecoin.sol";

/// @title IAIStablecoin Interface
/// @notice Interface for the AI Stablecoin contract
/// @dev Defines the mint and burn functions for the AI Stablecoin
interface IAIStablecoin {
    function mint(address to, uint256 amount) external;
    function burn(uint256 amount) external;
    function burnFrom(address account, uint256 amount) external;
}

/// @title IERC20Extended Interface
/// @notice Extended ERC20 interface with symbol function
/// @dev Used for automatic symbol detection
interface IERC20Extended {
    function symbol() external view returns (string memory);
}

/// @title IAIControllerCallback Interface
/// @notice Interface for the AI Controller that processes collateral assessments
/// @dev Defines the callback mechanism for AI-driven collateral evaluation
interface IAIControllerCallback {
    /// @notice Submits a request for AI assessment of collateral
    /// @param user The address of the user depositing collateral
    /// @param basketData Encoded data about the collateral basket
    /// @param collateralValue Total USD value of the collateral
    /// @return requestId Unique identifier for tracking the AI assessment request
    function submitAIRequest(address user, bytes calldata basketData, uint256 collateralValue)
        external
        payable
        returns (uint256 requestId);
}

/// @title AICollateralVaultCallback
/// @notice A vault contract that manages collateral deposits and AI-driven stablecoin minting
/// @dev Implements a callback pattern for asynchronous AI assessment of collateral
contract AICollateralVaultCallback is OwnedThreeStep {
    /// @notice Core contract interfaces
    IAIStablecoin public aiusd;
    IAIControllerCallback public aiController;

    /// @notice Information about supported collateral tokens
    /// @dev Stores price and decimals for each supported token
    struct TokenInfo {
        uint256 priceUSD; // Price in USD with 18 decimals
        uint8 decimals; // Token decimals
        bool supported; // Whether token is currently accepted
    }

    /// @notice User collateral position information
    /// @dev Tracks all aspects of a user's deposited collateral and minted stablecoins
    struct Position {
        address[] tokens; // Array of deposited token addresses
        uint256[] amounts; // Corresponding amounts of each token
        uint256 totalValueUSD; // Total value in USD (18 decimals)
        uint256 aiusdMinted; // Amount of AIUSD minted against position
        uint256 collateralRatio; // Current collateral ratio in basis points
        uint256 requestId; // ID of the last AI assessment request
        bool hasPendingRequest; // Whether an AI assessment is in progress
    }

    /// @notice Mapping of supported tokens
    mapping(address => TokenInfo) public supportedTokens;

    /// @notice Mapping of user positions
    mapping(address => Position) public positions;

    /// @notice Mapping of token addresses to their symbols
    mapping(address => string) private tokenSymbols;

    /// @notice Event emitted when a token symbol is set
    event TokenSymbolSet(address indexed token, string symbol);

    /// @notice Events
    event CollateralDeposited(address indexed user, address[] tokens, uint256[] amounts, uint256 totalValue);
    event AIRequestSubmitted(address indexed user, uint256 indexed requestId, uint256 collateralValue);
    event AIUSDMinted(address indexed user, uint256 amount, uint256 ratio, uint256 confidence);
    event CollateralWithdrawn(address indexed user, uint256 amount);
    event TokenAdded(address indexed token, uint256 priceUSD, uint8 decimals);
    event TokenPriceUpdated(address indexed token, uint256 newPriceUSD);
    event EmergencyRequestCleared(address indexed user, uint256 indexed requestId);

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
    error EmptySymbol();
    error SymbolTooLong();

    /// @notice Restricts function access to AI controller
    modifier onlyAIController() {
        if (msg.sender != address(aiController)) revert OnlyAIController();
        _;
    }

    /// @notice Validates token amounts are non-zero
    /// @param amount Amount to validate
    modifier nonZeroAmount(uint256 amount) {
        if (amount == 0) revert ZeroAmount();
        _;
    }

    /// @notice Initializes the vault with core contract addresses
    /// @param _aiusd Address of the AIUSD stablecoin contract
    /// @param _aiController Address of the AI controller contract
    constructor(address _aiusd, address _aiController) OwnedThreeStep(msg.sender) {
        aiusd = IAIStablecoin(_aiusd);
        aiController = IAIControllerCallback(_aiController);
    }

    /// @notice Receive function to accept ETH refunds from controller
    receive() external payable {
        // Accept ETH refunds from the AI controller
        // The depositBasket function will forward these to the user
    }

    /// @notice Deposits a basket of tokens as collateral and initiates AI assessment
    /// @dev Transfers tokens from user, stores position, and triggers AI evaluation
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
            hasPendingRequest: true
        });

        emit CollateralDeposited(msg.sender, tokens, amounts, totalValueUSD);

        // Create basket data for AI analysis
        bytes memory basketData = _encodeBasketData(tokens, amounts, totalValueUSD);

        // Submit AI request with callback (forwards ETH for ORA fee)
        // Store user address for potential refund
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

    /// @notice Allows users to withdraw collateral by burning AIUSD
    /// @dev Burns AIUSD and returns proportional amount of collateral
    /// @param amount Amount of AIUSD to burn
    function withdrawCollateral(uint256 amount) external {
        Position storage position = positions[msg.sender];
        if (position.totalValueUSD == 0) revert NoPosition();
        if (position.hasPendingRequest) revert PendingAIRequest();
        if (amount > position.aiusdMinted) revert InsufficientAIUSD();

        // Calculate collateral to return (proportional)
        uint256 collateralRatio = (amount * 10_000) / position.aiusdMinted;

        // Burn AIUSD from user's balance
        aiusd.burnFrom(msg.sender, amount);

        // Return proportional collateral
        for (uint256 i = 0; i < position.tokens.length; i++) {
            uint256 returnAmount = (position.amounts[i] * collateralRatio) / 10_000;
            if (returnAmount > 0) {
                bool success = IERC20(position.tokens[i]).transfer(msg.sender, returnAmount);
                if (!success) revert TransferFailed();
                position.amounts[i] -= returnAmount;
            }
        }

        // Update position
        position.aiusdMinted -= amount;
        position.totalValueUSD = (position.totalValueUSD * (10_000 - collateralRatio)) / 10_000;

        emit CollateralWithdrawn(msg.sender, amount);
    }

    /// @notice Encodes basket data for AI analysis
    /// @dev Creates a formatted string with basket composition
    /// @param tokens Array of token addresses in the basket
    /// @param amounts Array of token amounts in the basket
    /// @param totalValueUSD Total USD value of the basket
    /// @return Encoded basket data as bytes
    function _encodeBasketData(address[] calldata tokens, uint256[] calldata amounts, uint256 totalValueUSD)
        internal
        view
        returns (bytes memory)
    {
        string memory basketInfo = "Basket: ";

        for (uint256 i = 0; i < tokens.length; i++) {
            TokenInfo memory tokenInfo = supportedTokens[tokens[i]];
            uint256 tokenValueUSD = (amounts[i] * tokenInfo.priceUSD) / (10 ** tokenInfo.decimals);
            // Calculate percentage directly using 100 instead of constant
            uint256 percentage = (tokenValueUSD * 100) / totalValueUSD;

            basketInfo =
                string(abi.encodePacked(basketInfo, _getTokenSymbol(tokens[i]), ":", _uint2str(percentage), "% "));
        }

        // Use 1e18 directly for USD decimals conversion
        return abi.encodePacked(basketInfo, "Total:$", _uint2str(totalValueUSD / 1e18));
    }

    /// @notice Helper function to get a token's symbol
    /// @dev Tries to fetch from token contract first, falls back to stored symbol
    /// @param token Address of the token
    /// @return Symbol string representation of the token
    function _getTokenSymbol(address token) internal view returns (string memory) {
        // First try to get symbol from stored mapping
        string memory storedSymbol = tokenSymbols[token];
        if (bytes(storedSymbol).length > 0) {
            return storedSymbol;
        }

        // Try to fetch from token contract
        try IERC20Extended(token).symbol() returns (string memory tokenSymbol) {
            if (bytes(tokenSymbol).length > 0) {
                return tokenSymbol;
            }
        } catch {
            // If external call fails, continue to fallback
        }

        // Final fallback
        return "UNKNOWN";
    }

    /// @notice Converts a uint256 to its string representation
    /// @dev Uses a bytes array to build the string efficiently
    /// @param _i The number to convert
    /// @return The string representation of the number
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

    /// @notice Retrieves the full position information for a user
    /// @dev Returns all aspects of a user's collateral position
    /// @param user Address of the user to query
    /// @return tokens Array of deposited token addresses
    /// @return amounts Array of token amounts
    /// @return totalValueUSD Total position value in USD
    /// @return aiusdMinted Amount of AIUSD minted against position
    /// @return collateralRatio Current collateral ratio
    /// @return requestId ID of the last AI assessment request
    /// @return hasPendingRequest Whether an AI assessment is pending
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

    /// @notice Sets the symbol for a token (override automatic detection)
    /// @dev Only callable by owner, used to override automatic symbol detection
    /// @param token Address of the token
    /// @param symbol Symbol string for the token (empty string to clear override)
    function setTokenSymbol(address token, string calldata symbol) external onlyOwner {
        if (bytes(symbol).length > 10) revert SymbolTooLong();

        tokenSymbols[token] = symbol;
        emit TokenSymbolSet(token, symbol);
    }

    /// @notice Gets the effective symbol for a token
    /// @dev Public function to check what symbol will be used
    /// @param token Address of the token
    /// @return The symbol that will be used for this token
    function getTokenSymbol(address token) external view returns (string memory) {
        return _getTokenSymbol(token);
    }

    /// @notice Adds a new token as accepted collateral with symbol
    /// @dev Only callable by owner
    /// @param token Address of the token to add
    /// @param priceUSD Initial USD price with 18 decimals
    /// @param decimals Number of decimals for the token
    /// @param symbol Symbol string for the token
    function addSupportedToken(address token, uint256 priceUSD, uint8 decimals, string calldata symbol)
        external
        onlyOwner
    {
        if (bytes(symbol).length == 0) revert EmptySymbol();
        if (bytes(symbol).length > 10) revert SymbolTooLong();

        supportedTokens[token] = TokenInfo({ priceUSD: priceUSD, decimals: decimals, supported: true });

        tokenSymbols[token] = symbol;

        emit TokenAdded(token, priceUSD, decimals);
        emit TokenSymbolSet(token, symbol);
    }

    /// @notice Updates the price of a supported token
    /// @dev Only callable by owner
    /// @param token Address of the token to update
    /// @param newPriceUSD New USD price with 18 decimals
    function updateTokenPrice(address token, uint256 newPriceUSD) external onlyOwner {
        if (newPriceUSD == 0) revert InvalidPrice();
        if (!supportedTokens[token].supported) revert TokenNotSupported();

        supportedTokens[token].priceUSD = newPriceUSD;
        emit TokenPriceUpdated(token, newPriceUSD);
    }

    /// @notice Emergency function to clear a stuck AI request
    /// @dev Only callable by owner, use with extreme caution
    /// @param user Address of the user whose request needs clearing
    function emergencyClearRequest(address user) external onlyOwner {
        Position storage position = positions[user];
        uint256 requestId = position.requestId;
        position.hasPendingRequest = false;
        emit EmergencyRequestCleared(user, requestId);
    }

    /// @notice Emergency function to remove token support
    /// @dev Only callable by owner, for emergency situations
    /// @param token Address of the token to remove support for
    function emergencyRemoveToken(address token) external onlyOwner {
        supportedTokens[token].supported = false;
    }

    /// @notice Emergency function to pause deposits
    /// @dev Only callable by owner, prevents new deposits
    /// @param token Address of the token to pause
    function emergencyPauseToken(address token) external onlyOwner {
        supportedTokens[token].supported = false;
    }

    /// @notice Calculates the USD value of a token amount
    /// @dev Internal helper function to calculate token values
    /// @param token The token address
    /// @param amount The amount of tokens
    /// @return The USD value with 18 decimals
    function _calculateUSDValue(address token, uint256 amount) internal view returns (uint256) {
        TokenInfo memory tokenInfo = supportedTokens[token];
        return (amount * tokenInfo.priceUSD) / (10 ** tokenInfo.decimals);
    }
}
