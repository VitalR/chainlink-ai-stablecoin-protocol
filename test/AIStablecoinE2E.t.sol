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
        aiusd = new AIStablecoin();

        controller = new AIControllerCallback(
            address(mockOracle), // oracle
            11, // model ID
            500_000, // gas limit
            0.01 ether // oracle fee
        );

        vault = new AICollateralVaultCallback(address(aiusd), address(controller));

        // Setup permissions
        aiusd.addVault(address(vault));
        controller.setAuthorizedCaller(address(vault), true);

        // Setup token prices (mock oracle prices)
        vault.addSupportedToken(address(weth), 2000 * 1e18, 18, "WETH"); // $2000 per ETH
        vault.addSupportedToken(address(wbtc), 50_000 * 1e18, 8, "WBTC"); // $50000 per BTC
        vault.addSupportedToken(address(usdc), 1 * 1e18, 6, "USDC"); // $1 per USDC

        // Mint tokens to users
        weth.mint(user1, INITIAL_BALANCE);
        wbtc.mint(user1, INITIAL_BALANCE);
        usdc.mint(user1, INITIAL_BALANCE);

        weth.mint(user2, INITIAL_BALANCE);
        wbtc.mint(user2, INITIAL_BALANCE);
        usdc.mint(user2, INITIAL_BALANCE);

        vm.stopPrank();

        // Fund users with ETH for transaction fees
        vm.deal(user1, 10 ether);
        vm.deal(user2, 10 ether);

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
        vault.depositBasket{ value: aiFee }(tokens, amounts);

        // Get request ID from position
        (,,,,, uint256 requestId, bool hasPendingRequest) = vault.getPosition(user1);

        console.log("Request ID:", requestId);
        assertGt(requestId, 0, "Request ID should be greater than 0");

        // 4. Verify deposit was recorded
        (
            address[] memory depositedTokens,
            uint256[] memory depositedAmounts,
            uint256 totalValue,
            uint256 aiusdMinted,
            uint256 collateralRatio,
            uint256 requestIdCheck,
            bool hasPendingRequestCheck
        ) = vault.getPosition(user1);

        assertEq(depositedTokens.length, 1, "Should have 1 token");
        assertEq(depositedTokens[0], address(weth), "Should be WETH");
        assertEq(depositedAmounts[0], DEPOSIT_AMOUNT, "Should match deposit amount");
        assertEq(totalValue, expectedValue, "Should match expected value");
        assertEq(aiusdMinted, 0, "No AIUSD minted yet");
        assertTrue(hasPendingRequestCheck, "Should have pending AI request");

        // 5. Verify AI request was submitted
        assertTrue(controller.isRequestProcessed(requestId) == false, "Request should not be processed yet");

        vm.stopPrank();

        // 6. Simulate AI processing (as oracle)
        mockOracle.processRequest(1); // First request ID from mock oracle

        // 7. Verify AI callback was processed
        vm.startPrank(user1);

        (,,, uint256 finalAiusdMinted, uint256 finalCollateralRatio,, bool finalHasPendingRequest) =
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
        amounts[1] = 0.1 * 1e8; // 0.1 BTC with 8 decimals

        tokens[2] = address(usdc);
        amounts[2] = 5000 * 1e6; // 5,000 USDC = $5,000

        uint256 expectedValue = (5 * 2000 * 1e18) + (0.1 * 1e8 * 50_000 * 1e18 / 1e8) + (5000 * 1e6 * 1 * 1e18 / 1e6); // $20,000
            // total

        // 2. Get fee estimate
        uint256 aiFee = controller.estimateTotalFee();

        // 3. Deposit diversified basket
        vault.depositBasket{ value: aiFee }(tokens, amounts);

        // Get request ID from position
        (,,,,, uint256 requestId,) = vault.getPosition(user2);

        console.log("Diversified basket request ID:", requestId);

        // 4. Verify initial state
        (
            address[] memory depositedTokens,
            uint256[] memory depositedAmounts,
            uint256 totalValue,
            uint256 aiusdMinted,
            ,
            ,
            bool hasPendingRequest
        ) = vault.getPosition(user2);

        assertEq(depositedTokens.length, 3, "Should have 3 tokens");
        assertEq(totalValue, expectedValue, "Should match expected total value");
        assertEq(aiusdMinted, 0, "No AIUSD minted yet");
        assertTrue(hasPendingRequest, "Should have pending AI request");

        vm.stopPrank();

        // 5. Process AI request
        mockOracle.processRequest(requestId); // Use actual request ID, not hardcoded 2

        // 6. Verify final state
        vm.startPrank(user2);

        (,,, uint256 finalAiusdMinted, uint256 finalCollateralRatio,, bool finalHasPendingRequest) =
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
        vault.depositBasket{ value: excessFee }(tokens, amounts);

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
        vault.depositBasket{ value: aiFee - 1 }(tokens, amounts);

        // Test empty deposit
        address[] memory emptyTokens = new address[](0);
        uint256[] memory emptyAmounts = new uint256[](0);
        vm.expectRevert();
        vault.depositBasket{ value: aiFee }(emptyTokens, emptyAmounts);

        vm.stopPrank();
    }

    /// @notice Test position queries and state management
    function test_deposit_position_management() public {
        vm.startPrank(user1);

        // Initial position should be empty - check key fields only
        (,, uint256 totalValue, uint256 aiusdMinted,,, bool hasPendingRequest) = vault.getPosition(user1);

        assertEq(totalValue, 0, "Should have no value initially");
        assertEq(aiusdMinted, 0, "Should have no AIUSD initially");
        assertFalse(hasPendingRequest, "Should not have pending request initially");

        // Make deposit
        address[] memory depositTokens = new address[](1);
        uint256[] memory depositAmounts = new uint256[](1);
        depositTokens[0] = address(weth);
        depositAmounts[0] = 5 ether;

        uint256 aiFee = controller.estimateTotalFee();
        vault.depositBasket{ value: aiFee }(depositTokens, depositAmounts);

        // Position should be updated - check in separate calls to avoid stack too deep
        (address[] memory tokens, uint256[] memory amounts,,,,,) = vault.getPosition(user1);
        (,, uint256 newTotalValue,,,, bool newHasPendingRequest) = vault.getPosition(user1);

        assertEq(tokens.length, 1, "Should have 1 token");
        assertEq(tokens[0], address(weth), "Should be WETH");
        assertEq(amounts[0], 5 ether, "Should match deposit");
        assertEq(newTotalValue, 5 ether * 2000, "Should match expected value");
        assertTrue(newHasPendingRequest, "Should have pending request");

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

        vault.depositBasket{ value: aiFee }(tokens1, amounts1);

        // Get request IDs from positions
        (,,,,, uint256 requestId1,) = vault.getPosition(user1);

        vm.stopPrank();

        // User 2 deposits
        vm.startPrank(user2);
        address[] memory tokens2 = new address[](1);
        uint256[] memory amounts2 = new uint256[](1);
        tokens2[0] = address(wbtc);
        amounts2[0] = 0.05 ether; // 0.05 BTC

        vault.depositBasket{ value: aiFee }(tokens2, amounts2);

        // Get request ID from position
        (,,,,, uint256 requestId2,) = vault.getPosition(user2);

        vm.stopPrank();

        // Both should have different request IDs
        assertNotEq(requestId1, requestId2, "Request IDs should be different");

        // Process both AI requests using actual request IDs
        mockOracle.processRequest(requestId1);
        mockOracle.processRequest(requestId2);

        // Both users should have AIUSD
        assertGt(aiusd.balanceOf(user1), 0, "User1 should have AIUSD");
        assertGt(aiusd.balanceOf(user2), 0, "User2 should have AIUSD");

        console.log("User1 AIUSD balance:", aiusd.balanceOf(user1));
        console.log("User2 AIUSD balance:", aiusd.balanceOf(user2));
    }

    // ========================================
    // WITHDRAW FLOW TESTS
    // ========================================

    /// @notice Test basic withdraw flow: deposit → mint → withdraw
    function test_withdraw_basic_flow() public {
        vm.startPrank(user1);

        // 1. Setup: Deposit and mint AIUSD first
        address[] memory tokens = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        tokens[0] = address(weth);
        amounts[0] = 10 ether; // 10 ETH = $20,000

        uint256 aiFee = controller.estimateTotalFee();
        vault.depositBasket{ value: aiFee }(tokens, amounts);

        (,,,,, uint256 requestId,) = vault.getPosition(user1);
        vm.stopPrank();

        // Process AI request
        mockOracle.processRequest(requestId);

        vm.startPrank(user1);

        // Get initial state after minting
        uint256 initialAiusdBalance = aiusd.balanceOf(user1);
        uint256 initialWethBalance = weth.balanceOf(user1);
        (,, uint256 initialTotalValue, uint256 initialAiusdMinted,,, bool initialHasPending) = vault.getPosition(user1);

        assertGt(initialAiusdBalance, 0, "Should have AIUSD minted");
        assertEq(initialAiusdBalance, initialAiusdMinted, "AIUSD balance should match minted amount");
        assertFalse(initialHasPending, "Should not have pending request");

        console.log("Initial AIUSD balance:", initialAiusdBalance);
        console.log("Initial total value:", initialTotalValue);

        // 2. Withdraw half of the position
        uint256 withdrawAmount = initialAiusdBalance / 2;

        // Approve vault to burn AIUSD
        aiusd.approve(address(vault), withdrawAmount);

        vault.withdrawCollateral(withdrawAmount);

        // 3. Verify withdraw results
        uint256 finalAiusdBalance = aiusd.balanceOf(user1);
        uint256 finalWethBalance = weth.balanceOf(user1);
        (,, uint256 finalTotalValue, uint256 finalAiusdMinted,,,) = vault.getPosition(user1);

        // AIUSD should be burned
        assertEq(finalAiusdBalance, initialAiusdBalance - withdrawAmount, "AIUSD should be burned");

        // Should receive proportional collateral back
        assertGt(finalWethBalance, initialWethBalance, "Should receive WETH back");

        // Position should be updated proportionally
        assertLt(finalTotalValue, initialTotalValue, "Total value should decrease");
        assertEq(finalAiusdMinted, initialAiusdMinted - withdrawAmount, "Minted amount should decrease");

        console.log("Final AIUSD balance:", finalAiusdBalance);
        console.log("Final WETH balance:", finalWethBalance);
        console.log("WETH received:", finalWethBalance - initialWethBalance);

        vm.stopPrank();
    }

    /// @notice Test full withdrawal - user withdraws entire position
    function test_withdraw_full_position() public {
        vm.startPrank(user1);

        // 1. Setup: Deposit and mint AIUSD
        address[] memory tokens = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        tokens[0] = address(weth);
        amounts[0] = 5 ether;

        uint256 aiFee = controller.estimateTotalFee();
        vault.depositBasket{ value: aiFee }(tokens, amounts);

        (,,,,, uint256 requestId,) = vault.getPosition(user1);
        vm.stopPrank();

        mockOracle.processRequest(requestId);

        vm.startPrank(user1);

        uint256 initialAiusdBalance = aiusd.balanceOf(user1);
        uint256 initialWethBalance = weth.balanceOf(user1);

        // 2. Withdraw entire position
        aiusd.approve(address(vault), initialAiusdBalance);
        vault.withdrawCollateral(initialAiusdBalance);

        // 3. Verify complete withdrawal
        uint256 finalAiusdBalance = aiusd.balanceOf(user1);
        uint256 finalWethBalance = weth.balanceOf(user1);
        (,, uint256 finalTotalValue, uint256 finalAiusdMinted,,,) = vault.getPosition(user1);

        assertEq(finalAiusdBalance, 0, "All AIUSD should be burned");
        assertEq(finalTotalValue, 0, "Position should be empty");
        assertEq(finalAiusdMinted, 0, "No AIUSD should remain minted");

        // Should receive all collateral back (minus any fees/rounding)
        assertGt(finalWethBalance, initialWethBalance, "Should receive WETH back");

        console.log("Full withdrawal - WETH received:", finalWethBalance - initialWethBalance);

        vm.stopPrank();
    }

    /// @notice Test withdrawal from diversified basket
    function test_withdraw_diversified_basket() public {
        vm.startPrank(user2);

        // 1. Setup: Deposit diversified basket
        address[] memory tokens = new address[](3);
        uint256[] memory amounts = new uint256[](3);
        tokens[0] = address(weth);
        amounts[0] = 2 ether; // $4,000
        tokens[1] = address(wbtc);
        amounts[1] = 0.04 * 1e8; // 0.04 BTC = $2,000
        tokens[2] = address(usdc);
        amounts[2] = 4000 * 1e6; // $4,000

        uint256 aiFee = controller.estimateTotalFee();
        vault.depositBasket{ value: aiFee }(tokens, amounts);

        (,,,,, uint256 requestId,) = vault.getPosition(user2);
        vm.stopPrank();

        mockOracle.processRequest(requestId);

        vm.startPrank(user2);

        // Get initial balances
        uint256 initialAiusdBalance = aiusd.balanceOf(user2);
        uint256 initialWethBalance = weth.balanceOf(user2);
        uint256 initialWbtcBalance = wbtc.balanceOf(user2);
        uint256 initialUsdcBalance = usdc.balanceOf(user2);

        // 2. Withdraw 25% of position
        uint256 withdrawAmount = initialAiusdBalance / 4;
        aiusd.approve(address(vault), withdrawAmount);
        vault.withdrawCollateral(withdrawAmount);

        // 3. Verify proportional withdrawal from all tokens
        uint256 finalWethBalance = weth.balanceOf(user2);
        uint256 finalWbtcBalance = wbtc.balanceOf(user2);
        uint256 finalUsdcBalance = usdc.balanceOf(user2);

        assertGt(finalWethBalance, initialWethBalance, "Should receive WETH back");
        assertGt(finalWbtcBalance, initialWbtcBalance, "Should receive WBTC back");
        assertGt(finalUsdcBalance, initialUsdcBalance, "Should receive USDC back");

        console.log("Diversified withdrawal:");
        console.log("WETH received:", finalWethBalance - initialWethBalance);
        console.log("WBTC received:", finalWbtcBalance - initialWbtcBalance);
        console.log("USDC received:", finalUsdcBalance - initialUsdcBalance);

        vm.stopPrank();
    }

    /// @notice Test partial withdrawal maintains correct ratios
    function test_withdraw_maintains_ratios() public {
        vm.startPrank(user1);

        // 1. Setup position
        address[] memory tokens = new address[](2);
        uint256[] memory amounts = new uint256[](2);
        tokens[0] = address(weth);
        amounts[0] = 4 ether; // $8,000
        tokens[1] = address(usdc);
        amounts[1] = 2000 * 1e6; // $2,000

        uint256 aiFee = controller.estimateTotalFee();
        vault.depositBasket{ value: aiFee }(tokens, amounts);

        (,,,,, uint256 requestId,) = vault.getPosition(user1);
        vm.stopPrank();

        mockOracle.processRequest(requestId);

        vm.startPrank(user1);

        // Get initial position ratios
        (address[] memory initialTokens, uint256[] memory initialAmounts,,,,,) = vault.getPosition(user1);
        uint256 initialWethAmount = initialAmounts[0];
        uint256 initialUsdcAmount = initialAmounts[1];
        uint256 initialWethRatio = (initialWethAmount * 1e18) / (initialWethAmount + (initialUsdcAmount * 1e12)); // Normalize
            // USDC to 18 decimals

        uint256 initialAiusdBalance = aiusd.balanceOf(user1);

        // 2. Withdraw 30% of position
        uint256 withdrawAmount = (initialAiusdBalance * 30) / 100;
        aiusd.approve(address(vault), withdrawAmount);
        vault.withdrawCollateral(withdrawAmount);

        // 3. Verify ratios are maintained
        (address[] memory finalTokens, uint256[] memory finalAmounts,,,,,) = vault.getPosition(user1);
        uint256 finalWethAmount = finalAmounts[0];
        uint256 finalUsdcAmount = finalAmounts[1];
        uint256 finalWethRatio = (finalWethAmount * 1e18) / (finalWethAmount + (finalUsdcAmount * 1e12));

        // Ratios should be approximately the same (allowing for small rounding differences)
        assertApproxEqRel(finalWethRatio, initialWethRatio, 0.01e18, "WETH ratio should be maintained");

        console.log("Initial WETH ratio:", initialWethRatio);
        console.log("Final WETH ratio:", finalWethRatio);

        vm.stopPrank();
    }

    /// @notice Test withdraw error cases
    function test_withdraw_error_cases() public {
        vm.startPrank(user1);

        // 1. Setup position first
        address[] memory tokens = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        tokens[0] = address(weth);
        amounts[0] = 1 ether;

        uint256 aiFee = controller.estimateTotalFee();
        vault.depositBasket{ value: aiFee }(tokens, amounts);

        (,,,,, uint256 requestId,) = vault.getPosition(user1);
        vm.stopPrank();

        mockOracle.processRequest(requestId);

        vm.startPrank(user1);

        uint256 aiusdBalance = aiusd.balanceOf(user1);

        // Test: Withdraw more than balance
        aiusd.approve(address(vault), type(uint256).max);
        vm.expectRevert();
        vault.withdrawCollateral(aiusdBalance + 1);

        // Test: Withdraw zero amount
        vm.expectRevert();
        vault.withdrawCollateral(0);

        // Test: Withdraw without approval (proper DeFi flow)
        aiusd.approve(address(vault), 0);
        vm.expectRevert();
        vault.withdrawCollateral(aiusdBalance / 2);

        vm.stopPrank();

        // Test: Withdraw from empty position (different user)
        vm.startPrank(user2);
        vm.expectRevert();
        vault.withdrawCollateral(1);
        vm.stopPrank();
    }

    /// @notice Test withdraw with pending AI request should fail
    function test_withdraw_with_pending_request_fails() public {
        vm.startPrank(user1);

        // 1. Deposit but don't process AI request yet
        address[] memory tokens = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        tokens[0] = address(weth);
        amounts[0] = 1 ether;

        uint256 aiFee = controller.estimateTotalFee();
        vault.depositBasket{ value: aiFee }(tokens, amounts);

        // Position should have pending request
        (,,,,, uint256 requestId, bool hasPendingRequest) = vault.getPosition(user1);
        assertTrue(hasPendingRequest, "Should have pending request");

        // 2. Try to withdraw while request is pending - should fail
        vm.expectRevert();
        vault.withdrawCollateral(1);

        vm.stopPrank();

        // 3. Process request, then withdraw should work
        mockOracle.processRequest(requestId);

        vm.startPrank(user1);
        uint256 aiusdBalance = aiusd.balanceOf(user1);
        aiusd.approve(address(vault), aiusdBalance);
        vault.withdrawCollateral(aiusdBalance); // Should not revert

        vm.stopPrank();
    }

    /// @notice Test multiple partial withdrawals
    function test_withdraw_multiple_partial() public {
        vm.startPrank(user1);

        // 1. Setup large position
        address[] memory tokens = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        tokens[0] = address(weth);
        amounts[0] = 20 ether; // $40,000

        uint256 aiFee = controller.estimateTotalFee();
        vault.depositBasket{ value: aiFee }(tokens, amounts);

        (,,,,, uint256 requestId,) = vault.getPosition(user1);
        vm.stopPrank();

        mockOracle.processRequest(requestId);

        vm.startPrank(user1);

        uint256 initialAiusdBalance = aiusd.balanceOf(user1);
        uint256 initialWethBalance = weth.balanceOf(user1);

        // 2. Make multiple partial withdrawals
        uint256 withdrawAmount1 = initialAiusdBalance / 5; // 20%
        uint256 withdrawAmount2 = initialAiusdBalance / 4; // 25% of original
        uint256 withdrawAmount3 = initialAiusdBalance / 10; // 10%

        // First withdrawal
        aiusd.approve(address(vault), withdrawAmount1);
        vault.withdrawCollateral(withdrawAmount1);

        uint256 balanceAfter1 = aiusd.balanceOf(user1);
        assertEq(balanceAfter1, initialAiusdBalance - withdrawAmount1, "First withdrawal should burn correct amount");

        // Second withdrawal
        aiusd.approve(address(vault), withdrawAmount2);
        vault.withdrawCollateral(withdrawAmount2);

        uint256 balanceAfter2 = aiusd.balanceOf(user1);
        assertEq(
            balanceAfter2,
            initialAiusdBalance - withdrawAmount1 - withdrawAmount2,
            "Second withdrawal should burn correct amount"
        );

        // Third withdrawal
        aiusd.approve(address(vault), withdrawAmount3);
        vault.withdrawCollateral(withdrawAmount3);

        uint256 finalAiusdBalance = aiusd.balanceOf(user1);
        uint256 finalWethBalance = weth.balanceOf(user1);

        // Verify total withdrawals
        uint256 totalWithdrawn = withdrawAmount1 + withdrawAmount2 + withdrawAmount3;
        assertEq(finalAiusdBalance, initialAiusdBalance - totalWithdrawn, "Total AIUSD burned should match");
        assertGt(finalWethBalance, initialWethBalance, "Should have received WETH back");

        console.log("Multiple withdrawals completed:");
        console.log("Total AIUSD burned:", totalWithdrawn);
        console.log("Total WETH received:", finalWethBalance - initialWethBalance);

        vm.stopPrank();
    }

    /// @notice Test withdraw events are emitted correctly
    function test_withdraw_events() public {
        vm.startPrank(user1);

        // Setup position
        address[] memory tokens = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        tokens[0] = address(weth);
        amounts[0] = 2 ether;

        uint256 aiFee = controller.estimateTotalFee();
        vault.depositBasket{ value: aiFee }(tokens, amounts);

        (,,,,, uint256 requestId,) = vault.getPosition(user1);
        vm.stopPrank();

        mockOracle.processRequest(requestId);

        vm.startPrank(user1);

        uint256 aiusdBalance = aiusd.balanceOf(user1);
        uint256 withdrawAmount = aiusdBalance / 2;

        aiusd.approve(address(vault), withdrawAmount);

        // Expect CollateralWithdrawn event
        vm.expectEmit(true, false, false, true);
        emit CollateralWithdrawn(user1, withdrawAmount);

        vault.withdrawCollateral(withdrawAmount);

        vm.stopPrank();
    }

    // Event declaration for testing
    event CollateralWithdrawn(address indexed user, uint256 amount);
}
