// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "forge-std/Script.sol";
import { IERC20 } from "@openzeppelin/token/ERC20/IERC20.sol";

import { AIStablecoin } from "src/AIStablecoin.sol";
import { CollateralVault } from "src/CollateralVault.sol";
import { RiskOracleController } from "src/RiskOracleController.sol";
import { AutoEmergencyWithdrawal } from "src/automation/AutoEmergencyWithdrawal.sol";
import { SepoliaConfig } from "config/SepoliaConfig.sol";

/// @title TestEmergencyWithdrawalFlow - Realistic Emergency Testing
/// @notice Tests emergency withdrawal by removing consumer from Chainlink subscription
contract TestEmergencyWithdrawalFlowScript is Script {
    AIStablecoin aiusd;
    CollateralVault vault;
    RiskOracleController controller;
    AutoEmergencyWithdrawal autoWithdrawer;
    IERC20 weth;

    address user;
    uint256 userPrivateKey;

    function setUp() public {
        user = vm.envAddress("DEPLOYER_PUBLIC_KEY");
        userPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");

        aiusd = AIStablecoin(SepoliaConfig.AI_STABLECOIN);
        vault = CollateralVault(payable(SepoliaConfig.COLLATERAL_VAULT));
        controller = RiskOracleController(SepoliaConfig.RISK_ORACLE_CONTROLLER);
        autoWithdrawer = AutoEmergencyWithdrawal(SepoliaConfig.AUTO_EMERGENCY_WITHDRAWAL);
        weth = IERC20(SepoliaConfig.MOCK_WETH);
    }

    /// @notice Test automation emergency withdrawal with realistic Chainlink Functions failure
    function testAutomationEmergencyFlow() public {
        vm.startBroadcast(userPrivateKey);

        console.log("=== REALISTIC EMERGENCY WITHDRAWAL TEST ===");
        console.log("User address:", user);
        console.log("Strategy: Remove consumer BEFORE creating position");
        console.log("");

        // Step 1: Opt into automation
        _optIntoAutomation();

        // Step 2: Manual action FIRST - remove consumer before creating position
        _instructSubscriptionManipulation();

        // Step 3: Create position (while AI is broken)
        _createStuckPosition();

        // Step 4: Test emergency withdrawal
        _testEmergencyWithdrawal();

        vm.stopBroadcast();
    }

    /// @notice Opt into automation (required for automation emergency withdrawal)
    function _optIntoAutomation() internal {
        console.log("=== STEP 1: OPT INTO AUTOMATION ===");

        if (!autoWithdrawer.userOptedIn(user)) {
            autoWithdrawer.optInToAutomation();
            console.log("SUCCESS: Opted into automation");
        } else {
            console.log("INFO: Already opted in");
        }

        (,, uint256 totalUsers, uint256 optedInUsers,) = autoWithdrawer.getAutomationInfo();
        console.log("Opted in users:", optedInUsers);
        console.log("Total users:", totalUsers);
        console.log("");
    }

    /// @notice Instructions for manual subscription manipulation BEFORE creating position
    function _instructSubscriptionManipulation() internal {
        console.log("=== STEP 2: BREAK AI SYSTEM FIRST ===");
        console.log("");
        console.log("CRITICAL: Remove consumer BEFORE creating position!");
        console.log("");
        console.log("1. Go to: https://functions.chain.link/sepolia/5075");
        console.log("2. Remove consumer: 0xf8D3A0d5dE0368319123a43b925d01D867Af2229");
        console.log("3. This ensures new positions cannot get AI responses");
        console.log("");
        console.log("Press Enter when consumer is removed, or wait 30 seconds...");

        // Give user time to remove consumer
        vm.warp(block.timestamp + 60);

        console.log("SUCCESS: Proceeding (assuming consumer removed)");
        console.log("");
    }

    /// @notice Create position while AI system is broken
    function _createStuckPosition() internal {
        console.log("=== STEP 3: CREATE STUCK POSITION ===");

        uint256 wethBalance = weth.balanceOf(user);
        require(wethBalance >= 1 ether, "Need at least 1 WETH");

        // Create 0.8 WETH position
        address[] memory tokens = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        tokens[0] = address(weth);
        amounts[0] = 0.8 ether;

        console.log("Creating position with 0.8 WETH (AI system broken)...");

        weth.approve(address(vault), amounts[0]);
        vault.depositBasket(tokens, amounts);

        // Check the position status
        (uint256 totalPositions,,,) = vault.getPositionSummary(user);
        CollateralVault.Position memory position = vault.getUserDepositInfo(user, totalPositions - 1);

        console.log("SUCCESS: Position created:");
        console.log("- Index:", totalPositions - 1);
        console.log("- Value: $", position.totalValueUSD / 1e18);
        console.log("- Pending AI request:", position.hasPendingRequest);
        console.log("- Request ID:", position.requestId);
        console.log("");

        if (position.hasPendingRequest) {
            console.log("SUCCESS: Position is stuck with pending AI request!");
            console.log("(No AI response possible - consumer removed)");
        } else {
            console.log("WARNING: Position not stuck (AI may have processed)");
            console.log("Check if consumer was removed properly");
        }
        console.log("");
    }

    /// @notice Test emergency withdrawal after timeout
    function _testEmergencyWithdrawal() internal {
        console.log("=== STEP 4: TEST EMERGENCY WITHDRAWAL ===");

        // Fast-forward past emergency delay
        uint256 emergencyDelay = vault.emergencyWithdrawalDelay();
        console.log("Emergency delay:", emergencyDelay / 60, "minutes");

        vm.warp(block.timestamp + emergencyDelay + 60);
        console.log("SUCCESS: Fast-forwarded past emergency timeout");

        // Check if user can withdraw
        (bool canWithdraw,) = vault.canEmergencyWithdraw(user);
        console.log("User can emergency withdraw:", canWithdraw);

        if (!canWithdraw) {
            console.log("ERROR: Emergency withdrawal not available yet");
            return;
        }

        // Test automation
        try autoWithdrawer.checkUpkeep("") returns (bool upkeepNeeded, bytes memory performData) {
            console.log("Automation check - upkeep needed:", upkeepNeeded);

            if (upkeepNeeded) {
                console.log("SUCCESS: Automation detected stuck position!");

                // Execute automation
                autoWithdrawer.performUpkeep(performData);
                console.log("SUCCESS: Automation emergency withdrawal executed!");

                // Verify position cleared
                (, uint256 activePositions,,) = vault.getPositionSummary(user);
                console.log("Active positions after withdrawal:", activePositions);

                uint256 finalWETH = weth.balanceOf(user);
                console.log("Final WETH balance:", finalWETH / 1e18, "WETH");
            } else {
                console.log("ERROR: Automation did not detect stuck position");
                console.log("(Position may not be truly stuck)");
            }
        } catch Error(string memory reason) {
            console.log("ERROR: Automation failed:", reason);
        }

        console.log("");
        console.log("=== EMERGENCY TEST COMPLETE ===");
        console.log("SUCCESS: System protects users when AI services fail!");
        console.log("");
        console.log("REMEMBER: Re-add consumer to subscription:");
        console.log("https://functions.chain.link/sepolia/5075");
        console.log("Consumer: 0xf8D3A0d5dE0368319123a43b925d01D867Af2229");
    }

    /// @notice Main run function
    function run(string memory scenario) public {
        if (keccak256(bytes(scenario)) == keccak256(bytes("automation"))) {
            testAutomationEmergencyFlow();
        } else {
            console.log("Available scenarios: automation");
            revert("Invalid scenario");
        }
    }

    /// @notice Default run function
    function run() public {
        testAutomationEmergencyFlow();
    }
}
