// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import { ICollateralVault } from "../../src/interfaces/ICollateralVault.sol";
import { AutoEmergencyWithdrawal } from "../../src/automation/AutoEmergencyWithdrawal.sol";
import { MockWETH } from "../../test/mocks/MockWETH.sol";

contract FixAndTestAutomationScript is Script {
    // Deployed contract addresses (Sepolia)
    address constant VAULT_ADDRESS = 0x207745583881e274a60D212F35C1F3e09f25f4bE;
    address constant AUTOMATION_ADDRESS = 0xFA4D7bb5EabF853aB213B940666989F3b3D43C8E;
    address constant WETH_ADDRESS = 0xe1cb3cFbf87E27c52192d90A49DB6B331C522846;

    function run() external {
        console.log("=== FIX AND TEST EMERGENCY WITHDRAWAL AUTOMATION ===");
        console.log("=====================================================");

        ICollateralVault vault = ICollateralVault(VAULT_ADDRESS);
        AutoEmergencyWithdrawal automation = AutoEmergencyWithdrawal(AUTOMATION_ADDRESS);
        MockWETH weth = MockWETH(WETH_ADDRESS);

        address user = vm.addr(vm.envUint("DEPLOYER_PRIVATE_KEY"));
        console.log("User:", user);

        // STEP 1: Fix Vault Address Issue
        console.log("\n=== STEP 1: SET VAULT ADDRESS IN AUTOMATION ===");
        vm.startBroadcast();

        // Check current vault address
        address currentVault = address(automation.vault());
        console.log("Current vault address in automation:", currentVault);

        if (currentVault == address(0)) {
            try automation.setVault(VAULT_ADDRESS) {
                console.log("SUCCESS: Set vault address in automation contract");
            } catch Error(string memory reason) {
                console.log("ERROR: Failed to set vault address:", reason);
                console.log("INFO: You might not be the owner, continuing anyway...");
            }
        } else if (currentVault == VAULT_ADDRESS) {
            console.log("INFO: Vault address already set correctly");
        } else {
            console.log("WARNING: Vault address is set to different address:", currentVault);
        }

        vm.stopBroadcast();

        // STEP 2: Check Authorization (Skip since it's already set)
        console.log("\n=== STEP 2: CHECK AUTHORIZATION STATUS ===");
        bool isAuthorized = vault.authorizedAutomation(AUTOMATION_ADDRESS);
        console.log("Automation authorized:", isAuthorized);

        if (!isAuthorized) {
            console.log("ERROR: Automation not authorized! Need to run authorization first");
            return;
        } else {
            console.log("SUCCESS: Automation already authorized");
        }

        // STEP 3: Check if user is opted in to automation
        console.log("\n=== STEP 3: CHECK USER OPT-IN STATUS ===");
        bool isOptedIn = automation.isUserOptedIn(user);
        console.log("User opted in to automation:", isOptedIn);

        if (!isOptedIn) {
            console.log("INFO: User not opted in, opting in now...");
            vm.startBroadcast();
            automation.optInToAutomation();
            console.log("SUCCESS: User opted in to automation");
            vm.stopBroadcast();
        }

        // STEP 4: Check Position Status
        console.log("\n=== STEP 4: CURRENT POSITION STATUS ===");
        (uint256 totalPositions,,,) = vault.getPositionSummary(user);
        console.log("Total positions:", totalPositions);

        if (totalPositions == 0) {
            console.log("No positions found. Creating a new stuck position...");
            this.createStuckPosition(vault, weth, user);
        }

        // Get updated position status
        (bool hasPosition, bool isPending, uint256 requestId, uint256 timeElapsed) = vault.getPositionStatus(user);
        console.log("Has position:", hasPosition);
        console.log("AI pending:", isPending);
        console.log("Request ID:", requestId);
        console.log("Time elapsed:", timeElapsed, "seconds");

        if (!isPending) {
            console.log("ERROR: No pending position found");
            return;
        }

        // STEP 5: Check Emergency Withdrawal Eligibility
        console.log("\n=== STEP 5: EMERGENCY WITHDRAWAL ELIGIBILITY ===");
        (bool canWithdraw, uint256 remainingTime) = vault.canEmergencyWithdraw(user);
        console.log("Can emergency withdraw:", canWithdraw);
        console.log("Time remaining:", remainingTime, "seconds");

        // If not eligible, fast-forward time
        if (!canWithdraw && remainingTime > 0) {
            console.log("INFO: Fast-forwarding time...");
            vm.warp(block.timestamp + remainingTime + 1);
            (canWithdraw, remainingTime) = vault.canEmergencyWithdraw(user);
            console.log("Can emergency withdraw (after warp):", canWithdraw);
        }

        // STEP 6: Test Automation Detection
        console.log("\n=== STEP 6: TEST AUTOMATION DETECTION ===");
        this.testAutomationDetection(automation, canWithdraw);

        // STEP 7: Test Automation Execution
        if (canWithdraw) {
            console.log("\n=== STEP 7: TEST AUTOMATION EXECUTION ===");
            this.testAutomationExecution(automation, vault, weth, user, requestId);
        } else {
            console.log("\n=== STEP 7: WAITING FOR ELIGIBILITY ===");
            console.log("Position not eligible for emergency withdrawal yet");
        }

        console.log("\n=== FINAL STATUS ===");
        (address vaultAddr, bool enabled, uint256 totalUsers, uint256 optedInUsers, uint256 startIndex) =
            automation.getAutomationInfo();
        console.log("Automation vault address:", vaultAddr);
        console.log("Automation enabled:", enabled);
        console.log("Total users:", totalUsers);
        console.log("Opted-in users:", optedInUsers);
        console.log("Current start index:", startIndex);

        console.log("\n=== AUTOMATION TEST COMPLETE ===");
    }

    function createStuckPosition(ICollateralVault vault, MockWETH weth, address user)
        external
        returns (uint256 timestamp)
    {
        console.log("Creating stuck position...");

        vm.startBroadcast();

        // Mint WETH if needed
        uint256 balance = weth.balanceOf(user);
        if (balance < 1e18) {
            weth.mint(user, 2e18);
            console.log("Minted 2 WETH for user");
        }

        // Approve and deposit
        weth.approve(VAULT_ADDRESS, 1e18);

        address[] memory tokens = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        tokens[0] = WETH_ADDRESS;
        amounts[0] = 1e18;

        timestamp = block.timestamp;
        vault.depositBasket(tokens, amounts);
        console.log("SUCCESS: Created deposit position");

        vm.stopBroadcast();
    }

    function testAutomationDetection(AutoEmergencyWithdrawal automation, bool expectedEligible) external view {
        console.log("Testing automation detection...");

        try automation.checkUpkeep("") returns (bool upkeepNeeded, bytes memory performData) {
            console.log("SUCCESS: checkUpkeep succeeded!");
            console.log("Upkeep needed:", upkeepNeeded);
            console.log("Perform data length:", performData.length, "bytes");

            if (upkeepNeeded && expectedEligible) {
                console.log("SUCCESS: Automation correctly detected eligible positions");
            } else if (!upkeepNeeded && !expectedEligible) {
                console.log("SUCCESS: Automation correctly waiting for eligibility");
            } else if (upkeepNeeded && !expectedEligible) {
                console.log("WARNING: Automation detected positions but none should be eligible");
            } else {
                console.log("WARNING: Automation didn't detect eligible positions");
            }
        } catch Error(string memory reason) {
            console.log("ERROR: checkUpkeep failed:", reason);
        } catch {
            console.log("ERROR: checkUpkeep failed with unknown error");
        }
    }

    function testAutomationExecution(
        AutoEmergencyWithdrawal automation,
        ICollateralVault vault,
        MockWETH weth,
        address user,
        uint256 requestId
    ) external {
        console.log("Testing automation execution...");

        // First get the perform data from checkUpkeep
        try automation.checkUpkeep("") returns (bool upkeepNeeded, bytes memory performData) {
            if (!upkeepNeeded) {
                console.log("INFO: No upkeep needed, skipping execution test");
                return;
            }

            console.log("Perform data obtained, testing performUpkeep...");

            uint256 balanceBefore = weth.balanceOf(user);
            console.log("WETH balance before:", balanceBefore / 1e18, "WETH");

            vm.startBroadcast();
            try automation.performUpkeep(performData) {
                console.log("SUCCESS: performUpkeep executed successfully!");

                uint256 balanceAfter = weth.balanceOf(user);
                console.log("WETH balance after:", balanceAfter / 1e18, "WETH");
                console.log("WETH recovered:", (balanceAfter - balanceBefore) / 1e18, "WETH");

                // Check if position is no longer pending
                (bool hasPosition, bool isPending,,) = vault.getPositionStatus(user);
                console.log("Position still has pending AI:", isPending);
            } catch Error(string memory reason) {
                console.log("ERROR: performUpkeep failed:", reason);
            } catch {
                console.log("ERROR: performUpkeep failed with unknown error");
            }
            vm.stopBroadcast();
        } catch {
            console.log("ERROR: Could not get perform data for execution test");
        }
    }
}
