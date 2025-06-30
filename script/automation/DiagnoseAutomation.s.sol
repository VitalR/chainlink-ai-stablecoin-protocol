// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";

import { AutoEmergencyWithdrawal } from "../../src/automation/AutoEmergencyWithdrawal.sol";
import { CollateralVault } from "../../src/CollateralVault.sol";
import { SepoliaConfig } from "config/SepoliaConfig.sol";

/// @title Diagnose Automation Issues
/// @notice Debug script to check why automation isn't triggering
contract DiagnoseAutomationScript is Script {
    address user;
    AutoEmergencyWithdrawal automationContract;
    CollateralVault vault;

    function setUp() public {
        user = vm.envAddress("DEPLOYER_PUBLIC_KEY");
        automationContract = AutoEmergencyWithdrawal(SepoliaConfig.AUTO_EMERGENCY_WITHDRAWAL);
        vault = CollateralVault(payable(SepoliaConfig.COLLATERAL_VAULT));
    }

    function run() external view {
        console.log("=== AUTOMATION DIAGNOSIS ===");
        console.log("User:", user);
        console.log("Current time:", block.timestamp);
        console.log("");

        // Check automation contract status
        _checkAutomationStatus();

        // Check user positions
        _checkUserPositions();

        // Check automation eligibility
        _checkAutomationEligibility();

        // Test checkUpkeep directly
        _testCheckUpkeep();
    }

    function _checkAutomationStatus() internal view {
        console.log("=== AUTOMATION CONTRACT STATUS ===");
        console.log("Contract address:", address(automationContract));
        console.log("Automation enabled:", automationContract.automationEnabled());
        console.log("Vault address:", address(automationContract.vault()));

        (address vaultAddr, bool enabled, uint256 totalUsers, uint256 optedInUsers, uint256 startIndex) =
            automationContract.getAutomationInfo();

        console.log("Total users:", totalUsers);
        console.log("Opted in users:", optedInUsers);
        console.log("Start index:", startIndex);

        bool userOptedIn = automationContract.isUserOptedIn(user);
        console.log("User opted in:", userOptedIn);
        console.log("");
    }

    function _checkUserPositions() internal view {
        console.log("=== USER POSITIONS ===");

        (uint256 totalPositions, uint256 activePositions, uint256 totalValue, uint256 totalMinted) =
            vault.getPositionSummary(user);

        console.log("Total positions:", totalPositions);
        console.log("Active positions:", activePositions);
        console.log("Total value: $", totalValue / 1e18);
        console.log("Total AIUSD minted:", totalMinted);
        console.log("");

        if (totalPositions > 0) {
            console.log("=== INDIVIDUAL POSITIONS ===");
            for (uint256 i = 0; i < totalPositions; i++) {
                try vault.getUserDepositInfo(user, i) returns (CollateralVault.Position memory position) {
                    if (position.timestamp > 0) {
                        console.log("Position", i, ":");
                        console.log("  - Timestamp:", position.timestamp);
                        console.log("  - Current time:", block.timestamp);
                        console.log("  - Age:", block.timestamp - position.timestamp, "seconds");
                        console.log("  - Value: $", position.totalValueUSD / 1e18);
                        console.log("  - AIUSD minted:", position.aiusdMinted);
                        console.log("  - Has pending request:", position.hasPendingRequest);
                        console.log("  - Request ID:", position.requestId);

                        if (position.hasPendingRequest) {
                            uint256 age = block.timestamp - position.timestamp;
                            uint256 emergencyDelay = vault.emergencyWithdrawalDelay();
                            console.log("  - Emergency delay:", emergencyDelay, "seconds");
                            console.log(
                                "  - Time until eligible:", age >= emergencyDelay ? 0 : emergencyDelay - age, "seconds"
                            );
                        }
                        console.log("");
                    }
                } catch {
                    console.log("Position", i, ": [EMPTY]");
                }
            }
        }
    }

    function _checkAutomationEligibility() internal view {
        console.log("=== AUTOMATION ELIGIBILITY ===");

        // Check emergency withdrawal status
        (bool canWithdraw, uint256 timeRemaining) = vault.canEmergencyWithdraw(user);
        console.log("Can emergency withdraw:", canWithdraw);
        console.log("Time remaining:", timeRemaining, "seconds");
        console.log("Time remaining:", timeRemaining / 60, "minutes");

        // Check emergency withdrawable positions
        try vault.getEmergencyWithdrawablePositions(user) returns (
            uint256[] memory indices, uint256[] memory timeRemaining_
        ) {
            console.log("Emergency withdrawable positions:");
            console.log("  - Count:", indices.length);

            for (uint256 i = 0; i < indices.length; i++) {
                console.log("  - Position", indices[i]);
                console.log("    Time remaining:", timeRemaining_[i], "seconds");
            }
        } catch Error(string memory reason) {
            console.log("Error getting withdrawable positions:", reason);
        }
        console.log("");
    }

    function _testCheckUpkeep() internal view {
        console.log("=== TEST CHECKUPKEEP ===");

        try automationContract.checkUpkeep("") returns (bool upkeepNeeded, bytes memory performData) {
            console.log("Upkeep needed:", upkeepNeeded);
            console.log("Perform data length:", performData.length);

            if (upkeepNeeded) {
                console.log("SUCCESS: Automation would trigger!");

                // Decode the perform data to see what would be processed
                try this._decodePerformData(performData) {
                    console.log("Perform data decoded successfully");
                } catch {
                    console.log("Could not decode perform data");
                }
            } else {
                console.log("Automation will NOT trigger");
                console.log("Possible reasons:");
                console.log("- User not opted in");
                console.log("- No positions found");
                console.log("- Positions not yet eligible");
                console.log("- Automation disabled");
            }
        } catch Error(string memory reason) {
            console.log("ERROR in checkUpkeep:", reason);
        }

        console.log("");
    }

    function _decodePerformData(bytes memory performData) external pure {
        (address[] memory users, uint256[] memory positions, uint256 newStartIndex) =
            abi.decode(performData, (address[], uint256[], uint256));

        console.log("Would process", users.length, "users");
        for (uint256 i = 0; i < users.length; i++) {
            console.log("  - User:", users[i], "Position:", positions[i]);
        }
    }
}
