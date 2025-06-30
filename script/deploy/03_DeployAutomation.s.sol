// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";

import { AutoEmergencyWithdrawal } from "../../src/automation/AutoEmergencyWithdrawal.sol";
import { SepoliaConfig } from "../../config/SepoliaConfig.sol";
import { CollateralVault } from "../../src/CollateralVault.sol";

/// @title Deploy Chainlink Automation Emergency Withdrawal
/// @notice Deploys the AutoEmergencyWithdrawal contract for real Chainlink Automation
/// @dev This contract will be registered with Chainlink Automation on Sepolia
contract DeployAutomationScript is Script {
    address deployerPublicKey;
    uint256 deployerPrivateKey;

    function setUp() public {
        deployerPublicKey = vm.envAddress("DEPLOYER_PUBLIC_KEY");
        deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
    }

    /// @notice Deploy automation contract for hackathon demo
    function run() external {
        vm.startBroadcast(deployerPrivateKey);

        console.log("=== Deploying Chainlink Automation Contract ===");
        console.log("Deployer:", deployerPublicKey);

        address vaultAddress = SepoliaConfig.COLLATERAL_VAULT;
        console.log("Target Vault Address:", vaultAddress);

        // Deploy automation contract
        // Note: If vault is address(0), we deploy anyway and authorize later
        AutoEmergencyWithdrawal automationContract = new AutoEmergencyWithdrawal(vaultAddress);

        console.log("AutoEmergencyWithdrawal deployed at:", address(automationContract));

        // Try to authorize in vault if it exists
        if (vaultAddress != address(0)) {
            try CollateralVault(payable(vaultAddress)).setAutomationAuthorized(address(automationContract), true) {
                console.log("SUCCESS: Automation contract authorized in existing vault");
            } catch {
                console.log("WARNING: Could not authorize in vault (vault may not support authorization yet)");
                console.log("         Run vault deployment script to deploy enhanced vault with authorization");
            }
        } else {
            console.log("INFO: No vault address set in config - deploy vault next");
        }

        console.log("");
        console.log("=== DEPLOYMENT COMPLETE ===");
        console.log("Update SepoliaConfig.sol with:");
        console.log("  AUTO_EMERGENCY_WITHDRAWAL = %s", address(automationContract));

        console.log("");
        console.log("=== NEXT STEPS FOR HACKATHON DEMO ===");
        console.log("1. Update config with automation address above");
        console.log("2. Deploy enhanced vault: forge script script/deploy/04_DeployVault.s.sol --broadcast");
        console.log("3. Register at https://automation.chain.link/sepolia:");
        console.log("   Target contract: %s", address(automationContract));
        console.log("   Admin address: %s", deployerPublicKey);
        console.log("   Gas limit: 500,000 (recommended)");
        console.log("   Starting balance: 5 LINK (minimum)");
        console.log("   Check data: 0x (empty)");
        console.log("");
        console.log("4. Test workflow:");
        console.log("   - Users call optInToAutomation()");
        console.log("   - Create deposits (they'll get stuck without AI)");
        console.log("   - Wait 4+ hours OR fast forward time in tests");
        console.log("   - Watch automation execute emergency withdrawals!");

        vm.stopBroadcast();
    }
}
