// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";

import { AutoEmergencyWithdrawal } from "../../src/automation/AutoEmergencyWithdrawal.sol";
import { SepoliaConfig } from "config/SepoliaConfig.sol";

/// @title Opt Into Automation
/// @notice Simple script to opt user into automation
contract OptIntoAutomationScript is Script {
    address user;
    uint256 userPrivateKey;
    AutoEmergencyWithdrawal automationContract;

    function setUp() public {
        user = vm.envAddress("DEPLOYER_PUBLIC_KEY");
        userPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        automationContract = AutoEmergencyWithdrawal(SepoliaConfig.AUTO_EMERGENCY_WITHDRAWAL);
    }

    function run() external {
        vm.startBroadcast(userPrivateKey);

        console.log("=== OPT INTO AUTOMATION ===");
        console.log("User:", user);
        console.log("Automation contract:", address(automationContract));

        // Check current status
        bool alreadyOptedIn = automationContract.isUserOptedIn(user);
        console.log("Already opted in:", alreadyOptedIn);

        if (alreadyOptedIn) {
            console.log("SUCCESS: User already opted into automation!");
        } else {
            // Opt into automation
            automationContract.optInToAutomation();
            console.log("SUCCESS: User opted into automation!");
        }

        // Show final status
        (,, uint256 totalUsers, uint256 optedInUsers,) = automationContract.getAutomationInfo();
        console.log("Total users:", totalUsers);
        console.log("Opted in users:", optedInUsers);

        vm.stopBroadcast();
    }
}
