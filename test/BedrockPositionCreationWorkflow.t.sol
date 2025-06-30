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
import { MockDAI } from "./mocks/MockDAI.sol";
import { MockWBTC } from "./mocks/MockWBTC.sol";

/// @title BedrockPositionCreationWorkflow Test
/// @notice Comprehensive test suite for the complete Bedrock AI position creation workflow
/// @dev Tests the entire flow: Request → Off-chain AI Analysis → Position Creation
contract BedrockPositionCreationWorkflowTest is Test {
    // Core contracts
    AIStablecoin public aiusd;
    CollateralVault public vault;
    RiskOracleController public controller;
    MockChainlinkFunctionsRouter public mockRouter;

    // Mock tokens
    MockWETH public weth;
    MockDAI public dai;
    MockWBTC public wbtc;

    // Test accounts
    address public owner = makeAddr("owner");
    address public user = makeAddr("user");
    address public manualProcessor = makeAddr("manualProcessor");

    // Test constants
    uint256 public constant INITIAL_BALANCE = 1000 ether;
    uint256 public constant DEPOSIT_AMOUNT = 10 ether;
    uint256 public constant WBTC_AMOUNT = 2e7; // 0.2 WBTC (8 decimals)
    uint256 public constant DAI_AMOUNT = 1000e18; // 1,000 DAI

    // Chainlink Functions config
    bytes32 public constant DON_ID = bytes32("fun_sepolia_1");
    uint64 public constant SUBSCRIPTION_ID = 123;
    string public constant AI_SOURCE_CODE = "return '150,75';"; // ratio,confidence

    function setUp() public {
        vm.startPrank(owner);

        // Deploy mock tokens
        weth = new MockWETH();
        dai = new MockDAI();
        wbtc = new MockWBTC();

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
        vault.addToken(address(dai), 1 * 1e18, 18, "DAI"); // $1 per DAI
        vault.addToken(address(wbtc), 50_000 * 1e18, 8, "WBTC"); // $50000 per BTC

        // Mint tokens to users
        weth.mint(user, INITIAL_BALANCE);
        dai.mint(user, INITIAL_BALANCE * 1000); // More DAI for large amounts
        wbtc.mint(user, 1e8); // 1 WBTC

        vm.stopPrank();

        // Fund users with ETH
        vm.deal(user, 10 ether);

        // Users approve vault
        vm.startPrank(user);
        weth.approve(address(vault), type(uint256).max);
        dai.approve(address(vault), type(uint256).max);
        wbtc.approve(address(vault), type(uint256).max);
        vm.stopPrank();
    }

    /// @notice Test complete Bedrock workflow: Conservative Portfolio (Stablecoins)
    function test_bedrockWorkflowConservativePortfolio() public {
        console.log("\n=== BEDROCK WORKFLOW: Conservative Portfolio (Stablecoins) ===");

        // Step 1: User creates BEDROCK request with stablecoin portfolio
        vm.startPrank(user);

        address[] memory tokens = new address[](2);
        uint256[] memory amounts = new uint256[](2);

        tokens[0] = address(dai);
        amounts[0] = 2000e18; // 2,000 DAI

        tokens[1] = address(dai); // Using DAI as USDC substitute
        amounts[1] = 2000e18; // 2,000 "USDC"

        console.log("Portfolio: 50% DAI, 50% USDC (~$4,000 total)");

        vault.depositBasket(tokens, amounts, IRiskOracleController.Engine.BEDROCK);
        vm.stopPrank();

        // Get request ID
        (,,,,, uint256 requestId, bool hasPending) = vault.getPosition(user);
        assertTrue(hasPending, "Should have pending BEDROCK request");
        console.log("SUCCESS: BEDROCK request created - ID:", requestId);

        // Step 2: Process with Bedrock AI result
        vm.warp(block.timestamp + 31 minutes);

        vm.prank(manualProcessor);
        controller.processWithOffChainAI(
            requestId,
            "RATIO:145 CONFIDENCE:80 SOURCE:BEDROCK_AI",
            RiskOracleController.ManualStrategy.PROCESS_WITH_OFFCHAIN_AI
        );

        // Step 3: Verify results
        (,,, uint256 aiusdMinted, uint256 ratio,,) = vault.getPosition(user);

        assertEq(ratio, 14_500, "Should have 145% collateral ratio");
        assertGt(aiusdMinted, 0, "Should have minted AIUSD");

        console.log("SUCCESS: Position created successfully!");
        console.log("AIUSD Minted:", aiusdMinted / 1e18);
        console.log("Collateral Ratio: 145%");
    }

    /// @notice Test complete Bedrock workflow: Balanced Portfolio (Mixed Assets)
    function test_bedrockWorkflowBalancedPortfolio() public {
        console.log("\n=== BEDROCK WORKFLOW: Balanced Portfolio (Mixed Assets) ===");

        // Step 1: Create balanced portfolio request
        vm.startPrank(user);

        address[] memory tokens = new address[](3);
        uint256[] memory amounts = new uint256[](3);

        tokens[0] = address(dai);
        amounts[0] = DAI_AMOUNT; // 1,000 DAI

        tokens[1] = address(weth);
        amounts[1] = 0.5 ether; // 0.5 WETH

        tokens[2] = address(wbtc);
        amounts[2] = WBTC_AMOUNT; // 0.02 WBTC

        vault.depositBasket(tokens, amounts, IRiskOracleController.Engine.BEDROCK);
        vm.stopPrank();

        // Get request ID
        (,,,,, uint256 requestId,) = vault.getPosition(user);
        console.log("SUCCESS: BEDROCK request created - ID:", requestId);

        // Step 2: Process with Bedrock result
        vm.warp(block.timestamp + 31 minutes);

        vm.prank(manualProcessor);
        controller.processWithOffChainAI(
            requestId,
            "RATIO:150 CONFIDENCE:75 SOURCE:BEDROCK_AI",
            RiskOracleController.ManualStrategy.PROCESS_WITH_OFFCHAIN_AI
        );

        // Step 3: Verify optimal capital efficiency
        (,,, uint256 aiusdMinted, uint256 ratio,,) = vault.getPosition(user);

        assertEq(ratio, 15_000, "Should have 150% collateral ratio");

        console.log("SUCCESS: Position created with optimal efficiency!");
        console.log("AIUSD Minted:", aiusdMinted / 1e18);
        console.log("Collateral Ratio: 150%");
    }

    /// @notice Test Bedrock workflow: High Risk Portfolio (Single Asset)
    function test_bedrockWorkflowHighRiskPortfolio() public {
        console.log("\n=== BEDROCK WORKFLOW: High Risk Portfolio (Single Asset) ===");

        // Step 1: Create high-risk single asset portfolio
        vm.startPrank(user);

        address[] memory tokens = new address[](1);
        uint256[] memory amounts = new uint256[](1);

        tokens[0] = address(wbtc);
        amounts[0] = 1e7; // 0.1 WBTC

        vault.depositBasket(tokens, amounts, IRiskOracleController.Engine.BEDROCK);
        vm.stopPrank();

        // Get request ID
        (,,,,, uint256 requestId,) = vault.getPosition(user);
        console.log("SUCCESS: BEDROCK request created - ID:", requestId);

        // Step 2: Process with conservative ratio
        vm.warp(block.timestamp + 31 minutes);

        vm.prank(manualProcessor);
        controller.processWithOffChainAI(
            requestId,
            "RATIO:180 CONFIDENCE:80 SOURCE:BEDROCK_AI",
            RiskOracleController.ManualStrategy.PROCESS_WITH_OFFCHAIN_AI
        );

        // Step 3: Verify conservative but competitive ratio
        (,,, uint256 aiusdMinted, uint256 ratio,,) = vault.getPosition(user);

        assertEq(ratio, 17_000, "Should have 170% collateral ratio");

        console.log("SUCCESS: Conservative but competitive position created!");
        console.log("AIUSD Minted:", aiusdMinted / 1e18);
        console.log("Collateral Ratio: 170%");
    }

    /// @notice Test Bedrock workflow error handling and fallbacks
    function test_bedrockWorkflowErrorHandling() public {
        console.log("\n=== BEDROCK WORKFLOW: Error Handling ===");

        // Create request
        vm.startPrank(user);
        address[] memory tokens = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        tokens[0] = address(weth);
        amounts[0] = DEPOSIT_AMOUNT;

        vault.depositBasket(tokens, amounts, IRiskOracleController.Engine.BEDROCK);
        vm.stopPrank();

        // Get request ID
        (,,,,, uint256 requestId,) = vault.getPosition(user);

        vm.warp(block.timestamp + 31 minutes);

        // Test: Invalid Bedrock response format
        vm.prank(manualProcessor);
        controller.processWithOffChainAI(
            requestId, "INVALID BEDROCK RESPONSE", RiskOracleController.ManualStrategy.PROCESS_WITH_OFFCHAIN_AI
        );

        // Should use default safe ratio
        (,,, uint256 aiusdMinted, uint256 ratio,,) = vault.getPosition(user);
        assertEq(ratio, 15_000, "Should use default 150% for invalid response");
        console.log("SUCCESS: Invalid response handled with safe default: 150%");
    }

    /// @notice Test Bedrock workflow comparison with other engines
    function test_bedrockWorkflowComparison() public {
        console.log("\n=== ENGINE COMPARISON: ALGO vs BEDROCK ===");

        address[] memory tokens = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        tokens[0] = address(weth);
        amounts[0] = DEPOSIT_AMOUNT;

        address user1 = makeAddr("algoUser");
        address user2 = makeAddr("bedrockUser");

        // Setup users
        weth.mint(user1, DEPOSIT_AMOUNT);
        weth.mint(user2, DEPOSIT_AMOUNT);

        vm.prank(user1);
        weth.approve(address(vault), type(uint256).max);
        vm.prank(user2);
        weth.approve(address(vault), type(uint256).max);

        // Test ALGO engine
        vm.prank(user1);
        vault.depositBasket(tokens, amounts, IRiskOracleController.Engine.ALGO);
        (,,,,, uint256 algoRequestId,) = vault.getPosition(user1);

        bytes memory algoResponse = abi.encode("RATIO:160 CONFIDENCE:70 SOURCE:ALGORITHMIC_AI");
        mockRouter.simulateCallback(algoRequestId, algoResponse, "");

        // Test BEDROCK engine
        vm.prank(user2);
        vault.depositBasket(tokens, amounts, IRiskOracleController.Engine.BEDROCK);
        (,,,,, uint256 bedrockRequestId,) = vault.getPosition(user2);

        vm.warp(block.timestamp + 31 minutes);
        vm.prank(manualProcessor);
        controller.processWithOffChainAI(
            bedrockRequestId,
            "RATIO:140 CONFIDENCE:85 SOURCE:BEDROCK_AI",
            RiskOracleController.ManualStrategy.PROCESS_WITH_OFFCHAIN_AI
        );

        // Compare results
        (,,, uint256 algoAIUSD, uint256 algoRatio,,) = vault.getPosition(user1);
        (,,, uint256 bedrockAIUSD, uint256 bedrockRatio,,) = vault.getPosition(user2);

        console.log("ALGO Engine - Ratio:", algoRatio / 100, "bps, AIUSD:", algoAIUSD / 1e18);
        console.log("BEDROCK Engine - Ratio:", bedrockRatio / 100, "bps, AIUSD:", bedrockAIUSD / 1e18);

        // BEDROCK should provide better capital efficiency
        assertLt(bedrockRatio, algoRatio, "BEDROCK should provide better (lower) ratio");
        assertGt(bedrockAIUSD, algoAIUSD, "BEDROCK should mint more AIUSD");

        console.log("SUCCESS: BEDROCK provides superior capital efficiency!");
    }
}
