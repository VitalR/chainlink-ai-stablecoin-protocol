// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { CollateralVault } from "../../src/CollateralVault.sol";
import { SepoliaConfig } from "../config/SepoliaConfig.sol";

/// @title UpdateEmergencyDelay
/// @notice Script to update the emergency withdrawal delay in the CollateralVault
contract UpdateEmergencyDelayScript is Script, SepoliaConfig {
    function run() external {
        vm.startBroadcast();

        CollateralVault vault = CollateralVault(COLLATERAL_VAULT);

        console.log("=== Emergency Withdrawal Delay Configuration ===");
        console.log("Vault address:", address(vault));

        // Show current delay
        uint256 currentDelay = vault.emergencyWithdrawalDelay();
        console.log("Current delay:", currentDelay, "seconds");
        console.log("Current delay (hours):", currentDelay / 3600);

        // Get new delay from environment variable or use default
        uint256 newDelay;
        try vm.envUint("NEW_EMERGENCY_DELAY") returns (uint256 envDelay) {
            newDelay = envDelay;
        } catch {
            newDelay = 3600; // Default 1 hour
        }

        console.log("Updating to new delay:", newDelay, "seconds");
        console.log("New delay (hours):", newDelay / 3600);
        console.log("New delay (minutes):", newDelay / 60);

        // Update the delay
        vault.updateEmergencyWithdrawalDelay(newDelay);

        console.log("Emergency withdrawal delay updated successfully!");

        // Verify the update
        uint256 updatedDelay = vault.emergencyWithdrawalDelay();
        console.log("Verified new delay:", updatedDelay, "seconds");

        vm.stopBroadcast();
    }
}
