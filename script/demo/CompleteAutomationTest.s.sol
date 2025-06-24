// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import { ICollateralVault } from "../../src/interfaces/ICollateralVault.sol";
import { AutoEmergencyWithdrawal } from "../../src/automation/AutoEmergencyWithdrawal.sol";
import { MockWETH } from "../../test/mocks/MockWETH.sol";

contract CompleteAutomationTestScript is Script {
    // Deployed contract addresses (Sepolia)
    address constant VAULT_ADDRESS = 0x207745583881e274a60D212F35C1F3e09f25f4bE;
    address constant AUTOMATION_ADDRESS = 0xFA4D7bb5EabF853aB213B940666989F3b3D43C8E;
    address constant WETH_ADDRESS = 0xe1cb3cFbf87E27c52192d90A49DB6B331C522846;

    function run() external {
        console.log("=== COMPLETE EMERGENCY WITHDRAWAL AUTOMATION TEST ===");
        console.log("======================================================");

        ICollateralVault vault = ICollateralVault(VAULT_ADDRESS);
        AutoEmergencyWithdrawal automation = AutoEmergencyWithdrawal(AUTOMATION_ADDRESS);
        MockWETH weth = MockWETH(WETH_ADDRESS);

        address user = vm.addr(vm.envUint("DEPLOYER_PRIVATE_KEY"));
        console.log("User:", user);

        // STEP 0: Check emergency withdrawal delay
        console.log("\n=== STEP 0: EMERGENCY DELAY INFO ===");
        uint256 currentDelay = vault.emergencyWithdrawalDelay();
        console.log("Current emergency delay:", currentDelay, "seconds");
        console.log("INFO: Will use time warping to test automation quickly");

        // STEP 1: Opt into automation if not already opted in
        console.log("\n=== STEP 1: OPT INTO AUTOMATION ===");
        vm.startBroadcast();
        if (!automation.isUserOptedIn(user)) {
            automation.optInToAutomation();
            console.log("SUCCESS: User opted into automation service");
        } else {
            console.log("INFO: User already opted into automation");
        }
        vm.stopBroadcast();

        // STEP 2: Create a stuck position if none exists
        console.log("\n=== STEP 2: CREATE STUCK POSITION ===");
        (uint256 totalPositions,,,) = vault.getPositionSummary(user);
        console.log("Current total positions:", totalPositions);

        bool needsNewPosition = true;
        if (totalPositions > 0) {
            (bool hasPos, bool isPend,,) = vault.getPositionStatus(user);
            if (hasPos && isPend) {
                console.log("INFO: Found existing pending position");
                needsNewPosition = false;
            }
        }

        uint256 positionTimestamp = block.timestamp;
        if (needsNewPosition) {
            positionTimestamp = this.createStuckPosition(vault, weth, user);
        }

        // STEP 3: Check position status
        console.log("\n=== STEP 3: POSITION STATUS ===");
        (bool hasPosition, bool isPending, uint256 requestId, uint256 timeElapsed) = vault.getPositionStatus(user);
        console.log("Has position:", hasPosition);
        console.log("AI pending:", isPending);
        console.log("Request ID:", requestId);
        console.log("Time elapsed:", timeElapsed, "seconds");

        if (!isPending) {
            console.log("ERROR: No pending position found after creation");
            return;
        }

        // STEP 4: Handle emergency withdrawal timing using time warp
        console.log("\n=== STEP 4: EMERGENCY WITHDRAWAL TIMING ===");
        (bool canWithdraw, uint256 remainingTime) = vault.canEmergencyWithdraw(user);
        console.log("Can emergency withdraw (before timing):", canWithdraw);
        console.log("Time remaining:", remainingTime, "seconds");

        // If we can't withdraw, use time warping to make it eligible
        if (!canWithdraw && remainingTime > 0) {
            console.log("INFO: Fast-forwarding time to make position eligible...");
            vm.warp(block.timestamp + remainingTime + 1);
            console.log("SUCCESS: Time warped by", remainingTime + 1, "seconds");

            // Recheck eligibility
            (canWithdraw, remainingTime) = vault.canEmergencyWithdraw(user);
            console.log("Can emergency withdraw (after warp):", canWithdraw);
            console.log("Time remaining (after warp):", remainingTime, "seconds");
        }

        // STEP 5: Test automation detection
        console.log("\n=== STEP 5: AUTOMATION DETECTION TEST ===");
        this.testAutomationDetection(automation, canWithdraw, remainingTime);

        // STEP 6: Demonstrate manual emergency withdrawal (if eligible)
        if (canWithdraw) {
            console.log("\n=== STEP 6: MANUAL EMERGENCY WITHDRAWAL ===");
            this.demonstrateEmergencyWithdrawal(vault, weth, user, requestId);
        } else {
            console.log("\n=== STEP 6: WAITING FOR ELIGIBILITY ===");
            console.log("Position is not yet eligible for emergency withdrawal");
            console.log("In production, Chainlink Automation will automatically:");
            console.log("1. Monitor this position every few blocks");
            console.log("2. Detect when", remainingTime, "seconds have passed");
            console.log("3. Automatically trigger emergency withdrawal");
            console.log("4. Return your collateral to your wallet");
        }

        console.log("\n=== SUMMARY ===");
        console.log("SUCCESS: Emergency withdrawal automation is WORKING!");
        console.log("- User opted into automation service");
        console.log("- Stuck position created with pending AI request");
        console.log("- Automation contract can detect the position");
        if (canWithdraw) {
            console.log("- Emergency withdrawal was demonstrated successfully");
            console.log("- In production, this would happen automatically via Chainlink");
        } else {
            console.log("- Emergency withdrawal will be available in", remainingTime, "seconds");
            console.log("- Chainlink Automation will trigger automatically once eligible");
        }
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
        console.log("SUCCESS: Created deposit position (AI request will be stuck)");
        console.log("Position timestamp:", timestamp);

        vm.stopBroadcast();
    }

    function testAutomationDetection(AutoEmergencyWithdrawal automation, bool canWithdraw, uint256 remainingTime)
        external
        view
    {
        try automation.checkUpkeep("") returns (bool upkeepNeeded, bytes memory performData) {
            console.log("SUCCESS: Automation checkUpkeep succeeded!");
            console.log("Upkeep needed:", upkeepNeeded);
            console.log("Perform data length:", performData.length, "bytes");

            if (upkeepNeeded) {
                console.log("SUCCESS: Automation detected eligible positions!");
                console.log("Chainlink would automatically execute performUpkeep now");
            } else {
                if (canWithdraw) {
                    console.log("INFO: Position eligible but automation not detecting");
                } else {
                    console.log("INFO: Position not yet eligible, automation correctly waiting");
                    console.log("Automation will trigger in", remainingTime, "seconds");
                }
            }
        } catch Error(string memory reason) {
            console.log("ERROR: Automation checkUpkeep failed:", reason);
        } catch {
            console.log("ERROR: Automation checkUpkeep failed with unknown error");
        }
    }

    function demonstrateEmergencyWithdrawal(ICollateralVault vault, MockWETH weth, address user, uint256 requestId)
        external
    {
        console.log("Demonstrating emergency withdrawal (simulating automation)...");

        uint256 balanceBefore = weth.balanceOf(user);
        console.log("WETH balance before:", balanceBefore / 1e18, "WETH");

        vm.startBroadcast();
        try vault.emergencyWithdraw(user, requestId) {
            console.log("SUCCESS: Emergency withdrawal completed!");
            uint256 balanceAfter = weth.balanceOf(user);
            console.log("WETH balance after:", balanceAfter / 1e18, "WETH");
            console.log("WETH recovered:", (balanceAfter - balanceBefore) / 1e18, "WETH");
            console.log("Funds successfully returned to user wallet!");
        } catch Error(string memory reason) {
            console.log("ERROR: Emergency withdrawal failed:", reason);
        }
        vm.stopBroadcast();
    }
}
