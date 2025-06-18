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

/// @title CollateralVaultTest - Comprehensive unit tests for CollateralVault
/// @notice Tests vault-specific functionality: withdrawals, token management, emergency flows
contract CollateralVaultTest is Test {
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

    // Test constants
    uint256 public constant INITIAL_BALANCE = 1000 ether;
    uint256 public constant DEPOSIT_AMOUNT = 10 ether;

    // Events to test
    event CollateralDeposited(address indexed user, address[] tokens, uint256[] amounts, uint256 totalValue);
    event AIUSDMinted(address indexed user, uint256 amount, uint256 ratio, uint256 confidence);
    event CollateralWithdrawn(address indexed user, uint256 amount);
    event EmergencyWithdrawal(address indexed user, uint256 indexed requestId, uint256 timestamp);
    event TokenAdded(address indexed token, uint256 priceUSD, uint8 decimals);
    event TokenPriceUpdated(address indexed token, uint256 newPriceUSD);
    event ControllerUpdated(address indexed oldController, address indexed newController);

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
        controller = new RiskOracleController(
            address(mockRouter), 
            bytes32("fun_sepolia_1"), 
            123, 
            "return 'RATIO:150 CONFIDENCE:85';"
        );
        vault = new CollateralVault(address(aiusd), address(controller));

        // Setup permissions
        aiusd.addVault(address(vault));
        controller.setAuthorizedCaller(address(vault), true);

        // Setup tokens
        vault.addToken(address(weth), 2000 * 1e18, 18, "WETH");
        vault.addToken(address(usdc), 1 * 1e18, 6, "USDC");
        vault.addToken(address(dai), 1 * 1e18, 18, "DAI");

        // Mint tokens to users
        weth.mint(user1, INITIAL_BALANCE);
        usdc.mint(user1, INITIAL_BALANCE);
        dai.mint(user1, INITIAL_BALANCE);
        
        weth.mint(user2, INITIAL_BALANCE);
        usdc.mint(user2, INITIAL_BALANCE);
        dai.mint(user2, INITIAL_BALANCE);

        vm.stopPrank();

        // Fund users
        vm.deal(user1, 10 ether);
        vm.deal(user2, 10 ether);

        // Approve vault
        vm.startPrank(user1);
        weth.approve(address(vault), type(uint256).max);
        usdc.approve(address(vault), type(uint256).max);
        dai.approve(address(vault), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(user2);
        weth.approve(address(vault), type(uint256).max);
        usdc.approve(address(vault), type(uint256).max);
        dai.approve(address(vault), type(uint256).max);
        vm.stopPrank();
    }

    /// @notice Test basic collateral withdrawal functionality
    function test_collateralWithdrawal() public {
        // Setup a completed position
        uint256 requestId = _setupCompletedPosition(user1);
        
        vm.startPrank(user1);
        (,,, uint256 aiusdMinted,,,) = vault.getPosition(user1);
        uint256 initialAIUSDBalance = aiusd.balanceOf(user1);
        uint256 initialWETHBalance = weth.balanceOf(user1);
        
        // Approve vault to burn AIUSD
        aiusd.approve(address(vault), type(uint256).max);
        
        // Withdraw half the AIUSD
        uint256 withdrawAmount = aiusdMinted / 2;
        
        vm.expectEmit(true, false, false, true);
        emit CollateralWithdrawn(user1, withdrawAmount);
        
        vault.withdrawCollateral(withdrawAmount);
        
        // Check AIUSD was burned
        assertEq(aiusd.balanceOf(user1), initialAIUSDBalance - withdrawAmount, "AIUSD should be burned");
        
        // Check proportional collateral returned (allow for small rounding differences)
        uint256 finalWETHBalance = weth.balanceOf(user1);
        uint256 expectedWETHReturn = DEPOSIT_AMOUNT / 2; // 50% withdrawal
        uint256 actualWETHReturn = finalWETHBalance - initialWETHBalance;
        
        // Allow for rounding errors within 100 wei
        assertApproxEqAbs(actualWETHReturn, expectedWETHReturn, 100, "Should receive proportional WETH");
        
        // Check position updated
        (,,, uint256 remainingAIUSD,,,) = vault.getPosition(user1);
        assertEq(remainingAIUSD, aiusdMinted - withdrawAmount, "Position should be updated");
        
        vm.stopPrank();
    }

    /// @notice Test full collateral withdrawal clears position
    function test_fullCollateralWithdrawal() public {
        uint256 requestId = _setupCompletedPosition(user1);
        
        vm.startPrank(user1);
        (,,, uint256 aiusdMinted,,,) = vault.getPosition(user1);
        
        // Approve vault to burn AIUSD
        aiusd.approve(address(vault), type(uint256).max);
        
        vault.withdrawCollateral(aiusdMinted);
        
        // Check position is cleared
        (address[] memory tokens,,,,,, bool hasPending) = vault.getPosition(user1);
        assertEq(tokens.length, 0, "Position should be cleared");
        assertFalse(hasPending, "Should have no pending request");
        
        vm.stopPrank();
    }

    /// @notice Test user-initiated emergency withdrawal
    function test_userEmergencyWithdrawal() public {
        // Setup pending position
        vm.startPrank(user1);
        address[] memory tokens = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        tokens[0] = address(weth);
        amounts[0] = DEPOSIT_AMOUNT;
        
        vault.depositBasket(tokens, amounts);
        uint256 initialWETHBalance = weth.balanceOf(user1);
        vm.stopPrank();
        
        // Try emergency withdrawal before 4 hours - should fail
        vm.startPrank(user1);
        vm.expectRevert("Must wait 4 hours");
        vault.userEmergencyWithdraw();
        vm.stopPrank();
        
        // Fast forward 4 hours
        vm.warp(block.timestamp + 4 hours + 1);
        
        // Now emergency withdrawal should work
        vm.startPrank(user1);
        
        (,,,,, uint256 requestId,) = vault.getPosition(user1);
        
        vm.expectEmit(true, true, false, true);
        emit EmergencyWithdrawal(user1, requestId, block.timestamp);
        
        vault.userEmergencyWithdraw();
        
        // Check collateral returned
        uint256 finalWETHBalance = weth.balanceOf(user1);
        assertEq(finalWETHBalance, initialWETHBalance + DEPOSIT_AMOUNT, "Should get all collateral back");
        
        // Check position cleared
        (address[] memory posTokens,,,,,, bool hasPending) = vault.getPosition(user1);
        assertEq(posTokens.length, 0, "Position should be cleared");
        assertFalse(hasPending, "Should have no pending request");
        
        vm.stopPrank();
    }

    /// @notice Test multi-token basket deposit and withdrawal
    function test_multiTokenBasket() public {
        vm.startPrank(user1);
        
        // Setup multi-token basket (using realistic amounts within available balances)
        address[] memory tokens = new address[](3);
        uint256[] memory amounts = new uint256[](3);
        tokens[0] = address(weth);
        tokens[1] = address(usdc);
        tokens[2] = address(dai);
        amounts[0] = 2 ether; // $4,000
        amounts[1] = 2000 * 1e6; // $2,000 (USDC has 6 decimals)
        amounts[2] = 500 ether; // $500 (within 1000 ether balance)
        // Total: $6,500
        
        uint256 expectedTotalValue = (2 * 2000 + 2000 + 500) * 1e18; // $6,500 in 18 decimals
        
        vm.expectEmit(true, false, false, false);
        emit CollateralDeposited(user1, tokens, amounts, expectedTotalValue);
        
        vault.depositBasket(tokens, amounts);
        
        // Check position
        (address[] memory posTokens, uint256[] memory posAmounts, uint256 totalValue,,,, bool hasPending) = vault.getPosition(user1);
        assertEq(posTokens.length, 3, "Should have 3 tokens");
        assertEq(posAmounts[0], 2 ether, "WETH amount correct");
        assertEq(posAmounts[1], 2000 * 1e6, "USDC amount correct");
        assertEq(posAmounts[2], 500 ether, "DAI amount correct");
        assertEq(totalValue, expectedTotalValue, "Total value calculated correctly");
        assertTrue(hasPending, "Should have pending request");
        
        vm.stopPrank();
    }

    /// @notice Test token management functions
    function test_tokenManagement() public {
        vm.startPrank(owner);
        
        // Add new token
        address newToken = makeAddr("newToken");
        uint256 price = 500 * 1e18; // $500
        
        vm.expectEmit(true, false, false, true);
        emit TokenAdded(newToken, price, 18);
        
        vault.addToken(newToken, price, 18, "NEW");
        
        // Check token added
        (uint256 tokenPrice, uint8 decimals, bool supported) = vault.supportedTokens(newToken);
        assertEq(tokenPrice, price, "Price should be set");
        assertEq(decimals, 18, "Decimals should be set");
        assertTrue(supported, "Token should be supported");
        
        // Update token price
        uint256 newPrice = 600 * 1e18;
        
        vm.expectEmit(true, false, false, true);
        emit TokenPriceUpdated(newToken, newPrice);
        
        vault.updateTokenPrice(newToken, newPrice);
        
        // Check price updated
        (uint256 updatedPrice,,) = vault.supportedTokens(newToken);
        assertEq(updatedPrice, newPrice, "Price should be updated");
        
        vm.stopPrank();
    }

    /// @notice Test controller update functionality
    function test_controllerUpdate() public {
        vm.startPrank(owner);
        
        address newController = makeAddr("newController");
        address oldController = address(controller);
        
        vm.expectEmit(true, true, false, false);
        emit ControllerUpdated(oldController, newController);
        
        vault.updateController(newController);
        
        // Check controller updated
        assertEq(address(vault.riskOracleController()), newController, "Controller should be updated");
        
        vm.stopPrank();
    }

    /// @notice Test view functions
    function test_viewFunctions() public {
        // Test canEmergencyWithdraw for user without position
        (bool canWithdraw, uint256 timeRemaining) = vault.canEmergencyWithdraw(user1);
        assertFalse(canWithdraw, "Should not be able to withdraw without position");
        assertEq(timeRemaining, 0, "No time remaining for non-existent position");
        
        // Setup pending position
        vm.startPrank(user1);
        address[] memory tokens = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        tokens[0] = address(weth);
        amounts[0] = DEPOSIT_AMOUNT;
        vault.depositBasket(tokens, amounts);
        vm.stopPrank();
        
        // Test canEmergencyWithdraw immediately after deposit
        (canWithdraw, timeRemaining) = vault.canEmergencyWithdraw(user1);
        assertFalse(canWithdraw, "Should not be able to withdraw immediately");
        assertGt(timeRemaining, 0, "Should have time remaining");
        
        // Test getPositionStatus
        (bool hasPosition, bool isPending, uint256 requestId, uint256 timeElapsed) = vault.getPositionStatus(user1);
        assertTrue(hasPosition, "Should have position");
        assertTrue(isPending, "Should be pending");
        assertGt(requestId, 0, "Should have request ID");
        assertGe(timeElapsed, 0, "Should have time elapsed");
        
        // Fast forward and test again
        vm.warp(block.timestamp + 4 hours + 1);
        
        (canWithdraw, timeRemaining) = vault.canEmergencyWithdraw(user1);
        assertTrue(canWithdraw, "Should be able to withdraw after 4 hours");
        assertEq(timeRemaining, 0, "No time remaining");
    }

    /// @notice Test error conditions
    function test_errorConditions() public {
        vm.startPrank(user1);
        
        // Test empty basket
        address[] memory emptyTokens = new address[](0);
        uint256[] memory emptyAmounts = new uint256[](0);
        
        vm.expectRevert(CollateralVault.EmptyBasket.selector);
        vault.depositBasket(emptyTokens, emptyAmounts);
        
        // Test array length mismatch
        address[] memory tokens = new address[](1);
        uint256[] memory amounts = new uint256[](2);
        tokens[0] = address(weth);
        amounts[0] = DEPOSIT_AMOUNT;
        amounts[1] = DEPOSIT_AMOUNT;
        
        vm.expectRevert(CollateralVault.ArrayLengthMismatch.selector);
        vault.depositBasket(tokens, amounts);
        
        // Test unsupported token
        address unsupportedToken = makeAddr("unsupported");
        tokens = new address[](1);
        amounts = new uint256[](1);
        tokens[0] = unsupportedToken;
        amounts[0] = DEPOSIT_AMOUNT;
        
        vm.expectRevert(CollateralVault.TokenNotSupported.selector);
        vault.depositBasket(tokens, amounts);
        
        // Test withdraw without position
        vm.expectRevert(CollateralVault.NoPosition.selector);
        vault.withdrawCollateral(100);
        
        vm.stopPrank();
    }

    /// @notice Test pending request protection
    function test_pendingRequestProtection() public {
        // Setup pending position
        vm.startPrank(user1);
        address[] memory tokens = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        tokens[0] = address(weth);
        amounts[0] = DEPOSIT_AMOUNT;
        
        vault.depositBasket(tokens, amounts);
        
        // Try to deposit again while pending
        vm.expectRevert(CollateralVault.PendingAIRequest.selector);
        vault.depositBasket(tokens, amounts);
        
        vm.stopPrank();
        
        // Complete the request
        _completeRequest(user1);
        
        // Try to withdraw while having minted AIUSD but no pending request
        vm.startPrank(user1);
        // Approve vault to burn AIUSD
        aiusd.approve(address(vault), type(uint256).max);
        vault.withdrawCollateral(100); // Should work now
        vm.stopPrank();
    }

    /// @notice Helper function to setup a completed position
    function _setupCompletedPosition(address user) internal returns (uint256 requestId) {
        vm.startPrank(user);
        address[] memory tokens = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        tokens[0] = address(weth);
        amounts[0] = DEPOSIT_AMOUNT;
        
        vault.depositBasket(tokens, amounts);
        (,,,,, requestId,) = vault.getPosition(user);
        vm.stopPrank();
        
        // Complete the request
        _completeRequest(user);
        
        return requestId;
    }

    /// @notice Helper function to complete a pending request
    function _completeRequest(address user) internal {
        (,,,,, uint256 requestId,) = vault.getPosition(user);
        
        // Simulate AI callback
        bytes memory response = abi.encode("RATIO:150 CONFIDENCE:85");
        mockRouter.simulateCallback(requestId, response, "");
    }
} 