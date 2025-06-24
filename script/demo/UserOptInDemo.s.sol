// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { AutoEmergencyWithdrawal } from "../../src/automation/AutoEmergencyWithdrawal.sol";
import { CollateralVault } from "../../src/CollateralVault.sol";
import { MockWETH } from "../../test/mocks/MockWETH.sol";
import { SepoliaConfig } from "../../config/SepoliaConfig.sol";

/// @title User Opt-in Demo Script
/// @notice Shows complete user journey for opting into automation
/// @dev Demonstrates the user experience from opt-in to automated recovery
contract UserOptInDemoScript is Script {
    address user = vm.envAddress("DEPLOYER_PUBLIC_KEY");
    uint256 userPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");

    // Assume automation contract is already deployed
    AutoEmergencyWithdrawal automationContract;
    CollateralVault vault;
    MockWETH weth;

    function setUp() public {
        // Load deployed contracts
        vault = CollateralVault(payable(SepoliaConfig.COLLATERAL_VAULT));
        weth = MockWETH(SepoliaConfig.MOCK_WETH);

        // You would replace this with the actual deployed automation contract address
        // automationContract = AutoEmergencyWithdrawal(DEPLOYED_AUTOMATION_ADDRESS);
    }

    /// @notice Demo: How user opts into automation
    function runUserOptInDemo() external {
        console.log("USER OPT-IN AUTOMATION DEMO");
        console.log("============================");

        vm.startBroadcast(userPrivateKey);

        console.log("\nSTEP 1: Check Current Status");
        console.log("-----------------------------");

        // Check initial opt-in status
        bool isInitiallyOptedIn = automationContract.isUserOptedIn(user);
        uint256 initialTotalUsers = automationContract.getTotalUsers();

        console.log("Before opt-in:");
        console.log("   - User opted in:", isInitiallyOptedIn);
        console.log("   - Total users:", initialTotalUsers);

        console.log("\nSTEP 2: User Opts Into Automation");
        console.log("---------------------------------");

        // User opts into automation service
        automationContract.optInToAutomation();
        console.log("User successfully opted into automation service");

        console.log("\nSTEP 3: Verify Opt-in Status");
        console.log("----------------------------");

        // Check opt-in status after
        bool isOptedIn = automationContract.isUserOptedIn(user);
        uint256 totalUsers = automationContract.getTotalUsers();

        console.log("After opt-in:");
        console.log("   - User opted in:", isOptedIn);
        console.log("   - Total users:", totalUsers);
        console.log("   - Automation enabled:", automationContract.automationEnabled());

        // Show all opted-in users
        address[] memory optedInUsers = automationContract.getOptedInUsers();
        console.log("   - All opted-in users:");
        for (uint256 i = 0; i < optedInUsers.length; i++) {
            console.log("     ", optedInUsers[i]);
        }

        console.log("\nSTEP 4: Test Opt-out (Optional)");
        console.log("-------------------------------");

        // Demonstrate opt-out functionality
        automationContract.optOutOfAutomation();
        console.log("User opted out of automation service");

        // Check final status
        bool isFinallyOptedIn = automationContract.isUserOptedIn(user);
        uint256 finalTotalUsers = automationContract.getTotalUsers();

        console.log("After opt-out:");
        console.log("   - User opted in:", isFinallyOptedIn);
        console.log("   - Total users:", finalTotalUsers);

        console.log("\nOPT-IN DEMO COMPLETE!");
        console.log("User has full control over automation participation");

        vm.stopBroadcast();
    }

    /// @notice Demo: How user opts out of automation
    function demonstrateUserOptOut() external {
        console.log("\nUSER OPT-OUT DEMO");
        console.log("==================");

        vm.startBroadcast(userPrivateKey);

        // First opt in
        automationContract.optInToAutomation();
        console.log("User opted into automation service");

        // Then opt out
        automationContract.optOutOfAutomation();
        console.log("User successfully opted out of automation");
        console.log("User can still use manual emergency withdrawals");

        // Check final status
        bool isOptedIn = automationContract.isUserOptedIn(user);
        console.log("Final opt-in status:", isOptedIn);

        vm.stopBroadcast();
    }

    /// @notice Demo: View functions available to users
    function demonstrateViewFunctions() external view {
        console.log("\nUSER VIEW FUNCTIONS");
        console.log("===================");

        // Check if user is opted in
        bool isOptedIn = automationContract.isUserOptedIn(user);
        console.log("Is user opted in:", isOptedIn);

        // Get total users
        uint256 totalUsers = automationContract.getTotalUsers();
        console.log("Total users in system:", totalUsers);

        // Check if automation is enabled
        bool automationEnabled = automationContract.automationEnabled();
        console.log("Automation enabled:", automationEnabled);

        // Get all opted-in users (if any)
        address[] memory users = automationContract.getOptedInUsers();
        console.log("Number of opted-in users:", users.length);
    }

    /// @notice Complete workflow demonstration
    function demonstrateCompleteWorkflow() external {
        console.log("\nCOMPLETE USER WORKFLOW DEMO");
        console.log("============================");

        vm.startBroadcast(userPrivateKey);

        // Step 1: User opts in
        automationContract.optInToAutomation();
        console.log("Opted in successfully");

        // Step 2: User creates deposit (would get stuck in real scenario)
        address[] memory tokens = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        tokens[0] = address(weth);
        amounts[0] = 1 ether;

        console.log("User creates deposit that gets stuck (AI fails)...");
        console.log("Automation monitors this situation 24/7");

        // Step 3: After 4+ hours, automation would trigger
        console.log("After 4+ hours:");
        console.log("Chainlink calls checkUpkeep() -> returns true");
        console.log("Chainlink calls performUpkeep() -> executes withdrawal");
        console.log("User gets all collateral back automatically!");

        vm.stopBroadcast();

        console.log("\nWORKFLOW COMPLETE!");
        console.log("Users are protected 24/7 without manual intervention");
    }
}
