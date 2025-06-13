// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { IERC20 } from "@openzeppelin/token/ERC20/IERC20.sol";
import { OwnedThreeStep } from "@solbase/auth/OwnedThreeStep.sol";

interface IAIStablecoin {
    function mint(address to, uint256 amount) external;
    function burn(address from, uint256 amount) external;
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
    // Core contract interfaces
    IAIStablecoin public immutable aiusd;
    IAIControllerCallback public immutable aiController;

    /// @notice Information about supported collateral tokens
    /// @dev Stores price and decimals for each supported token
    struct TokenInfo {
        uint256 priceUSD; // Price in USD with 18 decimals
        uint8 decimals; // Token decimals
        bool supported; // Whether token is currently accepted
    }

    /// @notice Mapping of supported tokens
    mapping(address => TokenInfo) public supportedTokens;

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

    mapping(address => Position) public positions;

    /// @notice Emitted when new collateral is deposited
    event CollateralDeposited(address indexed user, address[] tokens, uint256[] amounts, uint256 totalValue);
    /// @notice Emitted when an AI assessment request is submitted
    event AIRequestSubmitted(address indexed user, uint256 indexed requestId, uint256 collateralValue);
    /// @notice Emitted when AIUSD is minted based on AI assessment
    event AIUSDMinted(address indexed user, uint256 amount, uint256 ratio, uint256 confidence);
    /// @notice Emitted when collateral is withdrawn
    event CollateralWithdrawn(address indexed user, uint256 amount);
    /// @notice Emitted when a new token is added as supported collateral
    event TokenAdded(address indexed token, uint256 priceUSD, uint8 decimals);

    // Custom errors for gas-efficient reverts

    error TokenNotSupported();
    error InsufficientCollateral();
    error PendingAIRequest();
    error NoPosition();
    error TransferFailed();

    /// @notice Restricts function access to AI controller
    modifier onlyAIController() {
        require(msg.sender == address(aiController), "Only AI controller");
        _;
    }

    /// @notice Initializes the vault with core contract addresses
    /// @param _aiusd Address of the AIUSD stablecoin contract
    /// @param _aiController Address of the AI controller contract
    constructor(address _aiusd, address _aiController) OwnedThreeStep(msg.sender) {
        aiusd = IAIStablecoin(_aiusd);
        aiController = IAIControllerCallback(_aiController);
    }

    /// @notice Deposits a basket of tokens as collateral and initiates AI assessment
    /// @dev Transfers tokens from user, stores position, and triggers AI evaluation
    /// @param tokens Array of token addresses to deposit
    /// @param amounts Array of token amounts to deposit
    function depositBasket(address[] calldata tokens, uint256[] calldata amounts) external payable {
        require(tokens.length == amounts.length, "Array length mismatch");
        require(tokens.length > 0, "Empty basket");
        require(!positions[msg.sender].hasPendingRequest, "Pending AI request");

        uint256 totalValueUSD = 0;

        // Transfer tokens and calculate total value
        for (uint256 i = 0; i < tokens.length; i++) {
            TokenInfo memory tokenInfo = supportedTokens[tokens[i]];
            if (!tokenInfo.supported) revert TokenNotSupported();

            // Transfer token from user
            bool success = IERC20(tokens[i]).transferFrom(msg.sender, address(this), amounts[i]);
            if (!success) revert TransferFailed();

            // Calculate USD value
            uint256 tokenValueUSD = (amounts[i] * tokenInfo.priceUSD) / (10 ** tokenInfo.decimals);
            totalValueUSD += tokenValueUSD;
        }

        require(totalValueUSD > 0, "Zero value basket");

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
        uint256 requestId = aiController.submitAIRequest{ value: msg.value }(msg.sender, basketData, totalValueUSD);

        // Update position with request ID
        positions[msg.sender].requestId = requestId;

        emit AIRequestSubmitted(msg.sender, requestId, totalValueUSD);
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
        require(position.hasPendingRequest, "No pending request");
        require(position.requestId == requestId, "Request ID mismatch");

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
        require(position.totalValueUSD > 0, "No position");
        require(!position.hasPendingRequest, "Pending AI request");
        require(amount <= position.aiusdMinted, "Insufficient AIUSD minted");

        // Calculate collateral to return (proportional)
        uint256 collateralRatio = (amount * 10_000) / position.aiusdMinted;

        // Burn AIUSD
        aiusd.burn(msg.sender, amount);

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
            uint256 percentage = (tokenValueUSD * 100) / totalValueUSD;

            basketInfo =
                string(abi.encodePacked(basketInfo, _getTokenSymbol(tokens[i]), ":", _uint2str(percentage), "% "));
        }

        return abi.encodePacked(basketInfo, "Total:$", _uint2str(totalValueUSD / 1e18));
    }

    /// @notice Helper function to get a simplified token symbol
    /// @dev Currently uses hardcoded addresses for demo purposes
    /// @param token Address of the token
    /// @return Symbol string representation of the token
    function _getTokenSymbol(address token) internal pure returns (string memory) {
        // Simple mapping for demo - in production would use token.symbol()
        if (token == 0x82a170EDE9121FA86C5ed52D8cAE9a618f1c0988) return "WBTC";
        if (token == 0xCC74eEfB52887534E33d11d57c58a3F969e361B7) return "WETH";
        if (token == 0xD03f12D918eDA50D7Fb405cc6CBB6F8F39Aab76C) return "DAI";
        return "TOKEN";
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
            position.hasPendingRequest
        );
    }

    /// @notice Adds a new token as accepted collateral
    /// @dev Only callable by owner
    /// @param token Address of the token to add
    /// @param priceUSD Initial USD price with 18 decimals
    /// @param decimals Number of decimals for the token
    function addSupportedToken(address token, uint256 priceUSD, uint8 decimals) external onlyOwner {
        supportedTokens[token] = TokenInfo({ priceUSD: priceUSD, decimals: decimals, supported: true });
        emit TokenAdded(token, priceUSD, decimals);
    }

    /// @notice Updates the price of a supported token
    /// @dev Only callable by owner
    /// @param token Address of the token to update
    /// @param newPriceUSD New USD price with 18 decimals
    function updateTokenPrice(address token, uint256 newPriceUSD) external onlyOwner {
        require(supportedTokens[token].supported, "Token not supported");
        supportedTokens[token].priceUSD = newPriceUSD;
    }

    /// @notice Emergency function to clear a stuck AI request
    /// @dev Only callable by owner, use with caution
    /// @param user Address of the user whose request needs clearing
    function emergencyClearRequest(address user) external onlyOwner {
        positions[user].hasPendingRequest = false;
    }
}
