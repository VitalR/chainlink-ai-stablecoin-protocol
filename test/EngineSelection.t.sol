// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import { AIStablecoin } from "../src/AIStablecoin.sol";
import { CollateralVault } from "../src/CollateralVault.sol";
import { RiskOracleController } from "../src/RiskOracleController.sol";
import { IRiskOracleController } from "../src/interfaces/IRiskOracleController.sol";

import { MockChainlinkFunctionsRouter } from "./mocks/MockChainlinkFunctionsRouter.sol";
import { MockWETH } from "./mocks/MockWETH.sol";

/// @title EngineSelectionTest - Tests for AI Engine Selection Functionality
/// @notice Tests the new Engine enum and user choice of AI engines
contract EngineSelectionTest is Test {
    // Core contracts
    AIStablecoin public aiusd;
    CollateralVault public vault;
    RiskOracleController public controller;
    MockChainlinkFunctionsRouter public mockRouter;
    MockWETH public weth;

    // Test accounts
    address public owner = makeAddr("owner");
    address public user1 = makeAddr("user1");
    address public user2 = makeAddr("user2");

    // Test constants
    uint256 public constant INITIAL_BALANCE = 1000 ether;
    uint256 public constant DEPOSIT_AMOUNT = 10 ether;

    // Chainlink Functions config
    bytes32 public constant DON_ID = bytes32("fun_sepolia_1");
    uint64 public constant SUBSCRIPTION_ID = 123;
    string public constant AI_SOURCE_CODE = "return 'RATIO:150 CONFIDENCE:75';";

    // Events to test
    event AIRequestSubmitted(
        uint256 indexed internalRequestId, bytes32 indexed chainlinkRequestId, address indexed user, address vault
    );

    function setUp() public {
        vm.startPrank(owner);

        // Deploy mock tokens and router
        weth = new MockWETH();
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

        // Setup token prices in vault
        vault.addToken(address(weth), 2000 * 1e18, 18, "WETH"); // $2000 per ETH

        // Mint tokens to users
        weth.mint(user1, INITIAL_BALANCE);
        weth.mint(user2, INITIAL_BALANCE);

        vm.stopPrank();

        // Fund users with ETH
        vm.deal(user1, 10 ether);
        vm.deal(user2, 10 ether);

        // Users approve vault
        vm.startPrank(user1);
        weth.approve(address(vault), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(user2);
        weth.approve(address(vault), type(uint256).max);
        vm.stopPrank();
    }

    /// @notice Test ALGO engine selection
    function test_algoEngineSelection() public {
        vm.startPrank(user1);

        address[] memory tokens = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        tokens[0] = address(weth);
        amounts[0] = DEPOSIT_AMOUNT;

        // Explicitly choose ALGO engine
        vault.depositBasket(tokens, amounts, IRiskOracleController.Engine.ALGO);

        // Verify request was created
        (,,,,, uint256 requestId, bool hasPendingRequest) = vault.getPosition(user1);
        assertTrue(hasPendingRequest, "Should have pending request");
        assertGt(requestId, 0, "Should have valid request ID");

        // Get request info and verify engine
        RiskOracleController.RequestInfo memory requestInfo = controller.getRequestInfo(requestId);
        assertEq(uint256(requestInfo.engine), uint256(IRiskOracleController.Engine.ALGO), "Should use ALGO engine");
        assertEq(requestInfo.user, user1, "Should track correct user");
        assertEq(requestInfo.vault, address(vault), "Should track correct vault");

        vm.stopPrank();

        console.log("ALGO Engine - Request ID:", requestId);
        console.log("ALGO Engine - Engine type:", uint256(requestInfo.engine));
    }

    /// @notice Test BEDROCK engine selection
    function test_bedrockEngineSelection() public {
        vm.startPrank(user1);

        address[] memory tokens = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        tokens[0] = address(weth);
        amounts[0] = DEPOSIT_AMOUNT;

        // Explicitly choose BEDROCK engine
        vault.depositBasket(tokens, amounts, IRiskOracleController.Engine.BEDROCK);

        // Verify request was created
        (,,,,, uint256 requestId, bool hasPendingRequest) = vault.getPosition(user1);
        assertTrue(hasPendingRequest, "Should have pending request");
        assertGt(requestId, 0, "Should have valid request ID");

        // Get request info and verify engine
        RiskOracleController.RequestInfo memory requestInfo = controller.getRequestInfo(requestId);
        assertEq(
            uint256(requestInfo.engine), uint256(IRiskOracleController.Engine.BEDROCK), "Should use BEDROCK engine"
        );
        assertEq(requestInfo.user, user1, "Should track correct user");

        vm.stopPrank();

        console.log("BEDROCK Engine - Request ID:", requestId);
        console.log("BEDROCK Engine - Engine type:", uint256(requestInfo.engine));
    }

    /// @notice Test TEST_TIMEOUT engine selection (for automation testing)
    function test_testTimeoutEngineSelection() public {
        vm.startPrank(user1);

        address[] memory tokens = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        tokens[0] = address(weth);
        amounts[0] = DEPOSIT_AMOUNT;

        // Choose TEST_TIMEOUT engine
        vault.depositBasket(tokens, amounts, IRiskOracleController.Engine.TEST_TIMEOUT);

        // Verify request was created but NOT sent to Chainlink
        (,,,,, uint256 requestId, bool hasPendingRequest) = vault.getPosition(user1);
        assertTrue(hasPendingRequest, "Should have pending request");
        assertGt(requestId, 0, "Should have valid request ID");

        // Get request info and verify engine
        RiskOracleController.RequestInfo memory requestInfo = controller.getRequestInfo(requestId);
        assertEq(
            uint256(requestInfo.engine),
            uint256(IRiskOracleController.Engine.TEST_TIMEOUT),
            "Should use TEST_TIMEOUT engine"
        );
        assertEq(requestInfo.user, user1, "Should track correct user");
        assertFalse(requestInfo.processed, "Should not be processed yet");

        vm.stopPrank();

        console.log("TEST_TIMEOUT Engine - Request ID:", requestId);
        console.log("TEST_TIMEOUT Engine - Engine type:", uint256(requestInfo.engine));
        console.log("TEST_TIMEOUT - Creates stuck request for automation testing");
    }

    /// @notice Test backward compatibility (defaults to ALGO)
    function test_backwardCompatibility() public {
        vm.startPrank(user1);

        address[] memory tokens = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        tokens[0] = address(weth);
        amounts[0] = DEPOSIT_AMOUNT;

        // Use old function signature (should default to ALGO)
        vault.depositBasket(tokens, amounts);

        // Verify request was created
        (,,,,, uint256 requestId, bool hasPendingRequest) = vault.getPosition(user1);
        assertTrue(hasPendingRequest, "Should have pending request");
        assertGt(requestId, 0, "Should have valid request ID");

        // Get request info and verify it defaults to ALGO
        RiskOracleController.RequestInfo memory requestInfo = controller.getRequestInfo(requestId);
        assertEq(
            uint256(requestInfo.engine), uint256(IRiskOracleController.Engine.ALGO), "Should default to ALGO engine"
        );

        vm.stopPrank();

        console.log("Backward Compatibility - Request ID:", requestId);
        console.log("Backward Compatibility - Engine type (should be ALGO):", uint256(requestInfo.engine));
    }

    /// @notice Test multiple users with different engines
    function test_multipleUsersWithDifferentEngines() public {
        // User 1 chooses ALGO
        vm.startPrank(user1);
        address[] memory tokens1 = new address[](1);
        uint256[] memory amounts1 = new uint256[](1);
        tokens1[0] = address(weth);
        amounts1[0] = DEPOSIT_AMOUNT;
        vault.depositBasket(tokens1, amounts1, IRiskOracleController.Engine.ALGO);
        (,,,,, uint256 requestId1,) = vault.getPosition(user1);
        vm.stopPrank();

        // User 2 chooses BEDROCK
        vm.startPrank(user2);
        address[] memory tokens2 = new address[](1);
        uint256[] memory amounts2 = new uint256[](1);
        tokens2[0] = address(weth);
        amounts2[0] = DEPOSIT_AMOUNT;
        vault.depositBasket(tokens2, amounts2, IRiskOracleController.Engine.BEDROCK);
        (,,,,, uint256 requestId2,) = vault.getPosition(user2);
        vm.stopPrank();

        // Verify different engines were chosen
        RiskOracleController.RequestInfo memory requestInfo1 = controller.getRequestInfo(requestId1);
        RiskOracleController.RequestInfo memory requestInfo2 = controller.getRequestInfo(requestId2);

        assertEq(uint256(requestInfo1.engine), uint256(IRiskOracleController.Engine.ALGO), "User1 should use ALGO");
        assertEq(
            uint256(requestInfo2.engine), uint256(IRiskOracleController.Engine.BEDROCK), "User2 should use BEDROCK"
        );
        assertEq(requestInfo1.user, user1, "Should track user1 correctly");
        assertEq(requestInfo2.user, user2, "Should track user2 correctly");

        console.log("Multi-user - User1 engine:", uint256(requestInfo1.engine));
        console.log("Multi-user - User2 engine:", uint256(requestInfo2.engine));
    }

    /// @notice Test ALGO engine processing
    function test_algoEngineProcessing() public {
        // Setup ALGO request
        vm.startPrank(user1);
        address[] memory tokens = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        tokens[0] = address(weth);
        amounts[0] = DEPOSIT_AMOUNT;
        vault.depositBasket(tokens, amounts, IRiskOracleController.Engine.ALGO);
        (,,,,, uint256 requestId,) = vault.getPosition(user1);
        vm.stopPrank();

        // Simulate ALGO response
        bytes memory algoResponse = abi.encode("RATIO:140 CONFIDENCE:80 SOURCE:ALGORITHMIC_AI");
        mockRouter.simulateCallback(requestId, algoResponse, "");

        // Verify processing completed
        vm.startPrank(user1);
        (,,, uint256 aiusdMinted, uint256 collateralRatio,, bool hasPendingRequest) = vault.getPosition(user1);

        assertFalse(hasPendingRequest, "Should not have pending request");
        assertGt(aiusdMinted, 0, "Should have minted AIUSD");
        assertEq(collateralRatio, 14_000, "Should have 140% collateral ratio");

        vm.stopPrank();

        console.log("ALGO Processing - AIUSD minted:", aiusdMinted);
        console.log("ALGO Processing - Collateral ratio:", collateralRatio);
    }

    /// @notice Test BEDROCK engine processing
    function test_bedrockEngineProcessing() public {
        // Setup BEDROCK request
        vm.startPrank(user1);
        address[] memory tokens = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        tokens[0] = address(weth);
        amounts[0] = DEPOSIT_AMOUNT;
        vault.depositBasket(tokens, amounts, IRiskOracleController.Engine.BEDROCK);
        (,,,,, uint256 requestId,) = vault.getPosition(user1);
        vm.stopPrank();

        // Simulate BEDROCK response
        bytes memory bedrockResponse = abi.encode("RATIO:135 CONFIDENCE:90 SOURCE:AMAZON_BEDROCK_AI");
        mockRouter.simulateCallback(requestId, bedrockResponse, "");

        // Verify processing completed
        vm.startPrank(user1);
        (,,, uint256 aiusdMinted, uint256 collateralRatio,, bool hasPendingRequest) = vault.getPosition(user1);

        assertFalse(hasPendingRequest, "Should not have pending request");
        assertGt(aiusdMinted, 0, "Should have minted AIUSD");
        assertEq(collateralRatio, 13_500, "Should have 135% collateral ratio");

        vm.stopPrank();

        console.log("BEDROCK Processing - AIUSD minted:", aiusdMinted);
        console.log("BEDROCK Processing - Collateral ratio:", collateralRatio);
    }

    /// @notice Test TEST_TIMEOUT engine behavior (no processing, stuck for automation)
    function test_testTimeoutEngineTimeout() public {
        // Setup TEST_TIMEOUT request
        vm.startPrank(user1);
        address[] memory tokens = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        tokens[0] = address(weth);
        amounts[0] = DEPOSIT_AMOUNT;
        vault.depositBasket(tokens, amounts, IRiskOracleController.Engine.TEST_TIMEOUT);
        (,,,,, uint256 requestId,) = vault.getPosition(user1);
        vm.stopPrank();

        // Verify request stays stuck (doesn't process automatically)
        RiskOracleController.RequestInfo memory requestInfo = controller.getRequestInfo(requestId);
        assertFalse(requestInfo.processed, "Should remain unprocessed");
        assertEq(
            uint256(requestInfo.engine),
            uint256(IRiskOracleController.Engine.TEST_TIMEOUT),
            "Should be TEST_TIMEOUT engine"
        );

        // Fast forward time to simulate timeout
        vm.warp(block.timestamp + 2.1 hours);

        // User should be able to request emergency withdrawal
        vm.startPrank(user1);

        // Verify user can now do emergency withdrawal
        uint256 initialBalance = weth.balanceOf(user1);
        controller.emergencyWithdraw(requestId);
        uint256 finalBalance = weth.balanceOf(user1);

        assertEq(finalBalance, initialBalance + DEPOSIT_AMOUNT, "Should get collateral back via emergency withdrawal");

        vm.stopPrank();

        console.log("TEST_TIMEOUT - Successfully triggered emergency withdrawal");
        console.log("TEST_TIMEOUT - This tests automation functionality");
    }

    /// @notice Test engine selection with different fee scenarios
    function test_engineSelectionWithFees() public {
        uint256 aiFee = controller.estimateTotalFee();
        assertEq(aiFee, 0, "Should be 0 for subscription model");

        vm.startPrank(user1);

        address[] memory tokens = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        tokens[0] = address(weth);
        amounts[0] = DEPOSIT_AMOUNT;

        // Test all engines work with zero fees
        vault.depositBasket{ value: aiFee }(tokens, amounts, IRiskOracleController.Engine.ALGO);
        (,,,,, uint256 requestId1,) = vault.getPosition(user1);
        assertGt(requestId1, 0, "ALGO should work with subscription fees");

        // Mint more for second deposit
        vm.stopPrank();
        weth.mint(user1, DEPOSIT_AMOUNT);
        vm.startPrank(user1);

        vault.depositBasket{ value: aiFee }(tokens, amounts, IRiskOracleController.Engine.BEDROCK);
        (,,,,, uint256 requestId2,) = vault.getPosition(user1);
        assertGt(requestId2, 0, "BEDROCK should work with subscription fees");

        vm.stopPrank();

        console.log("Fee Test - ALGO request:", requestId1);
        console.log("Fee Test - BEDROCK request:", requestId2);
    }

    /// @notice Test engine enum values
    function test_engineEnumValues() public {
        // Test that enum values are correct
        uint256 algoValue = uint256(IRiskOracleController.Engine.ALGO);
        uint256 bedrockValue = uint256(IRiskOracleController.Engine.BEDROCK);
        uint256 testTimeoutValue = uint256(IRiskOracleController.Engine.TEST_TIMEOUT);

        assertEq(algoValue, 0, "ALGO should be 0");
        assertEq(bedrockValue, 1, "BEDROCK should be 1");
        assertEq(testTimeoutValue, 2, "TEST_TIMEOUT should be 2");

        console.log("Enum Values - ALGO:", algoValue);
        console.log("Enum Values - BEDROCK:", bedrockValue);
        console.log("Enum Values - TEST_TIMEOUT:", testTimeoutValue);
    }

    /// @notice Test engine selection persistence across requests
    function test_engineSelectionPersistence() public {
        vm.startPrank(user1);

        // Make multiple requests with same engine
        for (uint256 i = 0; i < 3; i++) {
            weth.mint(user1, DEPOSIT_AMOUNT);

            address[] memory tokens = new address[](1);
            uint256[] memory amounts = new uint256[](1);
            tokens[0] = address(weth);
            amounts[0] = DEPOSIT_AMOUNT;

            vault.depositBasket(tokens, amounts, IRiskOracleController.Engine.BEDROCK);
            (,,,,, uint256 requestId,) = vault.getPosition(user1);

            RiskOracleController.RequestInfo memory requestInfo = controller.getRequestInfo(requestId);
            assertEq(
                uint256(requestInfo.engine),
                uint256(IRiskOracleController.Engine.BEDROCK),
                "Should persist BEDROCK choice"
            );

            console.log("Persistence Test - Request", i + 1, "Engine:", uint256(requestInfo.engine));
        }

        vm.stopPrank();
    }

    /// @notice Test direct controller submission with engines
    function test_directControllerSubmissionWithEngines() public {
        // Test that only authorized callers can submit
        vm.startPrank(user1);
        vm.expectRevert(RiskOracleController.UnauthorizedCaller.selector);
        controller.submitAIRequest(user1, abi.encode("test"), 1000e18, RiskOracleController.Engine.ALGO);
        vm.stopPrank();

        // Test authorized caller can submit with all engines
        vm.startPrank(address(vault));

        uint256 requestId1 =
            controller.submitAIRequest(user1, abi.encode("test1"), 1000e18, RiskOracleController.Engine.ALGO);
        uint256 requestId2 =
            controller.submitAIRequest(user1, abi.encode("test2"), 1000e18, RiskOracleController.Engine.BEDROCK);
        uint256 requestId3 =
            controller.submitAIRequest(user1, abi.encode("test3"), 1000e18, RiskOracleController.Engine.TEST_TIMEOUT);

        assertGt(requestId1, 0, "Should submit ALGO request");
        assertGt(requestId2, 0, "Should submit BEDROCK request");
        assertGt(requestId3, 0, "Should submit TEST_TIMEOUT request");

        // Verify engines are tracked correctly
        RiskOracleController.RequestInfo memory info1 = controller.getRequestInfo(requestId1);
        RiskOracleController.RequestInfo memory info2 = controller.getRequestInfo(requestId2);
        RiskOracleController.RequestInfo memory info3 = controller.getRequestInfo(requestId3);

        assertEq(uint256(info1.engine), uint256(IRiskOracleController.Engine.ALGO), "Should track ALGO");
        assertEq(uint256(info2.engine), uint256(IRiskOracleController.Engine.BEDROCK), "Should track BEDROCK");
        assertEq(uint256(info3.engine), uint256(IRiskOracleController.Engine.TEST_TIMEOUT), "Should track TEST_TIMEOUT");

        vm.stopPrank();

        console.log("Direct Controller - ALGO request:", requestId1);
        console.log("Direct Controller - BEDROCK request:", requestId2);
        console.log("Direct Controller - TEST_TIMEOUT request:", requestId3);
    }
}
