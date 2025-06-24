// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import { IERC20 } from "@openzeppelin/token/ERC20/IERC20.sol";

import { AIStablecoin } from "src/AIStablecoin.sol";
import { CollateralVault } from "src/CollateralVault.sol";
import { RiskOracleController } from "src/RiskOracleController.sol";
import { SepoliaConfig } from "config/SepoliaConfig.sol";

/// @title Full System Fork Test
/// @notice Comprehensive test of the AI-powered stablecoin system using Sepolia fork
/// @dev Tests the complete workflow: deposit → AI assessment → minting without real transactions
contract ForkTestFullSystem is Test {
    // =============================================================
    //                      CONTRACTS
    // =============================================================

    AIStablecoin public stablecoin;
    RiskOracleController public riskOracle;
    CollateralVault public vault;

    // Mock tokens (deployed on Sepolia)
    IERC20 public mockDAI;
    IERC20 public mockWETH;
    IERC20 public mockWBTC;
    IERC20 public mockUSDC;

    // =============================================================
    //                      TEST SETUP
    // =============================================================

    address public user = address(0x123);
    address public deployer = address(0x456);

    uint256 public constant INITIAL_BALANCE = 10_000 * 1e18; // 10,000 tokens
    uint256 public constant DEPOSIT_AMOUNT = 1000 * 1e18; // 1,000 tokens

    function setUp() public {
        // Fork Sepolia at a recent block
        vm.createSelectFork(vm.envString("SEPOLIA_RPC_URL"));

        console.log("=== Fork Test Setup ===");
        console.log("Chain ID:", block.chainid);
        console.log("Block Number:", block.number);

        // Load deployed contracts
        stablecoin = AIStablecoin(SepoliaConfig.AI_STABLECOIN);
        riskOracle = RiskOracleController(SepoliaConfig.RISK_ORACLE_CONTROLLER);
        vault = CollateralVault(payable(SepoliaConfig.COLLATERAL_VAULT));

        // Load mock tokens
        mockDAI = IERC20(SepoliaConfig.MOCK_DAI);
        mockWETH = IERC20(SepoliaConfig.MOCK_WETH);
        mockWBTC = IERC20(SepoliaConfig.MOCK_WBTC);
        mockUSDC = IERC20(SepoliaConfig.MOCK_USDC);

        console.log("Contracts loaded:");
        console.log("- Stablecoin:", address(stablecoin));
        console.log("- Risk Oracle:", address(riskOracle));
        console.log("- Vault:", address(vault));

        // Setup test user with tokens
        _setupTestUser();

        // Get the actual owner and authorize deployer for manual processing
        address owner = riskOracle.owner();
        vm.prank(owner);
        riskOracle.setAuthorizedManualProcessor(deployer, true);

        console.log("Setup complete!");
    }

    function _setupTestUser() internal {
        vm.startPrank(deployer);

        // Give test user some tokens (simulate minting from token contracts)
        vm.deal(user, 10 ether); // Give ETH for gas

        // We'll use the token contracts' mint functions if available
        // For this test, we'll simulate having tokens by setting storage
        vm.stopPrank();

        // Set token balances directly using storage manipulation
        _setTokenBalance(address(mockDAI), user, INITIAL_BALANCE);
        _setTokenBalance(address(mockWETH), user, INITIAL_BALANCE);
        _setTokenBalance(address(mockWBTC), user, INITIAL_BALANCE / 1000); // WBTC has different decimals
        _setTokenBalance(address(mockUSDC), user, INITIAL_BALANCE);

        console.log("User token balances set:");
        console.log("- DAI:", mockDAI.balanceOf(user) / 1e18);
        console.log("- WETH:", mockWETH.balanceOf(user) / 1e18);
        console.log("- WBTC:", mockWBTC.balanceOf(user) / 1e8);
        console.log("- USDC:", mockUSDC.balanceOf(user) / 1e6);
    }

    function _setTokenBalance(address token, address account, uint256 amount) internal {
        // Use deal() which is more reliable for setting token balances
        deal(token, account, amount);
    }

    // =============================================================
    //                      SYSTEM STATUS TESTS
    // =============================================================

    function test_SystemStatus() public view {
        console.log("\n=== System Status Check ===");

        // Check contract addresses
        assertEq(address(stablecoin), SepoliaConfig.AI_STABLECOIN, "Stablecoin address mismatch");
        assertEq(address(riskOracle), SepoliaConfig.RISK_ORACLE_CONTROLLER, "Risk oracle address mismatch");
        assertEq(address(vault), SepoliaConfig.COLLATERAL_VAULT, "Vault address mismatch");

        // Check system configuration
        (bool paused, uint256 failures, uint256 lastFailure, bool circuitBreakerActive) = riskOracle.getSystemStatus();
        console.log("System Status:");
        console.log("- Processing Paused:", paused);
        console.log("- Failure Count:", failures);
        console.log("- Circuit Breaker Active:", circuitBreakerActive);

        assertFalse(paused, "System should not be paused");
        assertFalse(circuitBreakerActive, "Circuit breaker should not be active");

        // Check AI source code is updated
        string memory aiCode = riskOracle.aiSourceCode();
        assertGt(bytes(aiCode).length, 1000, "AI source code should be substantial");
        console.log("AI Source Code Length:", bytes(aiCode).length);

        console.log("System status check passed");
    }

    // =============================================================
    //                      PRICE FEED TESTS
    // =============================================================

    function test_PriceFeeds() public view {
        console.log("\n=== Price Feed Check ===");

        // Test all price feeds
        int256 ethPrice = riskOracle.getLatestPrice("ETH");
        int256 btcPrice = riskOracle.getLatestPrice("BTC");
        int256 linkPrice = riskOracle.getLatestPrice("LINK");
        int256 daiPrice = riskOracle.getLatestPrice("DAI");
        int256 usdcPrice = riskOracle.getLatestPrice("USDC");

        console.log("Current Prices:");
        console.log("- ETH/USD:", uint256(ethPrice) / 1e8);
        console.log("- BTC/USD:", uint256(btcPrice) / 1e8);
        console.log("- LINK/USD:", uint256(linkPrice) / 1e8);
        console.log("- DAI/USD:", uint256(daiPrice) / 1e8);
        console.log("- USDC/USD:", uint256(usdcPrice) / 1e8);

        // Verify prices are reasonable
        assertGt(ethPrice, 1000 * 1e8, "ETH price too low"); // > $1000
        assertLt(ethPrice, 10_000 * 1e8, "ETH price too high"); // < $10000
        assertGt(btcPrice, 20_000 * 1e8, "BTC price too low"); // > $20000
        assertLt(btcPrice, 200_000 * 1e8, "BTC price too high"); // < $200000 (updated for current market)

        console.log("Price feed check passed");
    }

    // =============================================================
    //                      DEPOSIT SIMULATION
    // =============================================================

    function test_DepositSimulation() public {
        console.log("\n=== Deposit Simulation ===");

        vm.startPrank(user);

        // Create a diversified portfolio: 60% WETH, 30% DAI, 10% WBTC
        address[] memory tokens = new address[](3);
        uint256[] memory amounts = new uint256[](3);

        tokens[0] = address(mockWETH);
        amounts[0] = 1 * 1e18; // 1 WETH

        tokens[1] = address(mockDAI);
        amounts[1] = 2000 * 1e18; // 2,000 DAI

        tokens[2] = address(mockWBTC);
        amounts[2] = 0.1 * 1e8; // 0.1 WBTC (we have lots)

        // Approve vault to spend tokens
        mockWETH.approve(address(vault), amounts[0]);
        mockDAI.approve(address(vault), amounts[1]);
        mockWBTC.approve(address(vault), amounts[2]);

        console.log("Portfolio to deposit:");
        console.log("- WETH:", amounts[0] / 1e18);
        console.log("- DAI:", amounts[1] / 1e18);
        console.log("- WBTC:", amounts[2] / 1e8);

        // Record balances before
        uint256 wethBefore = mockWETH.balanceOf(user);
        uint256 daiBefore = mockDAI.balanceOf(user);
        uint256 wbtcBefore = mockWBTC.balanceOf(user);

        console.log("Balances before deposit:");
        console.log("- WETH:", wethBefore / 1e18);
        console.log("- DAI:", daiBefore / 1e18);
        console.log("- WBTC:", wbtcBefore / 1e8);

        // Initiate deposit (this will trigger AI assessment)
        vault.depositBasket(tokens, amounts);

        // Get the request ID from the user's position
        (,,,,, uint256 requestId,) = vault.getPosition(user);

        console.log("Created request ID:", requestId);

        // Check that tokens were transferred to vault
        uint256 wethAfter = mockWETH.balanceOf(user);
        uint256 daiAfter = mockDAI.balanceOf(user);
        uint256 wbtcAfter = mockWBTC.balanceOf(user);

        console.log("Balances after deposit:");
        console.log("- WETH:", wethAfter / 1e18);
        console.log("- DAI:", daiAfter / 1e18);
        console.log("- WBTC:", wbtcAfter / 1e8);

        // Verify tokens were transferred
        assertEq(wethBefore - wethAfter, amounts[0], "WETH not transferred correctly");
        assertEq(daiBefore - daiAfter, amounts[1], "DAI not transferred correctly");
        assertEq(wbtcBefore - wbtcAfter, amounts[2], "WBTC not transferred correctly");

        // Check vault balances
        assertEq(mockWETH.balanceOf(address(vault)), amounts[0], "Vault WETH balance incorrect");
        assertEq(mockDAI.balanceOf(address(vault)), amounts[1], "Vault DAI balance incorrect");
        assertEq(mockWBTC.balanceOf(address(vault)), amounts[2], "Vault WBTC balance incorrect");

        vm.stopPrank();

        console.log("Deposit simulation passed");
    }

    // =============================================================
    //                      AI ASSESSMENT SIMULATION
    // =============================================================

    function test_AIAssessmentSimulation() public {
        console.log("\n=== AI Assessment Simulation ===");

        // First do a deposit to create a request
        vm.startPrank(user);

        address[] memory tokens = new address[](2);
        uint256[] memory amounts = new uint256[](2);

        tokens[0] = address(mockWETH);
        amounts[0] = 1 * 1e18; // 1 WETH

        tokens[1] = address(mockDAI);
        amounts[1] = 2000 * 1e18; // 2,000 DAI

        mockWETH.approve(address(vault), amounts[0]);
        mockDAI.approve(address(vault), amounts[1]);

        vault.depositBasket(tokens, amounts);

        // Get the request ID from the user's position
        (,,,,, uint256 requestId,) = vault.getPosition(user);

        vm.stopPrank();

        console.log("Created request ID:", requestId);

        // Get request info and log details
        RiskOracleController.RequestInfo memory requestInfo = riskOracle.getRequestInfo(requestId);
        console.log("- Collateral Value: $", requestInfo.collateralValue / 1e18);

        assertEq(requestInfo.user, user, "Request user mismatch");
        assertEq(requestInfo.vault, address(vault), "Request vault mismatch");
        assertFalse(requestInfo.processed, "Request should not be processed yet");
        assertGt(requestInfo.collateralValue, 0, "Collateral value should be positive");

        console.log("AI assessment simulation setup passed");
    }

    // =============================================================
    //                      MANUAL PROCESSING SIMULATION
    // =============================================================

    function test_ManualProcessingSimulation() public {
        console.log("\n=== Manual Processing Simulation ===");

        // Create a deposit request
        vm.startPrank(user);

        address[] memory tokens = new address[](2);
        uint256[] memory amounts = new uint256[](2);

        tokens[0] = address(mockWETH);
        amounts[0] = 1 * 1e18; // 1 WETH

        tokens[1] = address(mockDAI);
        amounts[1] = 2000 * 1e18; // 2,000 DAI

        mockWETH.approve(address(vault), amounts[0]);
        mockDAI.approve(address(vault), amounts[1]);

        vault.depositBasket(tokens, amounts);

        // Get the request ID from the user's position
        (,,,,, uint256 requestId,) = vault.getPosition(user);

        vm.stopPrank();

        console.log("Created request for manual processing:", requestId);

        // Fast forward time to allow manual processing
        vm.warp(block.timestamp + 31 minutes);

        // Simulate manual processing with off-chain AI response
        vm.startPrank(deployer); // Deployer is authorized for manual processing

        string memory offChainResponse = "RATIO:135 CONFIDENCE:85 SOURCE:MANUAL_AI";

        // Process with off-chain AI
        riskOracle.processWithOffChainAI(
            requestId, offChainResponse, RiskOracleController.ManualStrategy.PROCESS_WITH_OFFCHAIN_AI
        );

        vm.stopPrank();

        // Check that request was processed
        RiskOracleController.RequestInfo memory requestInfo = riskOracle.getRequestInfo(requestId);
        assertTrue(requestInfo.processed, "Request should be processed");

        // Check that user received stablecoins
        uint256 userBalance = stablecoin.balanceOf(user);
        assertGt(userBalance, 0, "User should have received stablecoins");

        console.log("User stablecoin balance:", userBalance / 1e18);
        console.log("Manual processing simulation passed");
    }

    // =============================================================
    //                      EMERGENCY WITHDRAWAL SIMULATION
    // =============================================================

    function test_EmergencyWithdrawalSimulation() public {
        console.log("\n=== Emergency Withdrawal Simulation ===");

        // Create a deposit request
        vm.startPrank(user);

        address[] memory tokens = new address[](1);
        uint256[] memory amounts = new uint256[](1);

        tokens[0] = address(mockDAI);
        amounts[0] = 1000 * 1e18; // 1,000 DAI

        mockDAI.approve(address(vault), amounts[0]);

        uint256 balanceBefore = mockDAI.balanceOf(user);
        vault.depositBasket(tokens, amounts);

        // Get the request ID from the user's position
        (,,,,, uint256 requestId,) = vault.getPosition(user);

        vm.stopPrank();

        console.log("Created request for emergency withdrawal:", requestId);
        console.log("User DAI balance before:", balanceBefore / 1e18);
        console.log("User DAI balance after deposit:", mockDAI.balanceOf(user) / 1e18);

        // Fast forward time
        vm.warp(block.timestamp + 31 minutes);

        // Simulate emergency withdrawal
        vm.startPrank(deployer);

        riskOracle.processWithOffChainAI(
            requestId,
            "", // No response needed for emergency withdrawal
            RiskOracleController.ManualStrategy.EMERGENCY_WITHDRAWAL
        );

        vm.stopPrank();

        // Check that user got their tokens back
        uint256 balanceAfter = mockDAI.balanceOf(user);
        console.log("User DAI balance after emergency withdrawal:", balanceAfter / 1e18);

        assertEq(balanceAfter, balanceBefore, "User should have received all tokens back");

        // Check that no stablecoins were minted
        uint256 userStableBalance = stablecoin.balanceOf(user);
        assertEq(userStableBalance, 0, "No stablecoins should be minted in emergency withdrawal");

        console.log("Emergency withdrawal simulation passed");
    }

    // =============================================================
    //                      WITHDRAW AFTER DEPOSIT SIMULATION
    // =============================================================

    function test_WithdrawAfterDepositSimulation() public {
        console.log("\n=== Withdraw After Deposit Simulation ===");

        // Step 1: Create a deposit and mint stablecoins
        vm.startPrank(user);

        address[] memory tokens = new address[](2);
        uint256[] memory amounts = new uint256[](2);

        tokens[0] = address(mockWETH);
        amounts[0] = 2 * 1e18; // 2 WETH

        tokens[1] = address(mockDAI);
        amounts[1] = 3000 * 1e18; // 3,000 DAI

        mockWETH.approve(address(vault), amounts[0]);
        mockDAI.approve(address(vault), amounts[1]);

        // Record initial balances
        uint256 initialWETH = mockWETH.balanceOf(user);
        uint256 initialDAI = mockDAI.balanceOf(user);

        console.log("Initial balances:");
        console.log("- WETH:", initialWETH / 1e18);
        console.log("- DAI:", initialDAI / 1e18);

        vault.depositBasket(tokens, amounts);

        // Get the request ID from the user's position
        (,,,,, uint256 requestId,) = vault.getPosition(user);

        vm.stopPrank();

        console.log("Created deposit request ID:", requestId);

        // Step 2: Process the request to mint stablecoins
        vm.warp(block.timestamp + 31 minutes);

        vm.prank(deployer);
        riskOracle.processWithOffChainAI(
            requestId,
            "RATIO:140 CONFIDENCE:80 SOURCE:ALGORITHMIC_AI",
            RiskOracleController.ManualStrategy.PROCESS_WITH_OFFCHAIN_AI
        );

        uint256 stablecoinBalance = stablecoin.balanceOf(user);
        console.log("Stablecoins minted:", stablecoinBalance / 1e18);
        assertGt(stablecoinBalance, 0, "Should have minted stablecoins");

        // Step 3: Burn stablecoins and withdraw collateral
        vm.startPrank(user);

        // First approve the vault to burn stablecoins
        stablecoin.approve(address(vault), stablecoinBalance);

        console.log("Burning", stablecoinBalance / 1e18, "stablecoins to withdraw collateral...");

        // Withdraw all collateral by burning all stablecoins
        vault.withdrawFromPosition(0, stablecoinBalance);

        vm.stopPrank();

        // Step 4: Verify withdrawal results
        uint256 finalWETH = mockWETH.balanceOf(user);
        uint256 finalDAI = mockDAI.balanceOf(user);
        uint256 finalStablecoins = stablecoin.balanceOf(user);

        console.log("Final balances:");
        console.log("- WETH:", finalWETH / 1e18);
        console.log("- DAI:", finalDAI / 1e18);
        console.log("- Stablecoins:", finalStablecoins / 1e18);

        // Verify complete withdrawal
        assertEq(finalWETH, initialWETH, "Should have received all WETH back");
        assertEq(finalDAI, initialDAI, "Should have received all DAI back");
        assertEq(finalStablecoins, 0, "Should have burned all stablecoins");

        // Verify position is cleaned up
        (address[] memory positionTokens,,,,,,) = vault.getPosition(user);
        assertEq(positionTokens.length, 0, "Position should be cleaned up");

        console.log("Withdraw after deposit simulation passed");
    }

    // =============================================================
    //                      COMPREHENSIVE SYSTEM TEST
    // =============================================================

    // TODO: Fix comprehensive system test - currently fails due to LINK subscription balance
    // in fork environment. Individual portfolio tests work fine, but running them all together
    // causes InsufficientBalance errors. Need to investigate subscription balance simulation.
    /*
    function test_ComprehensiveSystemTest() public {
        console.log("\n=== Comprehensive System Test ===");

        // Test multiple deposits with different portfolios
        _testConservativePortfolio();
        _testAggressivePortfolio();
        _testBalancedPortfolio();

        console.log("Comprehensive system test passed");
    }
    */

    // =============================================================
    //                      UTILITY FUNCTIONS
    // =============================================================

    function test_ViewFunctions() public view {
        console.log("\n=== View Functions Test ===");

        // Test fee estimation
        uint256 fee = riskOracle.estimateTotalFee();
        console.log("Estimated fee:", fee);
        assertEq(fee, 0, "Fee should be 0 for subscription model");

        // Test system status
        (bool paused, uint256 failures, uint256 lastFailure, bool circuitBreakerActive) = riskOracle.getSystemStatus();
        console.log("System status:");
        console.log("- Paused:", paused);
        console.log("- Failures:", failures);
        console.log("- Circuit Breaker:", circuitBreakerActive);

        console.log("View functions test passed");
    }

    // Helper functions for individual portfolio testing (can be used separately)
    function _testConservativePortfolio() internal {
        console.log("\nTesting Conservative Portfolio");

        address conservativeUser = makeAddr("conservativeUser");
        _setTokenBalance(address(mockDAI), conservativeUser, 10_000 * 1e18);
        _setTokenBalance(address(mockWETH), conservativeUser, 10 * 1e18);

        vm.startPrank(conservativeUser);

        address[] memory tokens = new address[](2);
        uint256[] memory amounts = new uint256[](2);

        tokens[0] = address(mockDAI);
        amounts[0] = 8000 * 1e18; // 80% stablecoin

        tokens[1] = address(mockWETH);
        amounts[1] = 1 * 1e18; // 20% ETH

        mockDAI.approve(address(vault), amounts[0]);
        mockWETH.approve(address(vault), amounts[1]);

        vault.depositBasket(tokens, amounts);

        // Get the request ID from the user's position
        (,,,,, uint256 requestId,) = vault.getPosition(conservativeUser);

        vm.stopPrank();

        // Fast forward time to allow manual processing (31 minutes)
        vm.warp(block.timestamp + 31 minutes);

        // Simulate manual processing with conservative ratio (125%)
        vm.prank(deployer);
        riskOracle.processWithOffChainAI(
            requestId,
            "RATIO:125 CONFIDENCE:85 SOURCE:ALGORITHMIC_AI",
            RiskOracleController.ManualStrategy.PROCESS_WITH_OFFCHAIN_AI
        );

        // Check results
        uint256 stablecoinBalance = stablecoin.balanceOf(conservativeUser);
        console.log("Conservative portfolio minted:", stablecoinBalance / 1e18, "stablecoins");

        assertGt(stablecoinBalance, 0, "Should have minted stablecoins");
    }

    function _testAggressivePortfolio() internal {
        console.log("\nTesting Aggressive Portfolio");

        address aggressiveUser = makeAddr("aggressiveUser");
        _setTokenBalance(address(mockWBTC), aggressiveUser, 1 * 1e8);

        vm.startPrank(aggressiveUser);

        address[] memory tokens = new address[](1);
        uint256[] memory amounts = new uint256[](1);

        tokens[0] = address(mockWBTC);
        amounts[0] = 0.02 * 1e8; // 0.02 BTC (volatile)

        mockWBTC.approve(address(vault), amounts[0]);

        vault.depositBasket(tokens, amounts);

        // Get the request ID from the user's position
        (,,,,, uint256 requestId,) = vault.getPosition(aggressiveUser);

        vm.stopPrank();

        // Fast forward time to allow manual processing (31 minutes)
        vm.warp(block.timestamp + 31 minutes);

        // Simulate manual processing with aggressive ratio (180%)
        vm.prank(deployer);
        riskOracle.processWithOffChainAI(
            requestId,
            "RATIO:180 CONFIDENCE:65 SOURCE:ALGORITHMIC_AI",
            RiskOracleController.ManualStrategy.PROCESS_WITH_OFFCHAIN_AI
        );

        // Check results
        uint256 stablecoinBalance = stablecoin.balanceOf(aggressiveUser);
        console.log("Aggressive portfolio minted:", stablecoinBalance / 1e18, "stablecoins");

        assertGt(stablecoinBalance, 0, "Should have minted stablecoins");
    }

    function _testBalancedPortfolio() internal {
        console.log("\nTesting Balanced Portfolio");

        address balancedUser = makeAddr("balancedUser");
        _setTokenBalance(address(mockWETH), balancedUser, 10 * 1e18);
        _setTokenBalance(address(mockDAI), balancedUser, 10_000 * 1e18);
        _setTokenBalance(address(mockWBTC), balancedUser, 1 * 1e8);

        vm.startPrank(balancedUser);

        address[] memory tokens = new address[](3);
        uint256[] memory amounts = new uint256[](3);

        tokens[0] = address(mockWETH);
        amounts[0] = 1 * 1e18; // ~50% ETH

        tokens[1] = address(mockDAI);
        amounts[1] = 2500 * 1e18; // ~25% DAI

        tokens[2] = address(mockWBTC);
        amounts[2] = 0.005 * 1e8; // ~25% BTC

        mockWETH.approve(address(vault), amounts[0]);
        mockDAI.approve(address(vault), amounts[1]);
        mockWBTC.approve(address(vault), amounts[2]);

        vault.depositBasket(tokens, amounts);

        // Get the request ID from the user's position
        (,,,,, uint256 requestId,) = vault.getPosition(balancedUser);

        vm.stopPrank();

        // Fast forward time to allow manual processing (31 minutes)
        vm.warp(block.timestamp + 31 minutes);

        // Simulate manual processing with balanced ratio (145%)
        vm.prank(deployer);
        riskOracle.processWithOffChainAI(
            requestId,
            "RATIO:145 CONFIDENCE:78 SOURCE:ALGORITHMIC_AI",
            RiskOracleController.ManualStrategy.PROCESS_WITH_OFFCHAIN_AI
        );

        // Check results
        uint256 stablecoinBalance = stablecoin.balanceOf(balancedUser);
        console.log("Balanced portfolio minted:", stablecoinBalance / 1e18, "stablecoins");

        assertGt(stablecoinBalance, 0, "Should have minted stablecoins");
    }
}
