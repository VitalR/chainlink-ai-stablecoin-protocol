// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import { console } from "forge-std/console.sol";

import { CollateralVault } from "../../src/CollateralVault.sol";
import { AIStablecoin } from "../../src/AIStablecoin.sol";
import { RiskOracleController } from "../../src/RiskOracleController.sol";
import { MockWETH } from "../mocks/MockWETH.sol";
import { AutoEmergencyWithdrawal } from "../../src/automation/AutoEmergencyWithdrawal.sol";

/// @title CollateralVault Automation Authorization Unit Tests
/// @notice Comprehensive tests for the automation authorization functionality
/// @dev Tests the new automation authorization system for emergency withdrawals
contract CollateralVaultAutomationTest is Test {
    // Core contracts
    CollateralVault vault;
    AIStablecoin aiusd;
    RiskOracleController controller;
    MockWETH weth;
    AutoEmergencyWithdrawal automationContract;

    // Test addresses
    address deployer = address(this);
    address user1 = makeAddr("user1");
    address user2 = makeAddr("user2");
    address automation1 = makeAddr("automation1");
    address automation2 = makeAddr("automation2");
    address notOwner = makeAddr("notOwner");

    // Events to test
    event AutomationAuthorized(address indexed automation, bool authorized);

    function setUp() public {
        // Deploy core contracts
        aiusd = new AIStablecoin();
        controller = new RiskOracleController(
            0xb83E47C2bC239B3bf370bc41e1459A34b41238D0, // Sepolia Functions Router
            0x66756e2d657468657265756d2d7365706f6c69612d3100000000000000000000, // DON ID
            5075, // Subscription ID
            "const request = Functions.makeHttpRequest({ url: 'https://example.com' }); return Functions.encodeString('test');" // AI
                // Source Code
        );
        vault = new CollateralVault(
            address(aiusd),
            address(controller),
            address(0), // No automation contract yet
            new CollateralVault.TokenConfig[](0) // No initial tokens
        );

        // Deploy test token
        weth = new MockWETH();

        // Deploy automation contract
        automationContract = new AutoEmergencyWithdrawal(address(vault));

        // Setup permissions
        aiusd.addVault(address(vault));
        controller.setAuthorizedCaller(address(vault), true);

        // Add WETH as supported token
        vault.addToken(address(weth), 3500e18, 18, "WETH");

        // Setup test tokens for users
        weth.mint(user1, 10 ether);
        weth.mint(user2, 10 ether);

        vm.prank(user1);
        weth.approve(address(vault), type(uint256).max);

        vm.prank(user2);
        weth.approve(address(vault), type(uint256).max);
    }

    // =============================================================
    //                    AUTHORIZATION TESTS
    // =============================================================

    /// @notice Test successful automation authorization
    function test_SetAutomationAuthorized_Success() public {
        // Initial state should be false
        assertFalse(vault.authorizedAutomation(automation1));

        // Authorize automation contract
        vm.expectEmit(true, false, false, true);
        emit AutomationAuthorized(automation1, true);

        vault.setAutomationAuthorized(automation1, true);

        // Verify authorization
        assertTrue(vault.authorizedAutomation(automation1));
    }

    /// @notice Test automation deauthorization
    function test_SetAutomationAuthorized_Deauthorize() public {
        // First authorize
        vault.setAutomationAuthorized(automation1, true);
        assertTrue(vault.authorizedAutomation(automation1));

        // Then deauthorize
        vm.expectEmit(true, false, false, true);
        emit AutomationAuthorized(automation1, false);

        vault.setAutomationAuthorized(automation1, false);

        // Verify deauthorization
        assertFalse(vault.authorizedAutomation(automation1));
    }

    /// @notice Test multiple automation contracts
    function test_SetAutomationAuthorized_MultipleContracts() public {
        // Authorize multiple contracts
        vault.setAutomationAuthorized(automation1, true);
        vault.setAutomationAuthorized(automation2, true);

        // Verify both are authorized
        assertTrue(vault.authorizedAutomation(automation1));
        assertTrue(vault.authorizedAutomation(automation2));

        // Deauthorize one
        vault.setAutomationAuthorized(automation1, false);

        // Verify state
        assertFalse(vault.authorizedAutomation(automation1));
        assertTrue(vault.authorizedAutomation(automation2));
    }

    /// @notice Test authorization with zero address should revert
    function test_SetAutomationAuthorized_ZeroAddress() public {
        vm.expectRevert(CollateralVault.ZeroAddress.selector);
        vault.setAutomationAuthorized(address(0), true);
    }

    /// @notice Test non-owner cannot authorize automation contracts
    function test_SetAutomationAuthorized_OnlyOwner() public {
        vm.prank(notOwner);
        vm.expectRevert(); // Should revert with ownership error
        vault.setAutomationAuthorized(automation1, true);
    }

    // =============================================================
    //                    EMERGENCY WITHDRAW TESTS
    // =============================================================

    /// @notice Test authorized automation can call emergencyWithdraw
    function test_EmergencyWithdraw_AuthorizedAutomation() public {
        // Setup: Create a stuck position
        _createStuckPosition(user1, 1 ether);

        // Authorize automation contract
        vault.setAutomationAuthorized(automation1, true);

        // Fast forward past emergency delay
        vm.warp(block.timestamp + vault.emergencyWithdrawalDelay() + 1);

        // Get user's initial balance
        uint256 initialBalance = weth.balanceOf(user1);

        // Automation contract should be able to perform emergency withdrawal
        vm.prank(automation1);
        vault.emergencyWithdraw(user1, 1); // requestId = 1

        // Verify tokens were returned
        assertGt(weth.balanceOf(user1), initialBalance);
    }

    /// @notice Test unauthorized automation cannot call emergencyWithdraw
    function test_EmergencyWithdraw_UnauthorizedAutomation() public {
        // Setup: Create a stuck position
        _createStuckPosition(user1, 1 ether);

        // Fast forward past emergency delay
        vm.warp(block.timestamp + vault.emergencyWithdrawalDelay() + 1);

        // Unauthorized automation should not be able to perform emergency withdrawal
        vm.prank(automation1); // Not authorized
        vm.expectRevert(CollateralVault.OnlyRiskOracleController.selector);
        vault.emergencyWithdraw(user1, 1);
    }

    /// @notice Test controller can still call emergencyWithdraw (backward compatibility)
    function test_EmergencyWithdraw_ControllerStillWorks() public {
        // Setup: Create a stuck position
        _createStuckPosition(user1, 1 ether);

        // Fast forward past emergency delay
        vm.warp(block.timestamp + vault.emergencyWithdrawalDelay() + 1);

        // Get user's initial balance
        uint256 initialBalance = weth.balanceOf(user1);

        // Controller should still be able to perform emergency withdrawal
        vm.prank(address(controller));
        vault.emergencyWithdraw(user1, 1);

        // Verify tokens were returned
        assertGt(weth.balanceOf(user1), initialBalance);
    }

    /// @notice Test deauthorized automation cannot call emergencyWithdraw
    function test_EmergencyWithdraw_DeauthorizedAutomation() public {
        // Setup: Create a stuck position
        _createStuckPosition(user1, 1 ether);

        // Authorize then deauthorize automation
        vault.setAutomationAuthorized(automation1, true);
        vault.setAutomationAuthorized(automation1, false);

        // Fast forward past emergency delay
        vm.warp(block.timestamp + vault.emergencyWithdrawalDelay() + 1);

        // Deauthorized automation should not work
        vm.prank(automation1);
        vm.expectRevert(CollateralVault.OnlyRiskOracleController.selector);
        vault.emergencyWithdraw(user1, 1);
    }

    // =============================================================
    //                    INTEGRATION TESTS
    // =============================================================

    /// @notice Test full automation workflow
    function test_FullAutomationWorkflow() public {
        // Step 1: Deploy and authorize automation contract
        vault.setAutomationAuthorized(address(automationContract), true);

        // Step 2: User opts into automation
        vm.prank(user1);
        automationContract.optInToAutomation();

        // Step 3: User creates a position that gets stuck
        _createStuckPosition(user1, 2 ether);

        // Step 4: Check automation cannot trigger yet
        (bool upkeepNeeded,) = automationContract.checkUpkeep("");
        assertFalse(upkeepNeeded);

        // Step 5: Fast forward time
        vm.warp(block.timestamp + vault.emergencyWithdrawalDelay() + 1);

        // Step 6: Check automation can now trigger
        (upkeepNeeded,) = automationContract.checkUpkeep("");
        assertTrue(upkeepNeeded);

        // Step 7: Execute automation
        uint256 initialBalance = weth.balanceOf(user1);
        (, bytes memory performData) = automationContract.checkUpkeep("");
        automationContract.performUpkeep(performData);

        // Step 8: Verify tokens were recovered
        assertGt(weth.balanceOf(user1), initialBalance);
    }

    /// @notice Test automation with multiple users
    function test_AutomationMultipleUsers() public {
        // Authorize automation
        vault.setAutomationAuthorized(address(automationContract), true);

        // Both users opt in
        vm.prank(user1);
        automationContract.optInToAutomation();

        vm.prank(user2);
        automationContract.optInToAutomation();

        // Both users create stuck positions
        _createStuckPosition(user1, 1 ether);
        _createStuckPosition(user2, 2 ether);

        // Fast forward time
        vm.warp(block.timestamp + vault.emergencyWithdrawalDelay() + 1);

        // Check automation detects both
        (bool upkeepNeeded,) = automationContract.checkUpkeep("");
        assertTrue(upkeepNeeded);

        // Execute automation (should handle both users)
        uint256 user1BalanceBefore = weth.balanceOf(user1);
        uint256 user2BalanceBefore = weth.balanceOf(user2);

        (, bytes memory performData) = automationContract.checkUpkeep("");
        automationContract.performUpkeep(performData);

        // Both users should have recovered tokens
        assertGt(weth.balanceOf(user1), user1BalanceBefore);
        assertGt(weth.balanceOf(user2), user2BalanceBefore);
    }

    /// @notice Test authorization status query
    function test_AuthorizedAutomationQuery() public {
        // Initially false
        assertFalse(vault.authorizedAutomation(automation1));
        assertFalse(vault.authorizedAutomation(automation2));

        // Authorize one
        vault.setAutomationAuthorized(automation1, true);

        assertTrue(vault.authorizedAutomation(automation1));
        assertFalse(vault.authorizedAutomation(automation2));

        // Authorize second
        vault.setAutomationAuthorized(automation2, true);

        assertTrue(vault.authorizedAutomation(automation1));
        assertTrue(vault.authorizedAutomation(automation2));
    }

    // =============================================================
    //                    EDGE CASES & SECURITY
    // =============================================================

    /// @notice Test automation cannot be used for unauthorized operations
    function test_AutomationCannotCallOtherFunctions() public {
        // Authorize automation
        vault.setAutomationAuthorized(automation1, true);

        // Try to call other restricted functions
        vm.startPrank(automation1);

        // Should not be able to call owner functions
        vm.expectRevert();
        vault.addToken(address(weth), 3500e18, 18, "WETH2");

        vm.stopPrank();
    }

    /// @notice Test authorization doesn't affect normal user functions
    function test_AuthorizationDoesNotAffectUserFunctions() public {
        // Authorize automation
        vault.setAutomationAuthorized(automation1, true);

        // User should still be able to deposit normally
        address[] memory tokens = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        tokens[0] = address(weth);
        amounts[0] = 1 ether;

        vm.prank(user1);
        vault.depositBasket(tokens, amounts);

        // Verify deposit worked
        (bool hasPosition,,,) = vault.getPositionStatus(user1);
        assertTrue(hasPosition);
    }

    /// @notice Test events are properly emitted
    function test_AutomationAuthorizationEvents() public {
        // Test authorization event
        vm.expectEmit(true, false, false, true);
        emit AutomationAuthorized(automation1, true);
        vault.setAutomationAuthorized(automation1, true);

        // Test deauthorization event
        vm.expectEmit(true, false, false, true);
        emit AutomationAuthorized(automation1, false);
        vault.setAutomationAuthorized(automation1, false);
    }

    // =============================================================
    //                    HELPER FUNCTIONS
    // =============================================================

    /// @notice Helper to create a stuck position for testing
    function _createStuckPosition(address user, uint256 amount) internal {
        address[] memory tokens = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        tokens[0] = address(weth);
        amounts[0] = amount;

        vm.prank(user);
        vault.depositBasket(tokens, amounts);

        // Verify position was created
        (bool hasPosition, bool isPending,,) = vault.getPositionStatus(user);
        assertTrue(hasPosition);
        assertTrue(isPending); // Should be pending AI request
    }
}
