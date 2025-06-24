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
            address(mockRouter), bytes32("fun_sepolia_1"), 123, "return 'RATIO:150 CONFIDENCE:85';"
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

    /// @notice Test enhanced position management with multiple positions
    function test_multiplePositions() public {
        vm.startPrank(user1);

        // Position 1: WETH only
        address[] memory tokens1 = new address[](1);
        uint256[] memory amounts1 = new uint256[](1);
        tokens1[0] = address(weth);
        amounts1[0] = 5 ether; // $10,000

        vault.depositBasket(tokens1, amounts1);

        // Check position count
        assertEq(vault.userPositionCount(user1), 1, "Should have 1 position");

        // Complete first position
        _completeRequest(user1, 0);

        // Position 2: Multi-token basket
        address[] memory tokens2 = new address[](2);
        uint256[] memory amounts2 = new uint256[](2);
        tokens2[0] = address(usdc);
        tokens2[1] = address(dai);
        amounts2[0] = 1000 * 1e6; // $1,000
        amounts2[1] = 500 ether; // $500

        vault.depositBasket(tokens2, amounts2);

        // Check position count increased
        assertEq(vault.userPositionCount(user1), 2, "Should have 2 positions");

        // Complete second position
        _completeRequest(user1, 1);

        // Test getDepositPositions
        CollateralVault.Position[] memory positions = vault.getDepositPositions();
        assertEq(positions.length, 2, "Should return 2 positions");
        assertEq(positions[0].tokens.length, 1, "Position 0 should have 1 token");
        assertEq(positions[1].tokens.length, 2, "Position 1 should have 2 tokens");

        // Test getPositionSummary
        (uint256 totalPositions, uint256 activePositions, uint256 totalValueUSD, uint256 totalAIUSDMinted) =
            vault.getPositionSummary(user1);
        assertEq(totalPositions, 2, "Should have 2 total positions");
        assertEq(activePositions, 2, "Should have 2 active positions");
        assertGt(totalValueUSD, 0, "Should have total value");
        assertGt(totalAIUSDMinted, 0, "Should have minted AIUSD");

        vm.stopPrank();
    }

    /// @notice Test withdrawing from specific positions
    function test_withdrawFromSpecificPosition() public {
        // Setup two positions
        vm.startPrank(user1);

        // Position 0: WETH
        address[] memory tokens1 = new address[](1);
        uint256[] memory amounts1 = new uint256[](1);
        tokens1[0] = address(weth);
        amounts1[0] = 5 ether;
        vault.depositBasket(tokens1, amounts1);
        _completeRequest(user1, 0);

        // Position 1: DAI
        address[] memory tokens2 = new address[](1);
        uint256[] memory amounts2 = new uint256[](1);
        tokens2[0] = address(dai);
        amounts2[0] = 1000 ether;
        vault.depositBasket(tokens2, amounts2);
        _completeRequest(user1, 1);

        // Get position info
        CollateralVault.Position memory pos0 = vault.getUserDepositInfo(user1, 0);
        CollateralVault.Position memory pos1 = vault.getUserDepositInfo(user1, 1);

        uint256 initialWETH = weth.balanceOf(user1);
        uint256 initialDAI = dai.balanceOf(user1);

        // Approve AIUSD for burning
        aiusd.approve(address(vault), type(uint256).max);

        // Withdraw half from position 0 (WETH)
        uint256 withdrawAmount0 = pos0.aiusdMinted / 2;
        vault.withdrawFromPosition(0, withdrawAmount0);

        // Check WETH returned but DAI unchanged
        assertGt(weth.balanceOf(user1), initialWETH, "Should receive WETH");
        assertEq(dai.balanceOf(user1), initialDAI, "DAI should be unchanged");

        // Withdraw from position 1 (DAI)
        uint256 withdrawAmount1 = pos1.aiusdMinted / 4;
        vault.withdrawFromPosition(1, withdrawAmount1);

        // Check DAI returned
        assertGt(dai.balanceOf(user1), initialDAI, "Should receive DAI");

        vm.stopPrank();
    }

    /// @notice Test user emergency withdrawal with enhanced positions
    function test_userEmergencyWithdrawEnhanced() public {
        // Setup pending position
        vm.startPrank(user1);
        address[] memory tokens = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        tokens[0] = address(weth);
        amounts[0] = DEPOSIT_AMOUNT;

        vault.depositBasket(tokens, amounts);
        uint256 initialWETHBalance = weth.balanceOf(user1);
        vm.stopPrank();

        // Try emergency withdrawal before delay - should fail
        vm.startPrank(user1);
        vm.expectRevert("Must wait");
        vault.userEmergencyWithdraw();
        vm.stopPrank();

        // Fast forward past emergency delay
        vm.warp(block.timestamp + vault.emergencyWithdrawalDelay() + 1);

        // Now emergency withdrawal should work
        vm.startPrank(user1);

        CollateralVault.Position memory position = vault.getUserDepositInfo(user1, 0);
        uint256 requestId = position.requestId;

        vm.expectEmit(true, true, false, true);
        emit EmergencyWithdrawal(user1, requestId, block.timestamp);

        vault.userEmergencyWithdraw();

        // Check collateral returned
        uint256 finalWETHBalance = weth.balanceOf(user1);
        assertEq(finalWETHBalance, initialWETHBalance + DEPOSIT_AMOUNT, "Should get all collateral back");

        vm.stopPrank();
    }

    /// @notice Test configurable emergency withdrawal delay
    function test_configurableEmergencyDelay() public {
        // Test default delay
        assertEq(vault.emergencyWithdrawalDelay(), 4 hours, "Should have default 4 hour delay");

        // Update delay as owner
        vm.startPrank(owner);
        uint256 newDelay = 2 hours;

        vault.updateEmergencyWithdrawalDelay(newDelay);
        assertEq(vault.emergencyWithdrawalDelay(), newDelay, "Should update delay");

        vm.stopPrank();

        // Test new delay works
        vm.startPrank(user1);
        address[] memory tokens = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        tokens[0] = address(weth);
        amounts[0] = DEPOSIT_AMOUNT;
        vault.depositBasket(tokens, amounts);
        vm.stopPrank();

        // Should fail before new delay
        vm.warp(block.timestamp + 1 hours);
        vm.startPrank(user1);
        vm.expectRevert("Must wait");
        vault.userEmergencyWithdraw();
        vm.stopPrank();

        // Should work after new delay
        vm.warp(block.timestamp + 2 hours);
        vm.startPrank(user1);
        vault.userEmergencyWithdraw(); // Should not revert
        vm.stopPrank();
    }

    /// @notice Test enhanced view functions
    function test_enhancedViewFunctions() public {
        vm.startPrank(user1);

        // Initially no positions
        assertEq(vault.userPositionCount(user1), 0, "Should start with 0 positions");

        CollateralVault.Position[] memory positions = vault.getDepositPositions();
        assertEq(positions.length, 0, "Should return empty array");

        // Create first position
        address[] memory tokens = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        tokens[0] = address(weth);
        amounts[0] = DEPOSIT_AMOUNT;
        vault.depositBasket(tokens, amounts);

        // Check position count
        assertEq(vault.userPositionCount(user1), 1, "Should have 1 position");

        // Get specific position info
        CollateralVault.Position memory pos = vault.getUserDepositInfo(user1, 0);
        assertEq(pos.tokens.length, 1, "Position should have 1 token");
        assertEq(pos.tokens[0], address(weth), "Should be WETH");
        assertEq(pos.amounts[0], DEPOSIT_AMOUNT, "Should have correct amount");
        assertEq(pos.index, 0, "Should have index 0");
        assertTrue(pos.hasPendingRequest, "Should have pending request");

        vm.stopPrank();
    }

    /// @notice Test error conditions with enhanced positions
    function test_errorConditionsEnhanced() public {
        vm.startPrank(user1);

        // Test withdraw from non-existent position
        vm.expectRevert(CollateralVault.NoPosition.selector);
        vault.withdrawFromPosition(0, 100);

        // Create and complete a position
        address[] memory tokens = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        tokens[0] = address(weth);
        amounts[0] = DEPOSIT_AMOUNT;
        vault.depositBasket(tokens, amounts);
        vm.stopPrank();

        _completeRequest(user1, 0);

        vm.startPrank(user1);

        // Test withdraw more than minted
        CollateralVault.Position memory pos = vault.getUserDepositInfo(user1, 0);
        aiusd.approve(address(vault), type(uint256).max);

        vm.expectRevert(CollateralVault.InsufficientAIUSD.selector);
        vault.withdrawFromPosition(0, pos.aiusdMinted + 1);

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
        vm.stopPrank();

        // Complete the request
        _completeRequest(user, 0);

        CollateralVault.Position memory pos = vault.getUserDepositInfo(user, 0);
        return pos.requestId;
    }

    /// @notice Helper function to complete a pending request for a specific position
    function _completeRequest(address user, uint256 positionIndex) internal {
        CollateralVault.Position memory position = vault.getUserDepositInfo(user, positionIndex);
        uint256 requestId = position.requestId;

        // Simulate AI callback
        bytes memory response = abi.encode("RATIO:150 CONFIDENCE:85");
        mockRouter.simulateCallback(requestId, response, "");
    }

    /// @notice Test enhanced emergency withdrawal system with multiple positions
    function test_enhancedEmergencyWithdrawal() public {
        vm.startPrank(user1);

        // Create first position
        address[] memory tokens1 = new address[](1);
        uint256[] memory amounts1 = new uint256[](1);
        tokens1[0] = address(weth);
        amounts1[0] = DEPOSIT_AMOUNT;
        vault.depositBasket(tokens1, amounts1);

        // Create second position
        address[] memory tokens2 = new address[](1);
        uint256[] memory amounts2 = new uint256[](1);
        tokens2[0] = address(dai);
        amounts2[0] = 1000 ether;
        vault.depositBasket(tokens2, amounts2);

        uint256 initialWETHBalance = weth.balanceOf(user1);
        uint256 initialDAIBalance = dai.balanceOf(user1);

        vm.stopPrank();

        // Fast forward past emergency delay
        vm.warp(block.timestamp + vault.emergencyWithdrawalDelay() + 1);

        // Test the new view function
        vm.startPrank(user1);
        (uint256[] memory eligibleIndices, uint256[] memory timeRemaining) =
            vault.getEmergencyWithdrawablePositions(user1);

        assertEq(eligibleIndices.length, 2, "Should have 2 eligible positions");
        assertEq(timeRemaining[0], 0, "First position should be ready");
        assertEq(timeRemaining[1], 0, "Second position should be ready");

        // Test auto-find emergency withdrawal (should find oldest)
        vault.userEmergencyWithdraw();

        // Check that first position (oldest) was withdrawn
        uint256 finalWETHBalance = weth.balanceOf(user1);
        assertEq(finalWETHBalance, initialWETHBalance + DEPOSIT_AMOUNT, "Should get WETH back from first position");

        // Test specific position emergency withdrawal
        vault.userEmergencyWithdraw(1); // Withdraw second position

        uint256 finalDAIBalance = dai.balanceOf(user1);
        assertEq(finalDAIBalance, initialDAIBalance + 1000 ether, "Should get DAI back from second position");

        vm.stopPrank();
    }

    /// @notice Test both variants of canEmergencyWithdraw function
    function test_canEmergencyWithdrawVariants() public {
        vm.startPrank(user1);

        // Create first position at time T
        address[] memory tokens1 = new address[](1);
        uint256[] memory amounts1 = new uint256[](1);
        tokens1[0] = address(weth);
        amounts1[0] = DEPOSIT_AMOUNT;
        vault.depositBasket(tokens1, amounts1);

        uint256 firstPositionTime = block.timestamp;

        // Move forward 1 hour and create second position
        vm.warp(block.timestamp + 1 hours);

        address[] memory tokens2 = new address[](1);
        uint256[] memory amounts2 = new uint256[](1);
        tokens2[0] = address(dai);
        amounts2[0] = 1000 ether;
        vault.depositBasket(tokens2, amounts2);

        vm.stopPrank();

        // Test 1: Neither position ready (before delay)
        vm.warp(firstPositionTime + 2 hours); // 2 hours after first, 1 hour after second

        // Check all positions - should return false with time remaining
        (bool canWithdrawAll, uint256 timeRemainingAll) = vault.canEmergencyWithdraw(user1);
        assertFalse(canWithdrawAll, "Should not be able to withdraw yet");
        assertEq(timeRemainingAll, 2 hours, "Should have 2 hours remaining for first position");

        // Check specific positions
        (bool canWithdraw0, uint256 timeRemaining0) = vault.canEmergencyWithdraw(user1, 0);
        (bool canWithdraw1, uint256 timeRemaining1) = vault.canEmergencyWithdraw(user1, 1);

        assertFalse(canWithdraw0, "Position 0 should not be ready");
        assertFalse(canWithdraw1, "Position 1 should not be ready");
        assertEq(timeRemaining0, 2 hours, "Position 0 should have 2 hours remaining");
        assertEq(timeRemaining1, 3 hours, "Position 1 should have 3 hours remaining");

        // Test 2: First position ready, second not ready
        vm.warp(firstPositionTime + vault.emergencyWithdrawalDelay() + 1 minutes);

        // Check all positions - should return true (first position ready)
        (canWithdrawAll, timeRemainingAll) = vault.canEmergencyWithdraw(user1);
        assertTrue(canWithdrawAll, "Should be able to withdraw (first position ready)");
        assertEq(timeRemainingAll, 0, "Should have 0 time remaining");

        // Check specific positions
        (canWithdraw0, timeRemaining0) = vault.canEmergencyWithdraw(user1, 0);
        (canWithdraw1, timeRemaining1) = vault.canEmergencyWithdraw(user1, 1);

        assertTrue(canWithdraw0, "Position 0 should be ready");
        assertFalse(canWithdraw1, "Position 1 should not be ready yet");
        assertEq(timeRemaining0, 0, "Position 0 should have 0 time remaining");
        assertGt(timeRemaining1, 0, "Position 1 should still have time remaining");

        // Test 3: Both positions ready
        vm.warp(firstPositionTime + vault.emergencyWithdrawalDelay() + 1 hours + 1 minutes);

        // Check all positions
        (canWithdrawAll, timeRemainingAll) = vault.canEmergencyWithdraw(user1);
        assertTrue(canWithdrawAll, "Should be able to withdraw (both ready)");
        assertEq(timeRemainingAll, 0, "Should have 0 time remaining");

        // Check specific positions
        (canWithdraw0, timeRemaining0) = vault.canEmergencyWithdraw(user1, 0);
        (canWithdraw1, timeRemaining1) = vault.canEmergencyWithdraw(user1, 1);

        assertTrue(canWithdraw0, "Position 0 should be ready");
        assertTrue(canWithdraw1, "Position 1 should be ready");
        assertEq(timeRemaining0, 0, "Position 0 should have 0 time remaining");
        assertEq(timeRemaining1, 0, "Position 1 should have 0 time remaining");

        // Test 4: Check non-existent position
        (bool canWithdrawInvalid, uint256 timeRemainingInvalid) = vault.canEmergencyWithdraw(user1, 5);
        assertFalse(canWithdrawInvalid, "Invalid position should return false");
        assertEq(timeRemainingInvalid, 0, "Invalid position should have 0 time remaining");
    }
}
