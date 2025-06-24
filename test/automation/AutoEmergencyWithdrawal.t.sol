// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import { AutoEmergencyWithdrawal } from "../../src/automation/AutoEmergencyWithdrawal.sol";
import { CollateralVault } from "../../src/CollateralVault.sol";
import { AIStablecoin } from "../../src/AIStablecoin.sol";
import { RiskOracleController } from "../../src/RiskOracleController.sol";

import { MockChainlinkFunctionsRouter } from "../mocks/MockChainlinkFunctionsRouter.sol";
import { MockWETH } from "../mocks/MockWETH.sol";
import { MockDAI } from "../mocks/MockDAI.sol";

/// @title AutoEmergencyWithdrawalTest - Tests for Chainlink Automation Emergency Withdrawal
/// @notice Comprehensive tests for automated emergency withdrawal functionality
contract AutoEmergencyWithdrawalTest is Test {
    // Core contracts
    AutoEmergencyWithdrawal public autoWithdrawer;
    CollateralVault public vault;
    AIStablecoin public aiusd;
    RiskOracleController public controller;
    MockChainlinkFunctionsRouter public mockRouter;

    // Mock tokens
    MockWETH public weth;
    MockDAI public dai;

    // Test accounts
    address public owner = makeAddr("owner");
    address public user1 = makeAddr("user1");
    address public user2 = makeAddr("user2");
    address public user3 = makeAddr("user3");

    // Test constants
    uint256 public constant INITIAL_BALANCE = 1000 ether;
    uint256 public constant DEPOSIT_AMOUNT = 10 ether;

    // Events to test
    event UserOptedIn(address indexed user);
    event UserOptedOut(address indexed user);
    event EmergencyWithdrawalTriggered(address indexed user, uint256 positionIndex, uint256 requestId);
    event BatchProcessingCompleted(uint256 usersChecked, uint256 withdrawalsTriggered);

    function setUp() public {
        vm.startPrank(owner);

        // Deploy mock tokens
        weth = new MockWETH();
        dai = new MockDAI();

        // Deploy mock Chainlink Functions router
        mockRouter = new MockChainlinkFunctionsRouter();

        // Deploy core contracts
        aiusd = new AIStablecoin();
        controller = new RiskOracleController(
            address(mockRouter), bytes32("fun_sepolia_1"), 123, "return 'RATIO:150 CONFIDENCE:85';"
        );
        vault = new CollateralVault(
            address(aiusd),
            address(controller),
            address(0), // No automation contract yet
            new CollateralVault.TokenConfig[](0) // No initial tokens
        );

        // Deploy automation contract
        autoWithdrawer = new AutoEmergencyWithdrawal(address(vault));

        // Setup permissions
        aiusd.addVault(address(vault));
        controller.setAuthorizedCaller(address(vault), true);

        // IMPORTANT: Authorize automation contract for emergency withdrawals
        vault.setAutomationAuthorized(address(autoWithdrawer), true);

        // Setup tokens
        vault.addToken(address(weth), 2000 * 1e18, 18, "WETH");
        vault.addToken(address(dai), 1 * 1e18, 18, "DAI");

        // Mint tokens to users
        weth.mint(user1, INITIAL_BALANCE);
        weth.mint(user2, INITIAL_BALANCE);
        weth.mint(user3, INITIAL_BALANCE);

        dai.mint(user1, INITIAL_BALANCE);
        dai.mint(user2, INITIAL_BALANCE);
        dai.mint(user3, INITIAL_BALANCE);

        vm.stopPrank();

        // Fund users
        vm.deal(user1, 10 ether);
        vm.deal(user2, 10 ether);
        vm.deal(user3, 10 ether);

        // Approve vault for all users
        vm.startPrank(user1);
        weth.approve(address(vault), type(uint256).max);
        dai.approve(address(vault), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(user2);
        weth.approve(address(vault), type(uint256).max);
        dai.approve(address(vault), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(user3);
        weth.approve(address(vault), type(uint256).max);
        dai.approve(address(vault), type(uint256).max);
        vm.stopPrank();
    }

    /// @notice Test basic opt-in/opt-out functionality
    function test_userOptInOut() public {
        // Test opt-in
        vm.startPrank(user1);
        vm.expectEmit(true, false, false, false);
        emit UserOptedIn(user1);

        autoWithdrawer.optInToAutomation();
        assertTrue(autoWithdrawer.isUserOptedIn(user1), "User should be opted in");
        assertEq(autoWithdrawer.getTotalUsers(), 1, "Should have 1 user");

        // Test opt-out
        vm.expectEmit(true, false, false, false);
        emit UserOptedOut(user1);

        autoWithdrawer.optOutOfAutomation();
        assertFalse(autoWithdrawer.isUserOptedIn(user1), "User should be opted out");

        vm.stopPrank();
    }

    /// @notice Test automation with no eligible positions
    function test_checkUpkeepWithNoEligiblePositions() public {
        // No users opted in
        (bool upkeepNeeded, bytes memory performData) = autoWithdrawer.checkUpkeep("");
        assertFalse(upkeepNeeded, "Should not need upkeep with no users");

        // User opted in but no positions
        vm.startPrank(user1);
        autoWithdrawer.optInToAutomation();
        vm.stopPrank();

        (upkeepNeeded, performData) = autoWithdrawer.checkUpkeep("");
        assertFalse(upkeepNeeded, "Should not need upkeep with no positions");
    }

    /// @notice Test automation with pending positions (not yet eligible)
    function test_checkUpkeepWithPendingPositions() public {
        // Setup user with pending position
        vm.startPrank(user1);
        autoWithdrawer.optInToAutomation();

        address[] memory tokens = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        tokens[0] = address(weth);
        amounts[0] = DEPOSIT_AMOUNT;

        vault.depositBasket(tokens, amounts);
        vm.stopPrank();

        // Check upkeep before timeout
        (bool upkeepNeeded, bytes memory performData) = autoWithdrawer.checkUpkeep("");
        assertFalse(upkeepNeeded, "Should not need upkeep before timeout");
    }

    /// @notice Test automation with eligible positions
    function test_checkUpkeepWithEligiblePositions() public {
        // Setup user with position
        vm.startPrank(user1);
        autoWithdrawer.optInToAutomation();

        address[] memory tokens = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        tokens[0] = address(weth);
        amounts[0] = DEPOSIT_AMOUNT;

        vault.depositBasket(tokens, amounts);
        vm.stopPrank();

        // Fast forward past emergency delay
        vm.warp(block.timestamp + vault.emergencyWithdrawalDelay() + 1);

        // Check upkeep after timeout
        (bool upkeepNeeded, bytes memory performData) = autoWithdrawer.checkUpkeep("");
        assertTrue(upkeepNeeded, "Should need upkeep after timeout");
        assertGt(performData.length, 0, "Should have perform data");
    }

    /// @notice Test performing emergency withdrawal automation
    function test_performUpkeepEmergencyWithdrawal() public {
        // Setup user with position
        vm.startPrank(user1);
        autoWithdrawer.optInToAutomation();

        address[] memory tokens = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        tokens[0] = address(weth);
        amounts[0] = DEPOSIT_AMOUNT;

        uint256 initialBalance = weth.balanceOf(user1);
        vault.depositBasket(tokens, amounts);
        vm.stopPrank();

        // Fast forward past emergency delay
        vm.warp(block.timestamp + vault.emergencyWithdrawalDelay() + 1);

        // Get upkeep data
        (bool upkeepNeeded, bytes memory performData) = autoWithdrawer.checkUpkeep("");
        assertTrue(upkeepNeeded, "Should need upkeep");

        // Perform upkeep
        vm.expectEmit(true, false, false, false);
        emit EmergencyWithdrawalTriggered(user1, 0, 1);

        autoWithdrawer.performUpkeep(performData);

        // Verify user got tokens back
        uint256 finalBalance = weth.balanceOf(user1);
        assertEq(finalBalance, initialBalance, "User should get all tokens back");
    }

    /// @notice Test multiple users with different eligibility
    function test_multipleUsersAutomation() public {
        // Setup multiple users
        vm.startPrank(user1);
        autoWithdrawer.optInToAutomation();

        address[] memory tokens1 = new address[](1);
        uint256[] memory amounts1 = new uint256[](1);
        tokens1[0] = address(weth);
        amounts1[0] = DEPOSIT_AMOUNT;
        vault.depositBasket(tokens1, amounts1);
        vm.stopPrank();

        vm.startPrank(user2);
        autoWithdrawer.optInToAutomation();

        address[] memory tokens2 = new address[](1);
        uint256[] memory amounts2 = new uint256[](1);
        tokens2[0] = address(dai);
        amounts2[0] = 1000 ether;
        vault.depositBasket(tokens2, amounts2);
        vm.stopPrank();

        // User 3 opts in but doesn't deposit
        vm.startPrank(user3);
        autoWithdrawer.optInToAutomation();
        vm.stopPrank();

        // Fast forward past emergency delay
        vm.warp(block.timestamp + vault.emergencyWithdrawalDelay() + 1);

        // Check upkeep should find 2 eligible positions
        (bool upkeepNeeded, bytes memory performData) = autoWithdrawer.checkUpkeep("");
        assertTrue(upkeepNeeded, "Should need upkeep for multiple users");

        // Perform upkeep
        vm.expectEmit(false, false, false, false);
        emit BatchProcessingCompleted(2, 2); // Should process 2 withdrawals

        autoWithdrawer.performUpkeep(performData);

        // Verify both users got their tokens back
        assertGe(weth.balanceOf(user1), INITIAL_BALANCE - DEPOSIT_AMOUNT + DEPOSIT_AMOUNT, "User1 should get WETH back");
        assertGe(dai.balanceOf(user2), INITIAL_BALANCE - 1000 ether + 1000 ether, "User2 should get DAI back");
    }

    /// @notice Test round-robin checking with many users
    function test_roundRobinChecking() public {
        // Setup 5 users, but only 3 opt in
        address[] memory testUsers = new address[](5);
        for (uint256 i = 0; i < 5; i++) {
            testUsers[i] = makeAddr(string(abi.encodePacked("testUser", vm.toString(i))));
            vm.deal(testUsers[i], 1 ether);

            weth.mint(testUsers[i], INITIAL_BALANCE);
            vm.startPrank(testUsers[i]);
            weth.approve(address(vault), type(uint256).max);

            if (i < 3) {
                // Only first 3 users opt in
                autoWithdrawer.optInToAutomation();

                address[] memory tokens = new address[](1);
                uint256[] memory amounts = new uint256[](1);
                tokens[0] = address(weth);
                amounts[0] = DEPOSIT_AMOUNT;
                vault.depositBasket(tokens, amounts);
            }
            vm.stopPrank();
        }

        assertEq(autoWithdrawer.getTotalUsers(), 3, "Should have 3 opted-in users");

        // Fast forward past emergency delay
        vm.warp(block.timestamp + vault.emergencyWithdrawalDelay() + 1);

        // Check upkeep should find all 3 eligible
        (bool upkeepNeeded, bytes memory performData) = autoWithdrawer.checkUpkeep("");
        assertTrue(upkeepNeeded, "Should need upkeep for opted-in users");

        // Perform upkeep
        autoWithdrawer.performUpkeep(performData);

        // Verify round-robin index was updated
        assertGt(autoWithdrawer.checkStartIndex(), 0, "Start index should be updated");
    }

    /// @notice Test admin emergency withdrawal
    function test_adminEmergencyWithdraw() public {
        // Setup user with position
        vm.startPrank(user1);
        address[] memory tokens = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        tokens[0] = address(weth);
        amounts[0] = DEPOSIT_AMOUNT;

        uint256 initialBalance = weth.balanceOf(user1);
        vault.depositBasket(tokens, amounts);
        vm.stopPrank();

        // Fast forward past emergency delay
        vm.warp(block.timestamp + vault.emergencyWithdrawalDelay() + 1);

        // Admin triggers emergency withdrawal
        vm.startPrank(owner);
        vm.expectEmit(true, false, false, false);
        emit EmergencyWithdrawalTriggered(user1, 0, 1);

        autoWithdrawer.adminEmergencyWithdraw(user1, 0);
        vm.stopPrank();

        // Verify user got tokens back
        uint256 finalBalance = weth.balanceOf(user1);
        assertEq(finalBalance, initialBalance, "User should get all tokens back");
    }

    /// @notice Test automation enabled/disabled
    function test_automationEnabledDisabled() public {
        // Setup user with eligible position
        vm.startPrank(user1);
        autoWithdrawer.optInToAutomation();

        address[] memory tokens = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        tokens[0] = address(weth);
        amounts[0] = DEPOSIT_AMOUNT;
        vault.depositBasket(tokens, amounts);
        vm.stopPrank();

        vm.warp(block.timestamp + vault.emergencyWithdrawalDelay() + 1);

        // Disable automation
        vm.startPrank(owner);
        autoWithdrawer.setAutomationEnabled(false);
        vm.stopPrank();

        // Check upkeep should return false when disabled
        (bool upkeepNeeded,) = autoWithdrawer.checkUpkeep("");
        assertFalse(upkeepNeeded, "Should not need upkeep when disabled");

        // Re-enable automation
        vm.startPrank(owner);
        autoWithdrawer.setAutomationEnabled(true);
        vm.stopPrank();

        // Should work again
        (upkeepNeeded,) = autoWithdrawer.checkUpkeep("");
        assertTrue(upkeepNeeded, "Should need upkeep when re-enabled");
    }

    /// @notice Test getting opted-in users list
    function test_getOptedInUsers() public {
        // Initially no users
        address[] memory optedInUsers = autoWithdrawer.getOptedInUsers();
        assertEq(optedInUsers.length, 0, "Should have no opted-in users initially");

        // User1 and User2 opt in
        vm.startPrank(user1);
        autoWithdrawer.optInToAutomation();
        vm.stopPrank();

        vm.startPrank(user2);
        autoWithdrawer.optInToAutomation();
        vm.stopPrank();

        optedInUsers = autoWithdrawer.getOptedInUsers();
        assertEq(optedInUsers.length, 2, "Should have 2 opted-in users");
        assertTrue(optedInUsers[0] == user1 || optedInUsers[1] == user1, "Should contain user1");
        assertTrue(optedInUsers[0] == user2 || optedInUsers[1] == user2, "Should contain user2");

        // User1 opts out
        vm.startPrank(user1);
        autoWithdrawer.optOutOfAutomation();
        vm.stopPrank();

        optedInUsers = autoWithdrawer.getOptedInUsers();
        assertEq(optedInUsers.length, 1, "Should have 1 opted-in user after opt-out");
        assertEq(optedInUsers[0], user2, "Should only contain user2");
    }

    /// @notice Test error conditions
    function test_errorConditions() public {
        // Test admin emergency withdraw with invalid position
        vm.startPrank(owner);
        vm.expectRevert(AutoEmergencyWithdrawal.InvalidPosition.selector);
        autoWithdrawer.adminEmergencyWithdraw(user1, 0);
        vm.stopPrank();

        // Test perform upkeep when disabled
        vm.startPrank(owner);
        autoWithdrawer.setAutomationEnabled(false);
        vm.stopPrank();

        bytes memory emptyPerformData = abi.encode(new address[](0), new uint256[](0), uint256(0));
        vm.expectRevert(AutoEmergencyWithdrawal.AutomationDisabled.selector);
        autoWithdrawer.performUpkeep(emptyPerformData);
    }
}
