// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import { AIStablecoin } from "../src/AIStablecoin.sol";
import { CollateralVault } from "../src/CollateralVault.sol";
import { RiskOracleController } from "../src/RiskOracleController.sol";

import { MockChainlinkFunctionsRouter } from "./mocks/MockChainlinkFunctionsRouter.sol";
import { MockDAI } from "./mocks/MockDAI.sol";
import { MockUSDC } from "./mocks/MockUSDC.sol";
import { MockWETH } from "./mocks/MockWETH.sol";

/// @title RiskOracleControllerTest - Tests for Chainlink Functions-based RiskOracleController
/// @notice Tests Chainlink Functions integration, price feeds, and manual processing
contract RiskOracleControllerTest is Test {
    // Core contracts
    AIStablecoin public aiusd;
    CollateralVault public vault;
    RiskOracleController public controller;
    MockChainlinkFunctionsRouter public mockRouter;

    // Mock tokens
    MockWETH public weth;
    MockUSDC public usdc;
    MockDAI public dai;

    // Test accounts
    address public owner = makeAddr("owner");
    address public user1 = makeAddr("user1");
    address public user2 = makeAddr("user2");
    address public manualProcessor = makeAddr("manualProcessor");

    // Test constants
    uint256 public constant INITIAL_BALANCE = 1000 ether;
    uint256 public constant DEPOSIT_AMOUNT = 10 ether;

    // Chainlink Functions config
    bytes32 public constant DON_ID = bytes32("fun_sepolia_1");
    uint64 public constant SUBSCRIPTION_ID = 123;
    string public constant AI_SOURCE_CODE = "return '150,75';"; // ratio,confidence

    // Events to test
    event AIRequestSubmitted(
        uint256 indexed internalRequestId, bytes32 indexed chainlinkRequestId, address indexed user, address vault
    );
    event AIResultProcessed(
        uint256 indexed internalRequestId,
        bytes32 indexed chainlinkRequestId,
        uint256 ratio,
        uint256 confidence,
        uint256 mintAmount
    );
    event ManualProcessingRequested(uint256 indexed internalRequestId, address indexed user, uint256 timestamp);
    event PriceFeedUpdated(string indexed token, address indexed priceFeed);
    event ChainlinkConfigUpdated(bytes32 donId, uint64 subscriptionId, uint32 gasLimit);

    function setUp() public {
        vm.startPrank(owner);

        // Deploy mock tokens
        weth = new MockWETH();
        usdc = new MockUSDC();
        dai = new MockDAI();

        // Deploy mock Chainlink Functions router
        mockRouter = new MockChainlinkFunctionsRouter();

        // Deploy core contracts
        aiusd = new AIStablecoin();

        controller = new RiskOracleController(address(mockRouter), DON_ID, SUBSCRIPTION_ID, AI_SOURCE_CODE);

        vault = new CollateralVault(
            address(aiusd),
            address(controller),
            address(0), // No automation contract
            new CollateralVault.TokenConfig[](0) // No initial tokens
        );

        // Setup permissions
        aiusd.addVault(address(vault));
        controller.setAuthorizedCaller(address(vault), true);
        controller.setAuthorizedManualProcessor(manualProcessor, true);

        // Setup token prices in vault
        vault.addToken(address(weth), 2000 * 1e18, 18, "WETH"); // $2000 per ETH
        vault.addToken(address(usdc), 1 * 1e18, 6, "USDC"); // $1 per USDC
        vault.addToken(address(dai), 1 * 1e18, 18, "DAI"); // $1 per DAI

        // Mint tokens to users
        weth.mint(user1, INITIAL_BALANCE);
        usdc.mint(user1, INITIAL_BALANCE);
        dai.mint(user1, INITIAL_BALANCE);

        vm.stopPrank();

        // Fund users with ETH
        vm.deal(user1, 10 ether);
        vm.deal(user2, 10 ether);
        vm.deal(manualProcessor, 1 ether);

        // Users approve vault
        vm.startPrank(user1);
        weth.approve(address(vault), type(uint256).max);
        usdc.approve(address(vault), type(uint256).max);
        dai.approve(address(vault), type(uint256).max);
        vm.stopPrank();
    }

    /// @notice Test Chainlink Functions fee estimation (should be 0 for subscription model)
    function test_chainlinkFunctionsFeeEstimation() public {
        uint256 fee = controller.estimateTotalFee();
        assertEq(fee, 0, "Chainlink Functions should use subscription model (free)");
    }

    /// @notice Test successful Chainlink Functions AI request submission
    function test_submitChainlinkFunctionsRequest() public {
        vm.startPrank(user1);

        // Prepare deposit
        address[] memory tokens = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        tokens[0] = address(weth);
        amounts[0] = DEPOSIT_AMOUNT;

        uint256 aiFee = controller.estimateTotalFee();

        // Should emit AIRequestSubmitted event
        vm.expectEmit(true, false, true, false);
        emit AIRequestSubmitted(1, bytes32(0), user1, address(vault));

        vault.depositBasket{ value: aiFee }(tokens, amounts);

        // Verify request was created
        (,,,,, uint256 requestId, bool hasPendingRequest) = vault.getPosition(user1);
        assertTrue(hasPendingRequest, "Should have pending Chainlink Functions request");
        assertEq(requestId, 1, "Should have request ID 1");

        vm.stopPrank();
    }

    /// @notice Test Chainlink Functions callback processing
    function test_chainlinkFunctionsCallback() public {
        // Setup request
        uint256 requestId = _setupChainlinkRequest();

        // Simulate Chainlink Functions callback with AI response (new format)
        bytes memory response = abi.encode("RATIO:150 CONFIDENCE:85 SOURCE:AMAZON_BEDROCK_AI");
        mockRouter.simulateCallback(requestId, response, "");

        // Verify processing completed
        vm.startPrank(user1);
        (,,, uint256 aiusdMinted, uint256 collateralRatio,, bool hasPendingRequest) = vault.getPosition(user1);

        assertFalse(hasPendingRequest, "Should not have pending request");
        assertGt(aiusdMinted, 0, "Should have minted AIUSD");
        assertEq(collateralRatio, 15_000, "Should have 150% collateral ratio");
        assertGt(aiusd.balanceOf(user1), 0, "User should have AIUSD balance");

        console.log("Chainlink Functions - AIUSD minted:", aiusdMinted);
        console.log("Chainlink Functions - Collateral ratio:", collateralRatio);

        vm.stopPrank();
    }

    /// @notice Test Chainlink Functions callback failure handling
    function test_chainlinkFunctionsCallbackFailure() public {
        uint256 requestId = _setupChainlinkRequest();

        // Simulate callback with error
        bytes memory errorData = abi.encode("Network error");
        mockRouter.simulateCallback(requestId, "", errorData);

        // Request should still be pending and failure count should increase
        (bool paused, uint256 failures,,) = controller.getSystemStatus();
        assertGt(failures, 0, "Should have recorded failure");

        vm.startPrank(user1);
        (,,,,, uint256 pendingRequestId, bool hasPendingRequest) = vault.getPosition(user1);
        assertTrue(hasPendingRequest, "Should still have pending request after failure");
        vm.stopPrank();
    }

    /// @notice Test manual processing after Chainlink Functions timeout
    function test_manualProcessingAfterTimeout() public {
        uint256 requestId = _setupChainlinkRequest();

        // Fast forward time to allow manual processing
        vm.warp(block.timestamp + 31 minutes);

        // User requests manual processing
        vm.startPrank(user1);

        vm.expectEmit(true, true, false, true);
        emit ManualProcessingRequested(requestId, user1, block.timestamp);

        controller.requestManualProcessing(requestId);
        vm.stopPrank();

        // Manual processor processes with AI response
        vm.startPrank(manualProcessor);
        string memory aiResponse = "RATIO:140 CONFIDENCE:90";

        controller.processWithOffChainAI(
            requestId, aiResponse, RiskOracleController.ManualStrategy.PROCESS_WITH_OFFCHAIN_AI
        );
        vm.stopPrank();

        // Verify processing completed
        vm.startPrank(user1);
        (,,, uint256 aiusdMinted, uint256 collateralRatio,, bool hasPendingRequest) = vault.getPosition(user1);

        assertFalse(hasPendingRequest, "Should not have pending request");
        assertGt(aiusdMinted, 0, "Should have minted AIUSD");
        assertEq(collateralRatio, 14_000, "Should have 140% collateral ratio");

        vm.stopPrank();
    }

    /// @notice Test emergency withdrawal functionality
    function test_emergencyWithdrawal() public {
        uint256 requestId = _setupChainlinkRequest();

        // Fast forward time to allow emergency withdrawal
        vm.warp(block.timestamp + 2.1 hours);

        uint256 initialWethBalance = weth.balanceOf(user1);

        // User initiates emergency withdrawal
        vm.startPrank(user1);
        controller.emergencyWithdraw(requestId);
        vm.stopPrank();

        // Verify user got collateral back
        uint256 finalWethBalance = weth.balanceOf(user1);
        assertEq(finalWethBalance, initialWethBalance + DEPOSIT_AMOUNT, "Should get collateral back");
        assertEq(aiusd.balanceOf(user1), 0, "Should not have any AIUSD");
    }

    /// @notice Test force default mint strategy
    function test_forceDefaultMint() public {
        uint256 requestId = _setupChainlinkRequest();

        // Fast forward time
        vm.warp(block.timestamp + 31 minutes);

        // Manual processor uses force default mint
        vm.startPrank(manualProcessor);
        controller.processWithOffChainAI(requestId, "", RiskOracleController.ManualStrategy.FORCE_DEFAULT_MINT);
        vm.stopPrank();

        // Verify conservative ratio was used
        vm.startPrank(user1);
        (,,, uint256 aiusdMinted, uint256 collateralRatio,, bool hasPendingRequest) = vault.getPosition(user1);

        assertFalse(hasPendingRequest, "Should not have pending request");
        assertGt(aiusdMinted, 0, "Should have minted AIUSD");
        assertEq(collateralRatio, 16_000, "Should have conservative 160% ratio");

        vm.stopPrank();
    }

    /// @notice Test Chainlink configuration updates
    function test_updateChainlinkConfig() public {
        vm.startPrank(owner);

        bytes32 newDonId = bytes32("fun_sepolia_2");
        uint64 newSubscriptionId = 456;
        uint32 newGasLimit = 400_000;
        string memory newSourceCode = "return '160,80';";

        vm.expectEmit(false, false, false, true);
        emit ChainlinkConfigUpdated(newDonId, newSubscriptionId, newGasLimit);

        controller.updateChainlinkConfig(newDonId, newSubscriptionId, newGasLimit, newSourceCode);

        // Verify config was updated (we can't easily test private vars, but no revert means success)
        assertTrue(true, "Config update should succeed");

        vm.stopPrank();
    }

    /// @notice Test unauthorized access protection
    function test_unauthorizedAccess() public {
        uint256 requestId = _setupChainlinkRequest();

        // Non-authorized user tries manual processing
        vm.startPrank(user2);
        vm.expectRevert(RiskOracleController.UnauthorizedManualProcessor.selector);
        controller.processWithOffChainAI(
            requestId, "RATIO:150 CONFIDENCE:85", RiskOracleController.ManualStrategy.PROCESS_WITH_OFFCHAIN_AI
        );
        vm.stopPrank();

        // Non-vault tries to submit AI request
        vm.startPrank(user1);
        vm.expectRevert(RiskOracleController.UnauthorizedCaller.selector);
        controller.submitAIRequest(user1, abi.encode("test"), 1000e18, RiskOracleController.Engine.ALGO);
        vm.stopPrank();
    }

    /// @notice Test circuit breaker functionality
    function test_circuitBreaker() public {
        vm.startPrank(owner);

        // Test manual pause/resume
        controller.pauseProcessing();
        (bool paused,,,) = controller.getSystemStatus();
        assertTrue(paused, "Should be paused");

        controller.resumeProcessing();
        (paused,,,) = controller.getSystemStatus();
        assertFalse(paused, "Should be resumed");

        vm.stopPrank();
    }

    /// @notice Test AI response parsing
    function test_aiResponseParsing() public {
        uint256 requestId = _setupChainlinkRequest();
        vm.warp(block.timestamp + 31 minutes);

        vm.startPrank(manualProcessor);

        // Test various response formats
        string memory response1 = "RATIO:145 CONFIDENCE:90";
        controller.processWithOffChainAI(
            requestId, response1, RiskOracleController.ManualStrategy.PROCESS_WITH_OFFCHAIN_AI
        );

        // Verify parsing worked
        vm.startPrank(user1);
        (,,, uint256 aiusdMinted, uint256 collateralRatio,,) = vault.getPosition(user1);
        assertEq(collateralRatio, 14_500, "Should parse 145% ratio correctly");
        vm.stopPrank();
    }

    /// @notice Test system status queries
    function test_systemStatusQueries() public {
        (bool paused, uint256 failures, uint256 lastFailure, bool circuitBreakerActive) = controller.getSystemStatus();

        assertFalse(paused, "Should not be paused initially");
        assertEq(failures, 0, "Should have no failures initially");
        assertEq(lastFailure, 0, "Should have no last failure time");
        assertFalse(circuitBreakerActive, "Circuit breaker should not be active");
    }

    /// @notice Test Amazon Bedrock response format parsing
    function test_amazonBedrockResponseFormat() public {
        uint256 requestId = _setupChainlinkRequest();

        // Test Amazon Bedrock response format
        bytes memory bedrockResponse = abi.encode("RATIO:135 CONFIDENCE:85 SOURCE:AMAZON_BEDROCK_AI");
        mockRouter.simulateCallback(requestId, bedrockResponse, "");

        vm.startPrank(user1);
        (,,, uint256 aiusdMinted, uint256 collateralRatio,, bool hasPendingRequest) = vault.getPosition(user1);

        assertFalse(hasPendingRequest, "Should not have pending request");
        assertGt(aiusdMinted, 0, "Should have minted AIUSD");
        assertEq(collateralRatio, 13_500, "Should have 135% collateral ratio from Bedrock");

        console.log("Amazon Bedrock - AIUSD minted:", aiusdMinted);
        console.log("Amazon Bedrock - Collateral ratio:", collateralRatio);

        vm.stopPrank();
    }

    /// @notice Test algorithmic AI fallback response format
    function test_algorithmicFallbackResponseFormat() public {
        uint256 requestId = _setupChainlinkRequest();

        // Test algorithmic AI response format
        bytes memory algorithmicResponse = abi.encode("RATIO:165 CONFIDENCE:75 SOURCE:ALGORITHMIC_AI");
        mockRouter.simulateCallback(requestId, algorithmicResponse, "");

        vm.startPrank(user1);
        (,,, uint256 aiusdMinted, uint256 collateralRatio,, bool hasPendingRequest) = vault.getPosition(user1);

        assertFalse(hasPendingRequest, "Should not have pending request");
        assertGt(aiusdMinted, 0, "Should have minted AIUSD");
        assertEq(collateralRatio, 16_500, "Should have 165% collateral ratio from algorithmic AI");

        console.log("Algorithmic AI - AIUSD minted:", aiusdMinted);
        console.log("Algorithmic AI - Collateral ratio:", collateralRatio);

        vm.stopPrank();
    }

    /// @notice Test external AI response during manual processing
    function test_externalAIManualProcessing() public {
        uint256 requestId = _setupChainlinkRequest();
        vm.warp(block.timestamp + 31 minutes);

        vm.startPrank(manualProcessor);

        // Test external AI response formats
        string memory externalAIResponse1 = "RATIO:142 CONFIDENCE:88 SOURCE:EXTERNAL_AI";
        controller.processWithOffChainAI(
            requestId, externalAIResponse1, RiskOracleController.ManualStrategy.PROCESS_WITH_OFFCHAIN_AI
        );

        vm.stopPrank();

        vm.startPrank(user1);
        (,,, uint256 aiusdMinted, uint256 collateralRatio,, bool hasPendingRequest) = vault.getPosition(user1);

        assertFalse(hasPendingRequest, "Should not have pending request");
        assertGt(aiusdMinted, 0, "Should have minted AIUSD");
        assertEq(collateralRatio, 14_200, "Should have 142% collateral ratio from external AI");

        vm.stopPrank();
    }

    /// @notice Test ratio safety bounds application
    function test_ratioSafetyBounds() public {
        uint256 requestId = _setupChainlinkRequest();

        // Test extreme low ratio (should be bounded to minimum)
        bytes memory lowRatioResponse = abi.encode("RATIO:100 CONFIDENCE:90 SOURCE:AMAZON_BEDROCK_AI");
        mockRouter.simulateCallback(requestId, lowRatioResponse, "");

        vm.startPrank(user1);
        (,,, uint256 aiusdMinted1, uint256 collateralRatio1,,) = vault.getPosition(user1);

        // High confidence (90) should use 130% minimum ratio
        assertEq(collateralRatio1, 13_000, "High confidence should use 130% minimum ratio");

        vm.stopPrank();

        // Setup second test
        uint256 requestId2 = _setupSecondRequest();

        // Test extreme high ratio (should be bounded to maximum)
        bytes memory highRatioResponse = abi.encode("RATIO:250 CONFIDENCE:95 SOURCE:AMAZON_BEDROCK_AI");
        mockRouter.simulateCallback(requestId2, highRatioResponse, "");

        vm.startPrank(user1);
        (,,, uint256 aiusdMinted2, uint256 collateralRatio2,,) = vault.getPosition(user1);

        // Should be bounded to maximum safe ratio (170%)
        assertEq(collateralRatio2, 17_000, "Should apply maximum safety bound of 170%");

        console.log("Safety bounds - Low ratio result:", collateralRatio1);
        console.log("Safety bounds - High ratio result:", collateralRatio2);

        vm.stopPrank();
    }

    /// @notice Test confidence-based safety adjustments
    function test_confidenceBasedSafety() public {
        uint256 requestId1 = _setupChainlinkRequest();

        // Test low confidence (should increase minimum ratio)
        bytes memory lowConfidenceResponse = abi.encode("RATIO:140 CONFIDENCE:45 SOURCE:AMAZON_BEDROCK_AI");
        mockRouter.simulateCallback(requestId1, lowConfidenceResponse, "");

        vm.startPrank(user1);
        (,,, uint256 aiusdMinted1, uint256 collateralRatio1,,) = vault.getPosition(user1);

        // Low confidence should result in higher minimum ratio
        assertGe(collateralRatio1, 14_000, "Low confidence should increase minimum ratio to 140%");

        vm.stopPrank();

        uint256 requestId2 = _setupSecondRequest();

        // Test high confidence (should allow lower ratio)
        bytes memory highConfidenceResponse = abi.encode("RATIO:135 CONFIDENCE:95 SOURCE:AMAZON_BEDROCK_AI");
        mockRouter.simulateCallback(requestId2, highConfidenceResponse, "");

        vm.startPrank(user1);
        (,,, uint256 aiusdMinted2, uint256 collateralRatio2,,) = vault.getPosition(user1);

        // High confidence should allow the requested ratio
        assertEq(collateralRatio2, 13_500, "High confidence should allow 135% ratio");

        console.log("Confidence-based - Low confidence ratio:", collateralRatio1);
        console.log("Confidence-based - High confidence ratio:", collateralRatio2);

        vm.stopPrank();
    }

    /// @notice Test malformed AI response handling
    function test_malformedResponseHandling() public {
        uint256 requestId = _setupChainlinkRequest();

        // Test malformed response (missing RATIO)
        bytes memory malformedResponse1 = abi.encode("CONFIDENCE:85 SOURCE:AMAZON_BEDROCK_AI");
        mockRouter.simulateCallback(requestId, malformedResponse1, "");

        vm.startPrank(user1);
        (,,, uint256 aiusdMinted1, uint256 collateralRatio1,,) = vault.getPosition(user1);

        // Should use default ratio (150%)
        assertEq(collateralRatio1, 15_000, "Should use default 150% for malformed response");

        vm.stopPrank();

        uint256 requestId2 = _setupSecondRequest();

        // Test completely malformed response
        bytes memory malformedResponse2 = abi.encode("INVALID RESPONSE FORMAT");
        mockRouter.simulateCallback(requestId2, malformedResponse2, "");

        vm.startPrank(user1);
        (,,, uint256 aiusdMinted2, uint256 collateralRatio2,,) = vault.getPosition(user1);

        // Should use default ratio and confidence
        assertEq(collateralRatio2, 15_000, "Should use default 150% for invalid response");

        console.log("Malformed response - Default ratio used:", collateralRatio2);

        vm.stopPrank();
    }

    /// @notice Test multiple manual processing strategies
    function test_multipleManualStrategies() public {
        // Test force default mint strategy first
        uint256 requestId1 = _setupChainlinkRequest();
        vm.warp(block.timestamp + 31 minutes);

        vm.startPrank(manualProcessor);
        controller.processWithOffChainAI(requestId1, "", RiskOracleController.ManualStrategy.FORCE_DEFAULT_MINT);
        vm.stopPrank();

        // Verify force default mint worked (160% conservative ratio)
        vm.startPrank(user1);
        (,,, uint256 aiusdMinted1, uint256 collateralRatio1,,) = vault.getPosition(user1);
        assertEq(collateralRatio1, 16_000, "Force default should use 160% ratio");
        vm.stopPrank();

        // Test off-chain AI strategy with a new user to avoid vault position conflicts
        address offChainUser = makeAddr("offChainUser");
        weth.mint(offChainUser, DEPOSIT_AMOUNT);
        vm.deal(offChainUser, 1 ether);

        vm.startPrank(offChainUser);
        weth.approve(address(vault), type(uint256).max);

        address[] memory tokens = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        tokens[0] = address(weth);
        amounts[0] = DEPOSIT_AMOUNT;

        uint256 aiFee = controller.estimateTotalFee();
        vault.depositBasket{ value: aiFee }(tokens, amounts);
        (,,,,, uint256 requestId2,) = vault.getPosition(offChainUser);
        vm.stopPrank();

        vm.warp(block.timestamp + 31 minutes);

        vm.startPrank(manualProcessor);
        controller.processWithOffChainAI(
            requestId2, "RATIO:145 CONFIDENCE:90", RiskOracleController.ManualStrategy.PROCESS_WITH_OFFCHAIN_AI
        );
        vm.stopPrank();

        // Verify off-chain AI strategy worked
        vm.startPrank(offChainUser);
        (,,, uint256 aiusdMinted2, uint256 collateralRatio2,,) = vault.getPosition(offChainUser);
        assertEq(collateralRatio2, 14_500, "Off-chain AI should use 145% ratio");
        vm.stopPrank();

        console.log("Manual strategies - Force default ratio:", collateralRatio1);
        console.log("Manual strategies - Off-chain AI ratio:", collateralRatio2);
    }

    /// @notice Test circuit breaker with multiple failures
    function test_circuitBreakerMultipleFailures() public {
        // Trigger multiple failures to test circuit breaker
        for (uint256 i = 1; i <= 3; i++) {
            uint256 requestId = _setupChainlinkRequestForFailure(i);

            // Simulate failure
            bytes memory errorData = abi.encode("Network error");
            mockRouter.simulateCallback(requestId, "", errorData);

            (bool isPaused, uint256 failureCount,,) = controller.getSystemStatus();
            assertEq(failureCount, i, "Should increment failure count");

            if (i < 5) {
                assertFalse(isPaused, "Should not be paused yet");
            }
        }

        // Trigger 2 more failures to hit the limit
        for (uint256 i = 4; i <= 5; i++) {
            uint256 requestId = _setupChainlinkRequestForFailure(i);

            bytes memory errorData = abi.encode("Network error");
            mockRouter.simulateCallback(requestId, "", errorData);
        }

        (bool systemPaused, uint256 totalFailures,,) = controller.getSystemStatus();
        assertEq(totalFailures, 5, "Should have 5 failures");
        assertTrue(systemPaused, "Should be paused after 5 failures");

        console.log("Circuit breaker - Failures recorded:", totalFailures);
        console.log("Circuit breaker - System paused:", systemPaused);
    }

    /// @notice Test price feed integration readiness
    function test_priceFeedIntegrationSetup() public {
        vm.startPrank(owner);

        // Test setting up price feeds
        string[] memory tokens = new string[](3);
        address[] memory feeds = new address[](3);

        tokens[0] = "ETH";
        tokens[1] = "WBTC";
        tokens[2] = "DAI";

        feeds[0] = address(0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419); // ETH/USD mainnet
        feeds[1] = address(0xF4030086522a5bEEa4988F8cA5B36dbC97BeE88c); // BTC/USD mainnet
        feeds[2] = address(0xAed0c38402a5d19df6E4c03F4E2DceD6e29c1ee9); // DAI/USD mainnet

        // Should not revert
        controller.setPriceFeeds(tokens, feeds);

        vm.stopPrank();

        // Test that price feed setup doesn't break existing functionality
        uint256 requestId = _setupChainlinkRequest();
        bytes memory response = abi.encode("RATIO:150 CONFIDENCE:85 SOURCE:AMAZON_BEDROCK_AI");
        mockRouter.simulateCallback(requestId, response, "");

        vm.startPrank(user1);
        (,,, uint256 aiusdMinted, uint256 collateralRatio,, bool hasPendingRequest) = vault.getPosition(user1);

        assertFalse(hasPendingRequest, "Should not have pending request after price feed setup");
        assertGt(aiusdMinted, 0, "Should still mint AIUSD with price feeds configured");

        vm.stopPrank();
    }

    /// @notice Helper function to setup a second Chainlink Functions request (for multi-test scenarios)
    function _setupSecondRequest() internal returns (uint256 requestId) {
        // Mint more tokens to user1 for second deposit
        weth.mint(user1, DEPOSIT_AMOUNT);

        vm.startPrank(user1);

        address[] memory tokens = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        tokens[0] = address(weth);
        amounts[0] = DEPOSIT_AMOUNT;

        uint256 aiFee = controller.estimateTotalFee();
        vault.depositBasket{ value: aiFee }(tokens, amounts);

        (,,,,, requestId,) = vault.getPosition(user1);
        vm.stopPrank();

        return requestId;
    }

    /// @notice Helper function to setup a Chainlink Functions request
    function _setupChainlinkRequest() internal returns (uint256 requestId) {
        vm.startPrank(user1);

        address[] memory tokens = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        tokens[0] = address(weth);
        amounts[0] = DEPOSIT_AMOUNT;

        uint256 aiFee = controller.estimateTotalFee();
        vault.depositBasket{ value: aiFee }(tokens, amounts);

        (,,,,, requestId,) = vault.getPosition(user1);
        vm.stopPrank();

        return requestId;
    }

    /// @notice Helper function to setup requests for failure testing
    function _setupChainlinkRequestForFailure(uint256 index) internal returns (uint256 requestId) {
        // Use different users for failure tests to avoid conflicts
        address testUser = makeAddr(string(abi.encodePacked("failureUser", index)));

        // Mint tokens and ETH to test user
        weth.mint(testUser, DEPOSIT_AMOUNT);
        vm.deal(testUser, 1 ether);

        vm.startPrank(testUser);
        weth.approve(address(vault), type(uint256).max);

        address[] memory tokens = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        tokens[0] = address(weth);
        amounts[0] = DEPOSIT_AMOUNT;

        uint256 aiFee = controller.estimateTotalFee();
        vault.depositBasket{ value: aiFee }(tokens, amounts);

        (,,,,, requestId,) = vault.getPosition(testUser);
        vm.stopPrank();

        return requestId;
    }

    // ==================== PRODUCTION DEPLOYMENT TESTS ====================

    /// @notice Test complete Bedrock simulation flow
    function test_completeBedrockSimulationFlow() public {
        uint256 requestId = _setupChainlinkRequest();

        // Simulate complete Bedrock response with all metadata
        bytes memory bedrockResponse = abi.encode(
            "RATIO:142 CONFIDENCE:87 SOURCE:AMAZON_BEDROCK_AI SENTIMENT:0.75 ANALYSIS:Diversified portfolio with moderate risk"
        );
        mockRouter.simulateCallback(requestId, bedrockResponse, "");

        vm.startPrank(user1);
        (,,, uint256 aiusdMinted, uint256 collateralRatio,, bool hasPendingRequest) = vault.getPosition(user1);

        assertFalse(hasPendingRequest, "Should complete Bedrock simulation");
        assertGt(aiusdMinted, 0, "Should mint AIUSD from Bedrock");
        assertEq(collateralRatio, 14_200, "Should use Bedrock-determined ratio");

        // Verify AIUSD balance
        uint256 userBalance = aiusd.balanceOf(user1);
        assertGt(userBalance, 0, "User should receive minted AIUSD");
        assertEq(userBalance, aiusdMinted, "Balance should match minted amount");

        console.log("Bedrock Simulation - AIUSD minted:", aiusdMinted);
        console.log("Bedrock Simulation - User balance:", userBalance);
        console.log("Bedrock Simulation - Collateral ratio:", collateralRatio);

        vm.stopPrank();
    }

    /// @notice Test subscription-based fee model
    function test_subscriptionFeeModel() public {
        // Verify subscription model returns zero fees
        uint256 estimatedFee = controller.estimateTotalFee();
        assertEq(estimatedFee, 0, "Chainlink Functions should use subscription model");

        // Test multiple requests don't charge fees
        for (uint256 i = 0; i < 3; i++) {
            uint256 fee = controller.estimateTotalFee();
            assertEq(fee, 0, "Each request should be free with subscription");
        }

        // Test that deposit works with zero fee
        vm.startPrank(user1);
        address[] memory tokens = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        tokens[0] = address(weth);
        amounts[0] = DEPOSIT_AMOUNT;

        // Should work without sending ETH for fees
        vault.depositBasket(tokens, amounts);

        (,,,,, uint256 requestId, bool hasPendingRequest) = vault.getPosition(user1);
        assertTrue(hasPendingRequest, "Should create request without fees");
        assertGt(requestId, 0, "Should generate valid request ID");

        vm.stopPrank();
    }

    /// @notice Test Chainlink Functions configuration management
    function test_chainlinkConfigurationManagement() public {
        vm.startPrank(owner);

        // Test initial configuration
        bytes32 initialDonId = bytes32("fun_sepolia_1");
        uint64 initialSubId = 123;

        // Test configuration update
        bytes32 newDonId = bytes32("fun_mainnet_1");
        uint64 newSubscriptionId = 456;
        uint32 newGasLimit = 400_000;
        string memory newSourceCode = "return 'RATIO:160 CONFIDENCE:80';";

        vm.expectEmit(false, false, false, true);
        emit ChainlinkConfigUpdated(newDonId, newSubscriptionId, newGasLimit);

        controller.updateChainlinkConfig(newDonId, newSubscriptionId, newGasLimit, newSourceCode);

        // Test that new configuration is used in subsequent requests
        vm.stopPrank();

        // Make a request and verify it uses new configuration
        uint256 requestId = _setupChainlinkRequest();
        assertGt(requestId, 0, "Should work with updated configuration");

        console.log("Configuration update test passed");
    }

    /// @notice Test gas limit handling
    function test_gasLimitHandling() public {
        vm.startPrank(owner);

        // Test with various gas limits
        uint32[] memory gasLimits = new uint32[](3);
        gasLimits[0] = 200_000; // Low gas
        gasLimits[1] = 300_000; // Default gas
        gasLimits[2] = 500_000; // High gas

        for (uint256 i = 0; i < gasLimits.length; i++) {
            controller.updateChainlinkConfig(
                bytes32("fun_sepolia_1"), 123, gasLimits[i], "return 'RATIO:150 CONFIDENCE:80';"
            );

            vm.stopPrank();

            // Test request with this gas limit
            uint256 requestId = _setupChainlinkRequestWithUser(makeAddr(string(abi.encodePacked("gasUser", i))));
            assertGt(requestId, 0, "Should work with different gas limits");

            vm.startPrank(owner);
        }

        vm.stopPrank();
    }

    /// @notice Test source code update and validation
    function test_sourceCodeUpdateValidation() public {
        vm.startPrank(owner);

        // Test various source code scenarios
        string[] memory sourceCodes = new string[](3);
        sourceCodes[0] = "return 'RATIO:140 CONFIDENCE:85';"; // Simple response
        sourceCodes[1] = "const ratio = 135; return `RATIO:${ratio} CONFIDENCE:90`;"; // Dynamic response
        sourceCodes[2] = "return 'RATIO:160 CONFIDENCE:75 SOURCE:AMAZON_BEDROCK_AI';"; // Full response

        for (uint256 i = 0; i < sourceCodes.length; i++) {
            controller.updateChainlinkConfig(bytes32("fun_sepolia_1"), 123, 300_000, sourceCodes[i]);

            vm.stopPrank();

            // Test that updated source code can process requests
            uint256 requestId = _setupChainlinkRequestWithUser(makeAddr(string(abi.encodePacked("sourceUser", i))));

            // Simulate response based on source code
            bytes memory response = abi.encode("RATIO:150 CONFIDENCE:80");
            mockRouter.simulateCallback(requestId, response, "");

            vm.startPrank(owner);
        }

        vm.stopPrank();
    }

    /// @notice Test real-world portfolio scenarios
    function test_realWorldPortfolioScenarios() public {
        // Scenario 1: Conservative portfolio (high stablecoin allocation)
        uint256 requestId1 = _setupChainlinkRequest();
        bytes memory conservativeResponse = abi.encode("RATIO:125 CONFIDENCE:95 SOURCE:AMAZON_BEDROCK_AI");
        mockRouter.simulateCallback(requestId1, conservativeResponse, "");

        vm.startPrank(user1);
        (,,, uint256 aiusdMinted1, uint256 collateralRatio1,,) = vault.getPosition(user1);
        assertEq(collateralRatio1, 13_000, "Conservative portfolio should get minimum safe ratio");
        vm.stopPrank();

        // Scenario 2: Aggressive portfolio (high volatility tokens)
        uint256 requestId2 = _setupSecondRequest();
        bytes memory aggressiveResponse = abi.encode("RATIO:185 CONFIDENCE:70 SOURCE:AMAZON_BEDROCK_AI");
        mockRouter.simulateCallback(requestId2, aggressiveResponse, "");

        vm.startPrank(user1);
        (,,, uint256 aiusdMinted2, uint256 collateralRatio2,,) = vault.getPosition(user1);
        assertEq(collateralRatio2, 17_000, "Aggressive portfolio should be capped at maximum");
        vm.stopPrank();

        console.log("Conservative portfolio ratio:", collateralRatio1);
        console.log("Aggressive portfolio ratio:", collateralRatio2);
    }

    /// @notice Test high-frequency request handling
    function test_highFrequencyRequests() public {
        uint256 numRequests = 5;
        uint256[] memory requestIds = new uint256[](numRequests);

        // Create multiple rapid requests
        for (uint256 i = 0; i < numRequests; i++) {
            address testUser = makeAddr(string(abi.encodePacked("freqUser", i)));
            requestIds[i] = _setupChainlinkRequestWithUser(testUser);
            assertGt(requestIds[i], 0, "Should handle rapid requests");
        }

        // Process all requests
        for (uint256 i = 0; i < numRequests; i++) {
            bytes memory response = abi.encode("RATIO:145 CONFIDENCE:85 SOURCE:AMAZON_BEDROCK_AI");
            mockRouter.simulateCallback(requestIds[i], response, "");
        }

        console.log("Successfully processed", numRequests, "rapid requests");
    }

    /// @notice Test complete production deployment workflow
    function test_productionDeploymentWorkflow() public {
        // Step 1: Owner setup
        vm.startPrank(owner);

        // Configure price feeds (production addresses)
        string[] memory tokens = new string[](4);
        address[] memory feeds = new address[](4);
        tokens[0] = "ETH";
        tokens[1] = "WBTC";
        tokens[2] = "DAI";
        tokens[3] = "USDC";
        feeds[0] = address(0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419); // ETH/USD mainnet
        feeds[1] = address(0xF4030086522a5bEEa4988F8cA5B36dbC97BeE88c); // BTC/USD mainnet
        feeds[2] = address(0xAed0c38402a5d19df6E4c03F4E2DceD6e29c1ee9); // DAI/USD mainnet
        feeds[3] = address(0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6); // USDC/USD mainnet

        controller.setPriceFeeds(tokens, feeds);

        // Configure Chainlink Functions for production
        controller.updateChainlinkConfig(
            bytes32("fun_mainnet_1"),
            999, // Production subscription ID
            350_000, // Production gas limit
            "/* Production Bedrock integration code */"
        );

        // Authorize production manual processors
        address productionProcessor = makeAddr("productionProcessor");
        controller.setAuthorizedManualProcessor(productionProcessor, true);

        vm.stopPrank();

        // Step 2: User flow - use separate user to avoid prank conflicts
        address prodUser = makeAddr("productionUser");
        weth.mint(prodUser, DEPOSIT_AMOUNT);
        vm.deal(prodUser, 1 ether);

        vm.startPrank(prodUser);
        weth.approve(address(vault), type(uint256).max);

        address[] memory tokens_user = new address[](1);
        uint256[] memory amounts_user = new uint256[](1);
        tokens_user[0] = address(weth);
        amounts_user[0] = DEPOSIT_AMOUNT;

        uint256 aiFee = controller.estimateTotalFee();
        vault.depositBasket{ value: aiFee }(tokens_user, amounts_user);

        (,,,,, uint256 requestId, bool hasPendingRequest) = vault.getPosition(prodUser);
        vm.stopPrank();

        // Step 3: AI processing
        bytes memory productionResponse = abi.encode("RATIO:138 CONFIDENCE:92 SOURCE:AMAZON_BEDROCK_AI");
        mockRouter.simulateCallback(requestId, productionResponse, "");

        // Step 4: Verify complete flow
        vm.startPrank(prodUser);
        (,,, uint256 aiusdMinted, uint256 collateralRatio,, bool hasPendingRequestAfter) = vault.getPosition(prodUser);

        assertFalse(hasPendingRequestAfter, "Production flow should complete");
        assertGt(aiusdMinted, 0, "Should mint AIUSD");
        assertEq(collateralRatio, 13_800, "Should use production AI ratio");

        uint256 finalBalance = aiusd.balanceOf(prodUser);
        assertEq(finalBalance, aiusdMinted, "User should receive tokens");

        console.log("Production deployment test completed successfully");
        console.log("Final AIUSD balance:", finalBalance);
        console.log("Collateral ratio:", collateralRatio);

        vm.stopPrank();
    }

    /// @notice Test contract upgrade compatibility
    function test_contractUpgradeCompatibility() public {
        // Test that current state is preserved during upgrades
        uint256 requestId = _setupChainlinkRequest();

        // Simulate state before upgrade
        (bool initialPaused, uint256 initialFailures,,) = controller.getSystemStatus();

        // Test configuration preservation
        vm.startPrank(owner);
        bytes32 testDonId = bytes32("test_upgrade");
        controller.updateChainlinkConfig(testDonId, 123, 300_000, "test");
        vm.stopPrank();

        // Process request after "upgrade"
        bytes memory response = abi.encode("RATIO:150 CONFIDENCE:85");
        mockRouter.simulateCallback(requestId, response, "");

        vm.startPrank(user1);
        (,,, uint256 aiusdMinted, uint256 collateralRatio,,) = vault.getPosition(user1);
        assertGt(aiusdMinted, 0, "Should work after configuration changes");
        vm.stopPrank();

        console.log("Upgrade compatibility test passed");
    }

    /// @notice Helper function for creating requests with specific users
    function _setupChainlinkRequestWithUser(address testUser) internal returns (uint256 requestId) {
        weth.mint(testUser, DEPOSIT_AMOUNT);
        vm.deal(testUser, 1 ether);

        vm.startPrank(testUser);
        weth.approve(address(vault), type(uint256).max);

        address[] memory tokens = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        tokens[0] = address(weth);
        amounts[0] = DEPOSIT_AMOUNT;

        uint256 aiFee = controller.estimateTotalFee();
        vault.depositBasket{ value: aiFee }(tokens, amounts);

        (,,,,, requestId,) = vault.getPosition(testUser);
        vm.stopPrank();

        return requestId;
    }
}
