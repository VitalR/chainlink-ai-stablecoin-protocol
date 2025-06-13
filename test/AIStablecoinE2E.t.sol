// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import "../src/AIStablecoin.sol";
import "../src/AICollateralVaultCallback.sol";
import "../src/AIControllerCallback.sol";
import "./mocks/MockAIOracle.sol";
import "./mocks/MockERC20.sol";

/// @title AIStablecoinE2E - End-to-End Integration Tests
/// @notice Tests the complete flow: Deposit → AI Assessment → Minting
contract AIStablecoinE2E is Test {
    // Core contracts
    AIStablecoin public aiusd;
    AICollateralVaultCallback public vault;
    AIControllerCallback public controller;
    MockAIOracle public mockOracle;

    // Mock tokens
    MockERC20 public weth;
    MockERC20 public wbtc;
    MockERC20 public usdc;

    // Test accounts
    address public owner = makeAddr("owner");
    address public user1 = makeAddr("user1");
    address public user2 = makeAddr("user2");

    // Test constants
    uint256 public constant INITIAL_BALANCE = 1000 ether;
    uint256 public constant DEPOSIT_AMOUNT = 10 ether;

    function setUp() public {
        vm.startPrank(owner);

        // Deploy mock tokens
        weth = new MockERC20("Wrapped Ether", "WETH", 18);
        wbtc = new MockERC20("Wrapped Bitcoin", "WBTC", 8);
        usdc = new MockERC20("USD Coin", "USDC", 6);

        // Deploy mock oracle
        mockOracle = new MockAIOracle();

        // Deploy core contracts
        aiusd = new AIStablecoin("AI Stablecoin", "AIUSD");

        controller = new AIControllerCallback(
            address(mockOracle), // oracle
            11, // model ID
            500_000 // gas limit
        );

        vault = new AICollateralVaultCallback(address(aiusd), address(controller));

        // Setup permissions
        aiusd.setMinter(address(vault), true);
        controller.setAuthorizedCaller(address(vault), true);

        // Setup token prices (mock oracle prices)
        vault.updateTokenPrice(address(weth), 2000 * 1e18); // $2000 per ETH
        vault.updateTokenPrice(address(wbtc), 50_000 * 1e18); // $50000 per BTC
        vault.updateTokenPrice(address(usdc), 1 * 1e18); // $1 per USDC

        // Mint tokens to users
        weth.mint(user1, INITIAL_BALANCE);
        wbtc.mint(user1, INITIAL_BALANCE);
        usdc.mint(user1, INITIAL_BALANCE);

        weth.mint(user2, INITIAL_BALANCE);
        wbtc.mint(user2, INITIAL_BALANCE);
        usdc.mint(user2, INITIAL_BALANCE);

        vm.stopPrank();

        // Users approve vault
        vm.startPrank(user1);
        weth.approve(address(vault), type(uint256).max);
        wbtc.approve(address(vault), type(uint256).max);
        usdc.approve(address(vault), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(user2);
        weth.approve(address(vault), type(uint256).max);
        wbtc.approve(address(vault), type(uint256).max);
        usdc.approve(address(vault), type(uint256).max);
        vm.stopPrank();
    }

    /// @notice Test complete flow: single token deposit → AI assessment → minting
    function test_deposit_e2e_single_token_flow() public {
        vm.startPrank(user1);

        // 1. Prepare deposit
        address[] memory tokens = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        tokens[0] = address(weth);
        amounts[0] = DEPOSIT_AMOUNT; // 10 ETH

        uint256 expectedValue = DEPOSIT_AMOUNT * 2000; // 10 ETH * $2000 = $20,000

        // 2. Get fee estimate
        uint256 aiFee = controller.estimateTotalFee();
        console.log("AI fee required:", aiFee);

        // 3. Deposit collateral and request AI assessment
        uint256 requestId = vault.depositAndRequestAI{ value: aiFee }(tokens, amounts);

        console.log("Request ID:", requestId);
        assertGt(requestId, 0, "Request ID should be greater than 0");

        // 4. Verify deposit was recorded
        (
            address[] memory depositedTokens,
            uint256[] memory depositedAmounts,
            uint256 totalValue,
            uint256 aiusdMinted,
            uint256 collateralRatio,
            bool hasPendingRequest
        ) = vault.getPosition(user1);

        assertEq(depositedTokens.length, 1, "Should have 1 token");
        assertEq(depositedTokens[0], address(weth), "Should be WETH");
        assertEq(depositedAmounts[0], DEPOSIT_AMOUNT, "Should match deposit amount");
        assertEq(totalValue, expectedValue, "Should match expected value");
        assertEq(aiusdMinted, 0, "No AIUSD minted yet");
        assertTrue(hasPendingRequest, "Should have pending AI request");

        // 5. Verify AI request was submitted
        assertTrue(controller.isRequestFinalized(requestId) == false, "Request should not be finalized yet");

        vm.stopPrank();

        // 6. Simulate AI processing (as oracle)
        mockOracle.processRequest(1); // First request ID from mock oracle

        // 7. Verify AI callback was processed
        vm.startPrank(user1);

        (,,, uint256 finalAiusdMinted, uint256 finalCollateralRatio, bool finalHasPendingRequest) =
            vault.getPosition(user1);

        assertGt(finalAiusdMinted, 0, "AIUSD should be minted");
        assertGt(finalCollateralRatio, 0, "Collateral ratio should be set");
        assertFalse(finalHasPendingRequest, "Should not have pending request");

        // 8. Verify AIUSD balance
        uint256 aiusdBalance = aiusd.balanceOf(user1);
        assertEq(aiusdBalance, finalAiusdMinted, "AIUSD balance should match minted amount");

        console.log("Final AIUSD minted:", finalAiusdMinted);
        console.log("Final collateral ratio:", finalCollateralRatio);
        console.log("AIUSD balance:", aiusdBalance);

        vm.stopPrank();
    }

    /// @notice Test complete flow: diversified basket → AI assessment → minting
    function test_deposit_e2e_diversified_basket_flow() public {
        vm.startPrank(user2);

        // 1. Prepare diversified basket
        address[] memory tokens = new address[](3);
        uint256[] memory amounts = new uint256[](3);

        tokens[0] = address(weth);
        amounts[0] = 5 ether; // 5 ETH = $10,000

        tokens[1] = address(wbtc);
        amounts[1] = 0.1 ether; // 0.1 BTC = $5,000

        tokens[2] = address(usdc);
        amounts[2] = 5000 * 1e6; // 5,000 USDC = $5,000

        uint256 expectedValue = (5 * 2000) + (0.1 ether * 50_000 / 1e18) + 5000; // $20,000 total

        // 2. Get fee estimate
        uint256 aiFee = controller.estimateTotalFee();

        // 3. Deposit diversified basket
        uint256 requestId = vault.depositAndRequestAI{ value: aiFee }(tokens, amounts);

        console.log("Diversified basket request ID:", requestId);

        // 4. Verify initial state
        (
            address[] memory depositedTokens,
            uint256[] memory depositedAmounts,
            uint256 totalValue,
            uint256 aiusdMinted,
            ,
            bool hasPendingRequest
        ) = vault.getPosition(user2);

        assertEq(depositedTokens.length, 3, "Should have 3 tokens");
        assertEq(totalValue, expectedValue, "Should match expected total value");
        assertEq(aiusdMinted, 0, "No AIUSD minted yet");
        assertTrue(hasPendingRequest, "Should have pending AI request");

        vm.stopPrank();

        // 5. Process AI request
        mockOracle.processRequest(2); // Second request

        // 6. Verify final state
        vm.startPrank(user2);

        (,,, uint256 finalAiusdMinted, uint256 finalCollateralRatio, bool finalHasPendingRequest) =
            vault.getPosition(user2);

        assertGt(finalAiusdMinted, 0, "AIUSD should be minted");
        assertFalse(finalHasPendingRequest, "Should not have pending request");

        // Diversified basket should get better ratio (more AIUSD minted)
        uint256 aiusdBalance = aiusd.balanceOf(user2);
        assertEq(aiusdBalance, finalAiusdMinted, "AIUSD balance should match");

        console.log("Diversified basket AIUSD minted:", finalAiusdMinted);
        console.log("Diversified basket collateral ratio:", finalCollateralRatio);

        vm.stopPrank();
    }

    /// @notice Test AI controller fee estimation and payment
    function test_deposit_ai_fee_handling() public {
        vm.startPrank(user1);

        address[] memory tokens = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        tokens[0] = address(weth);
        amounts[0] = 1 ether;

        uint256 aiFee = controller.estimateTotalFee();
        uint256 excessFee = aiFee + 0.01 ether;

        uint256 balanceBefore = user1.balance;

        // Send excess fee - should get refund
        vault.depositAndRequestAI{ value: excessFee }(tokens, amounts);

        uint256 balanceAfter = user1.balance;
        uint256 actualFeeUsed = balanceBefore - balanceAfter;

        // Should only use the required fee, not the excess
        assertEq(actualFeeUsed, aiFee, "Should only use required fee");

        vm.stopPrank();
    }

    /// @notice Test error cases
    function test_deposit_error_cases() public {
        vm.startPrank(user1);

        address[] memory tokens = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        tokens[0] = address(weth);
        amounts[0] = 1 ether;

        // Test insufficient fee
        uint256 aiFee = controller.estimateTotalFee();
        vm.expectRevert();
        vault.depositAndRequestAI{ value: aiFee - 1 }(tokens, amounts);

        // Test empty deposit
        address[] memory emptyTokens = new address[](0);
        uint256[] memory emptyAmounts = new uint256[](0);
        vm.expectRevert();
        vault.depositAndRequestAI{ value: aiFee }(emptyTokens, emptyAmounts);

        vm.stopPrank();
    }

    /// @notice Test position queries and state management
    function test_deposit_position_management() public {
        vm.startPrank(user1);

        // Initial position should be empty
        (
            address[] memory tokens,
            uint256[] memory amounts,
            uint256 totalValue,
            uint256 aiusdMinted,
            uint256 collateralRatio,
            bool hasPendingRequest
        ) = vault.getPosition(user1);

        assertEq(tokens.length, 0, "Should have no tokens initially");
        assertEq(totalValue, 0, "Should have no value initially");
        assertEq(aiusdMinted, 0, "Should have no AIUSD initially");
        assertFalse(hasPendingRequest, "Should not have pending request initially");

        // Make deposit
        address[] memory depositTokens = new address[](1);
        uint256[] memory depositAmounts = new uint256[](1);
        depositTokens[0] = address(weth);
        depositAmounts[0] = 5 ether;

        uint256 aiFee = controller.estimateTotalFee();
        vault.depositAndRequestAI{ value: aiFee }(depositTokens, depositAmounts);

        // Position should be updated
        (tokens, amounts, totalValue, aiusdMinted, collateralRatio, hasPendingRequest) = vault.getPosition(user1);

        assertEq(tokens.length, 1, "Should have 1 token");
        assertEq(tokens[0], address(weth), "Should be WETH");
        assertEq(amounts[0], 5 ether, "Should match deposit");
        assertEq(totalValue, 5 ether * 2000, "Should match expected value");
        assertTrue(hasPendingRequest, "Should have pending request");

        vm.stopPrank();
    }

    /// @notice Helper to fund accounts with ETH
    function _fundAccount(address account, uint256 amount) internal {
        vm.deal(account, amount);
    }

    /// @notice Test multiple users can deposit simultaneously
    function test_deposit_e2e_multiple_users() public {
        // Fund accounts with ETH for fees
        _fundAccount(user1, 1 ether);
        _fundAccount(user2, 1 ether);

        uint256 aiFee = controller.estimateTotalFee();

        // User 1 deposits
        vm.startPrank(user1);
        address[] memory tokens1 = new address[](1);
        uint256[] memory amounts1 = new uint256[](1);
        tokens1[0] = address(weth);
        amounts1[0] = 3 ether;

        uint256 requestId1 = vault.depositAndRequestAI{ value: aiFee }(tokens1, amounts1);
        vm.stopPrank();

        // User 2 deposits
        vm.startPrank(user2);
        address[] memory tokens2 = new address[](1);
        uint256[] memory amounts2 = new uint256[](1);
        tokens2[0] = address(wbtc);
        amounts2[0] = 0.05 ether; // 0.05 BTC

        uint256 requestId2 = vault.depositAndRequestAI{ value: aiFee }(tokens2, amounts2);
        vm.stopPrank();

        // Both should have different request IDs
        assertNotEq(requestId1, requestId2, "Request IDs should be different");

        // Process both AI requests
        mockOracle.processRequest(1);
        mockOracle.processRequest(2);

        // Both users should have AIUSD
        assertGt(aiusd.balanceOf(user1), 0, "User1 should have AIUSD");
        assertGt(aiusd.balanceOf(user2), 0, "User2 should have AIUSD");

        console.log("User1 AIUSD balance:", aiusd.balanceOf(user1));
        console.log("User2 AIUSD balance:", aiusd.balanceOf(user2));
    }
}
