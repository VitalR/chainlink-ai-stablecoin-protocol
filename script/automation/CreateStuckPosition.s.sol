// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";

import { AutoEmergencyWithdrawal } from "../../src/automation/AutoEmergencyWithdrawal.sol";
import { CollateralVault } from "../../src/CollateralVault.sol";
import { IRiskOracleController } from "../../src/interfaces/IRiskOracleController.sol";
import { MockWETH } from "../../test/mocks/MockWETH.sol";
import { SepoliaConfig } from "config/SepoliaConfig.sol";

/// @title Create Stuck Position for Automation Testing
/// @notice Creates a position using TEST_TIMEOUT engine to test automation
contract CreateStuckPositionScript is Script {
    address user;
    uint256 userPrivateKey;

    AutoEmergencyWithdrawal automationContract;
    CollateralVault vault;
    MockWETH weth;

    function setUp() public {
        user = vm.envAddress("DEPLOYER_PUBLIC_KEY");
        userPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");

        automationContract = AutoEmergencyWithdrawal(SepoliaConfig.AUTO_EMERGENCY_WITHDRAWAL);
        vault = CollateralVault(payable(SepoliaConfig.COLLATERAL_VAULT));
        weth = MockWETH(SepoliaConfig.MOCK_WETH);
    }

    function run() external {
        console.log("=== CREATE STUCK POSITION FOR AUTOMATION ===");
        console.log("User:", user);
        console.log("");

        // Step 1: Check if user is opted into automation
        _checkAutomationStatus();

        // Step 2: Create stuck position
        _createStuckPosition();

        // Step 3: Show next steps
        _showNextSteps();
    }

    function _checkAutomationStatus() internal view {
        console.log("=== STEP 1: CHECK AUTOMATION STATUS ===");

        bool userOptedIn = automationContract.isUserOptedIn(user);
        console.log("User opted into automation:", userOptedIn);

        if (!userOptedIn) {
            console.log("ERROR: User must opt into automation first!");
            console.log("Run: automationContract.optInToAutomation()");
            return;
        }

        uint256 emergencyDelay = vault.emergencyWithdrawalDelay();
        console.log("Emergency delay:", emergencyDelay, "seconds");
        console.log("Emergency delay:", emergencyDelay / 60, "minutes");
        console.log("");
    }

    function _createStuckPosition() internal {
        vm.startBroadcast(userPrivateKey);

        console.log("=== STEP 2: CREATE STUCK POSITION ===");

        // Check current WETH balance
        uint256 currentBalance = weth.balanceOf(user);
        console.log("Current WETH balance:", currentBalance / 1e18, "WETH");

        // Mint WETH if needed
        if (currentBalance < 1 ether) {
            weth.mint(user, 5 ether);
            console.log("Minted 5 WETH for testing");
        }

        // Approve vault
        weth.approve(address(vault), type(uint256).max);
        console.log("Approved vault for WETH transfers");

        // Create deposit with TEST_TIMEOUT engine (this will get stuck!)
        address[] memory tokens = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        tokens[0] = address(weth);
        amounts[0] = 1 ether;

        console.log("Creating position with TEST_TIMEOUT engine...");
        console.log("- Token: WETH");
        console.log("- Amount: 1 WETH");
        console.log("- Engine: TEST_TIMEOUT (will get stuck)");

        uint256 balanceBefore = weth.balanceOf(user);

        // This creates a position that will NEVER get AI response
        vault.depositBasket(tokens, amounts, IRiskOracleController.Engine.TEST_TIMEOUT);

        uint256 balanceAfter = weth.balanceOf(user);
        console.log("SUCCESS: Position created!");
        console.log("- WETH balance before:", balanceBefore / 1e18, "WETH");
        console.log("- WETH balance after:", balanceAfter / 1e18, "WETH");
        console.log("- WETH used:", (balanceBefore - balanceAfter) / 1e18, "WETH");

        // Check position status
        (uint256 totalPositions, uint256 activePositions,,) = vault.getPositionSummary(user);
        console.log("- Total positions:", totalPositions);
        console.log("- Active positions:", activePositions);

        vm.stopBroadcast();
        console.log("");
    }

    function _showNextSteps() internal view {
        console.log("=== STEP 3: NEXT STEPS ===");

        uint256 emergencyDelay = vault.emergencyWithdrawalDelay();
        console.log("Wait for emergency delay:");
        console.log("- Minutes:", emergencyDelay / 60);
        console.log("- Seconds:", emergencyDelay);
        console.log("");
        console.log("1. Check automation readiness:");
        console.log("   forge script script/test/DiagnoseAutomation.s.sol --rpc-url $SEPOLIA_RPC_URL");
        console.log("");
        console.log("2. If upkeep needed = true, automation will trigger!");
        console.log("3. OR manually trigger for testing:");
        console.log("   automationContract.performUpkeep(performData)");
        console.log("");
        console.log("SUCCESS: Stuck position created!");
    }
}
