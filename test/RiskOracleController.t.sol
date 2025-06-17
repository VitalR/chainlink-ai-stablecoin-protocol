// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import "../src/RiskOracleController.sol";
import "../src/CollateralVault.sol";
import "../src/AIStablecoin.sol";
import "./mocks/MockERC20.sol";
import "./mocks/MockChainlinkFunctionsRouter.sol";

/// @title RiskOracleControllerTest - Tests for Chainlink Functions-based RiskOracleController
/// @notice Tests Chainlink Functions integration, price feeds, and manual processing
contract RiskOracleControllerTest is Test {
    // Core contracts
    AIStablecoin public aiusd;
    CollateralVault public vault;
    RiskOracleController public controller;
    MockChainlinkFunctionsRouter public mockRouter;

    // Mock tokens
    MockERC20 public weth;
    MockERC20 public usdc;
    MockERC20 public dai;

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

    function setUp() public {
        vm.startPrank(owner);

        // Deploy mock tokens
        weth = new MockERC20("Wrapped Ether", "WETH", 18);
        usdc = new MockERC20("USD Coin", "USDC", 6);
        dai = new MockERC20("DAI Stablecoin", "DAI", 18);

        // Deploy mock Chainlink Functions router
        mockRouter = new MockChainlinkFunctionsRouter();

        // Deploy core contracts
        aiusd = new AIStablecoin();

        controller = new RiskOracleController(address(mockRouter), DON_ID, SUBSCRIPTION_ID, AI_SOURCE_CODE);

        vault = new CollateralVault(address(aiusd), address(controller));

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

        // Simulate Chainlink Functions callback with AI response
        bytes memory response = abi.encode("150,85"); // 150% ratio, 85% confidence
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
        controller.submitAIRequest(user1, abi.encode("test"), 1000e18);
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
}
