// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";

import { AutoEmergencyWithdrawal } from "../../src/automation/AutoEmergencyWithdrawal.sol";
import { CollateralVault } from "../../src/CollateralVault.sol";
import { MockWETH } from "../../test/mocks/MockWETH.sol";
import { SepoliaConfig } from "../../config/SepoliaConfig.sol";

/// @title Hackathon Automation Demo Script
/// @notice Complete demo showing Chainlink Automation emergency withdrawal functionality
/// @dev Uses ALREADY DEPLOYED automation contract - ready for real Chainlink registration!
contract HackathonAutomationDemoScript is Script {
    address user = vm.envAddress("DEPLOYER_PUBLIC_KEY");
    uint256 userPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");

    // Contracts
    AutoEmergencyWithdrawal automationContract;
    CollateralVault vault;
    MockWETH weth;

    function setUp() public {
        // Load deployed contracts
        vault = CollateralVault(payable(SepoliaConfig.COLLATERAL_VAULT));
        weth = MockWETH(SepoliaConfig.MOCK_WETH);

        // IMPORTANT: Use already deployed automation contract
        // This contract should already be authorized in the vault!
        automationContract = AutoEmergencyWithdrawal(SepoliaConfig.AUTO_EMERGENCY_WITHDRAWAL);
    }

    /// @notice Full hackathon demo with REAL Chainlink Automation
    function runFullDemo() external {
        console.log("CHAINLINK AUTOMATION HACKATHON DEMO");
        console.log("===================================");
        console.log("Using DEPLOYED automation contract: SUCCESS!");
        console.log("Automation Address:", address(automationContract));
        console.log("");

        // Verify deployment status
        verifyDeploymentStatus();

        // Step 1: Setup user for demo
        setupUserForDemo();

        // Step 2: Create a stuck position scenario
        createStuckPosition();

        // Step 3: Show automation monitoring
        demonstrateAutomation();

        // Step 4: Show registration instructions
        showRegistrationInstructions();

        console.log("\nDEMO COMPLETE! Ready for hackathon presentation");
    }

    /// @notice Verify that contracts are properly deployed and configured
    function verifyDeploymentStatus() public view {
        console.log("VERIFICATION: Checking Deployment Status");
        console.log("----------------------------------------");

        require(address(automationContract) != address(0), "Automation contract not deployed");
        require(address(vault) != address(0), "Vault not deployed");
        require(address(weth) != address(0), "WETH not deployed");

        console.log("AutoEmergencyWithdrawal:", address(automationContract));
        console.log("CollateralVault:", address(vault));
        console.log("MockWETH:", address(weth));
        console.log("Max positions per upkeep:", automationContract.MAX_POSITIONS_PER_UPKEEP());
        console.log("Automation enabled:", automationContract.automationEnabled());

        // Check authorization
        bool isAuthorized = vault.authorizedAutomation(address(automationContract));
        console.log("Vault authorization:", isAuthorized ? "AUTHORIZED" : "NOT AUTHORIZED");

        if (!isAuthorized) {
            console.log("WARNING: Run deployment script first to authorize automation!");
        }
    }

    /// @notice Deploy the automation contract - DEPRECATED, use deployed version!
    function deployAutomationContract() public {
        console.log("DEPRECATED: This demo uses DEPLOYED contracts!");
        console.log("Use: forge script script/deploy/06_DeployAutomation.s.sol --broadcast");
        revert("Use deployed contract instead of deploying new one");
    }

    /// @notice Setup user for the demo
    function setupUserForDemo() public {
        vm.startBroadcast(userPrivateKey);

        console.log("\nSTEP 1: Setting Up User for Demo");
        console.log("---------------------------------");

        // Opt into automation
        automationContract.optInToAutomation();
        console.log("User opted into automation service");

        // Check opt-in status
        bool isOptedIn = automationContract.isUserOptedIn(user);
        uint256 totalUsers = automationContract.getTotalUsers();

        console.log("Automation Status:");
        console.log("   - User opted in:", isOptedIn);
        console.log("   - Total users:", totalUsers);
        console.log("   - Automation enabled:", automationContract.automationEnabled());

        vm.stopBroadcast();
    }

    /// @notice Create a stuck position for demonstration
    function createStuckPosition() public {
        vm.startBroadcast(userPrivateKey);

        console.log("\nSTEP 2: Creating Stuck Position Scenario");
        console.log("----------------------------------------");

        // Mint some WETH for the demo
        uint256 depositAmount = 1 ether;
        weth.mint(user, depositAmount);
        weth.approve(address(vault), depositAmount);

        console.log("Minted", depositAmount / 1e18, "WETH for user");

        // Create deposit that will get stuck
        address[] memory tokens = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        tokens[0] = address(weth);
        amounts[0] = depositAmount;

        uint256 initialBalance = weth.balanceOf(user);
        vault.depositBasket(tokens, amounts);

        console.log("Created deposit position");
        console.log("   - Token: WETH");
        console.log("   - Amount:", depositAmount / 1e18, "WETH");
        console.log("   - User balance before:", initialBalance / 1e18, "WETH");
        console.log("   - User balance after:", weth.balanceOf(user) / 1e18, "WETH");

        // Show position status
        (bool hasPosition, bool isPending, uint256 requestId, uint256 timeElapsed) = vault.getPositionStatus(user);

        console.log("Position Status:");
        console.log("   - Has position:", hasPosition);
        console.log("   - AI pending:", isPending);
        console.log("   - Request ID:", requestId);
        console.log("   - Time elapsed:", timeElapsed, "seconds");

        vm.stopBroadcast();
    }

    /// @notice Demonstrate automation monitoring and execution
    function demonstrateAutomation() public {
        console.log("\nSTEP 3: Chainlink Automation Monitoring");
        console.log("---------------------------------------");

        // Check current eligibility
        (bool canWithdrawNow, uint256 timeRemaining) = vault.canEmergencyWithdraw(user);

        console.log("Emergency Withdrawal Status:");
        console.log("   - Can withdraw now:", canWithdrawNow);
        console.log("   - Time remaining:", timeRemaining, "seconds");
        console.log("   - Delay period:", vault.emergencyWithdrawalDelay(), "seconds (4 hours)");

        // Test checkUpkeep (what Chainlink Automation calls)
        (bool upkeepNeeded, bytes memory performData) = automationContract.checkUpkeep("");

        console.log("\nChainlink Automation Check:");
        console.log("   - Upkeep needed:", upkeepNeeded);
        console.log("   - Perform data length:", performData.length);

        if (!upkeepNeeded) {
            console.log("Position not yet ready for emergency withdrawal");
            console.log("Automation will trigger automatically when ready");

            // Fast forward time to show automation would work
            console.log("\nFAST FORWARD SIMULATION (4+ hours later):");
            vm.warp(block.timestamp + vault.emergencyWithdrawalDelay() + 1);

            (bool futureUpkeepNeeded, bytes memory futurePerformData) = automationContract.checkUpkeep("");
            console.log("   - Future upkeep needed:", futureUpkeepNeeded);
            console.log("   - Future perform data length:", futurePerformData.length);

            if (futureUpkeepNeeded) {
                console.log("Automation would trigger emergency withdrawal!");

                // Show what would happen
                uint256 balanceBefore = weth.balanceOf(user);

                vm.startBroadcast(userPrivateKey);
                automationContract.performUpkeep(futurePerformData);
                vm.stopBroadcast();

                uint256 balanceAfter = weth.balanceOf(user);
                console.log("Emergency withdrawal executed automatically!");
                console.log("   - Tokens recovered:", (balanceAfter - balanceBefore) / 1e18, "WETH");
            }
        }

        // Show final status
        console.log("\nFINAL DEMO STATUS:");
        console.log("   - Total users opted in:", automationContract.getTotalUsers());
        console.log("   - User WETH balance:", weth.balanceOf(user) / 1e18, "WETH");
        console.log("   - Automation enabled:", automationContract.automationEnabled());
    }

    /// @notice Show registration instructions for hackathon judges
    function showRegistrationInstructions() public view {
        console.log("\nHACKATHON JUDGES: How to Test This");
        console.log("==================================");
        console.log("1. Visit: https://automation.chain.link/sepolia");
        console.log("2. Connect wallet with LINK tokens");
        console.log("3. Register new upkeep:");
        console.log("   Target:", address(automationContract));
        console.log("   Gas limit: 500,000");
        console.log("   Funding: 5 LINK minimum");
        console.log("4. Users call optInToAutomation()");
        console.log("5. Create deposits (they'll get stuck without AI)");
        console.log("6. Wait 4+ hours OR fast forward time");
        console.log("7. Watch automation execute emergency withdrawals!");
        console.log("");
        console.log("Benefits Demonstrated:");
        console.log("- 24/7 automated monitoring");
        console.log("- Batch processing (up to 10 positions/tx)");
        console.log("- Round-robin gas optimization");
        console.log("- User opt-in control");
        console.log("- Manual fallback preserved");
        console.log("- Real Chainlink Automation integration");
    }

    /// @notice Emergency admin functions for demo
    function adminDemo() external {
        vm.startBroadcast(userPrivateKey);

        console.log("\nADMIN DEMO FUNCTIONS");
        console.log("====================");

        // Show admin controls
        console.log("Admin can:");
        console.log("- Enable/disable automation");
        console.log("- Emergency withdraw for any user");
        console.log("- Monitor system health");

        // Toggle automation
        automationContract.setAutomationEnabled(false);
        console.log("Automation disabled");

        automationContract.setAutomationEnabled(true);
        console.log("Automation re-enabled");

        // Show monitoring data
        address[] memory optedInUsers = automationContract.getOptedInUsers();
        console.log("Current opted-in users:", optedInUsers.length);

        vm.stopBroadcast();
    }
}
