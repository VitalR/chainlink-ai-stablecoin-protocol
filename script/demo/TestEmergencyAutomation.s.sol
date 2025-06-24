// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import { ICollateralVault } from "../../src/interfaces/ICollateralVault.sol";
import { AutoEmergencyWithdrawal } from "../../src/automation/AutoEmergencyWithdrawal.sol";
import { MockWETH } from "../../test/mocks/MockWETH.sol";

contract TestEmergencyAutomationScript is Script {
    // Deployed contract addresses (Sepolia)
    address constant VAULT_ADDRESS = 0x207745583881e274a60D212F35C1F3e09f25f4bE;
    address constant AUTOMATION_ADDRESS = 0xFA4D7bb5EabF853aB213B940666989F3b3D43C8E;
    address constant WETH_ADDRESS = 0xe1cb3cFbf87E27c52192d90A49DB6B331C522846;

    function run() external {
        console.log("=== EMERGENCY WITHDRAWAL AUTOMATION TEST ===");
        console.log("=============================================");

        ICollateralVault vault = ICollateralVault(VAULT_ADDRESS);
        AutoEmergencyWithdrawal automation = AutoEmergencyWithdrawal(AUTOMATION_ADDRESS);

        // Get deployer address from private key
        address user = vm.addr(vm.envUint("DEPLOYER_PRIVATE_KEY"));

        console.log("User:", user);
        console.log("- User opted in:", automation.isUserOptedIn(user));
        console.log("- Automation enabled:", automation.automationEnabled());

        // Check positions
        (uint256 totalPositions,,,) = vault.getPositionSummary(user);
        console.log("Total positions:", totalPositions);

        if (totalPositions == 0) {
            console.log("No positions found. Run HackathonAutomationDemo to create one.");
            return;
        }

        // Check current position status
        (bool hasPosition, bool isPending, uint256 requestId, uint256 timeElapsed) = vault.getPositionStatus(user);
        console.log("Has position:", hasPosition);
        console.log("AI pending:", isPending);
        console.log("Request ID:", requestId);
        console.log("Time elapsed:", timeElapsed, "seconds");

        if (!isPending) {
            console.log("No pending AI request found.");
            return;
        }

        // Check emergency withdrawal eligibility
        (bool canWithdraw, uint256 remainingTime) = vault.canEmergencyWithdraw(user);
        console.log("Can emergency withdraw:", canWithdraw);
        console.log("Time remaining:", remainingTime, "seconds");

        // Test automation
        this.testAutomation(automation, remainingTime);

        // Test manual withdrawal if eligible
        if (canWithdraw) {
            this.testManualWithdrawal(vault, MockWETH(WETH_ADDRESS), user, requestId);
        } else {
            console.log("Position not yet eligible for emergency withdrawal");
        }
    }

    function testAutomation(AutoEmergencyWithdrawal automation, uint256 remainingTime) external view {
        console.log("\nTesting Automation Detection:");
        try automation.checkUpkeep("") returns (bool upkeepNeeded, bytes memory performData) {
            console.log("SUCCESS: checkUpkeep succeeded!");
            console.log("Upkeep needed:", upkeepNeeded);
            console.log("Perform data length:", performData.length);

            if (!upkeepNeeded) {
                console.log("WAIT:", remainingTime, "more seconds for eligibility");
            }
        } catch Error(string memory reason) {
            console.log("ERROR: checkUpkeep failed:", reason);
        } catch {
            console.log("ERROR: checkUpkeep failed with unknown error");
        }
    }

    function testManualWithdrawal(ICollateralVault vault, MockWETH weth, address user, uint256 requestId) external {
        console.log("\nTesting Manual Emergency Withdrawal:");

        uint256 balanceBefore = weth.balanceOf(user);
        console.log("WETH balance before:", balanceBefore / 1e18);

        vm.startBroadcast();
        try vault.emergencyWithdraw(user, requestId) {
            console.log("SUCCESS: Emergency withdrawal completed!");
            uint256 balanceAfter = weth.balanceOf(user);
            console.log("WETH balance after:", balanceAfter / 1e18);
            console.log("WETH recovered:", (balanceAfter - balanceBefore) / 1e18);
        } catch Error(string memory reason) {
            console.log("ERROR: Emergency withdrawal failed:", reason);
        }
        vm.stopBroadcast();
    }
}
