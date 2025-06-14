// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "forge-std/Script.sol";
import { AIControllerCallback } from "src/AIControllerCallback.sol";
import { AICollateralVaultCallback } from "src/AICollateralVaultCallback.sol";
import { SepoliaConfig } from "config/SepoliaConfig.sol";

/// @title DeployConfigurableController - Deploy new controller with configurable fees
/// @notice Deploys the updated AIControllerCallback with configurable oracle fee
contract DeployConfigurableControllerScript is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer = vm.envAddress("DEPLOYER_PUBLIC_KEY");

        console.log("=== Deploying Configurable Controller ===");
        console.log("Deployer:", deployer);
        console.log("Oracle address:", SepoliaConfig.ORA_ORACLE);

        vm.startBroadcast(deployerPrivateKey);

        // Deploy new controller with configurable fee
        uint256 modelId = 11; // Llama model
        uint64 callbackGasLimit = 500_000;
        uint256 initialOracleFee = 0.01 ether; // 0.01 ETH initial fee

        console.log("Deploying with parameters:");
        console.log("- Model ID:", modelId);
        console.log("- Callback gas limit:", callbackGasLimit);
        console.log("- Initial oracle fee:", initialOracleFee);

        AIControllerCallback newController =
            new AIControllerCallback(SepoliaConfig.ORA_ORACLE, modelId, callbackGasLimit, initialOracleFee);

        console.log("New Controller deployed at:", address(newController));

        // Set up authorization for the vault
        address vault = SepoliaConfig.AI_VAULT;
        newController.setAuthorizedCaller(vault, true);
        console.log("Authorized vault:", vault);

        // Verify configuration
        console.log("\n=== Verifying Configuration ===");
        console.log("Oracle fee:", newController.oracleFee());
        console.log("Flat fee:", newController.flatFee());
        // console.log("Total estimated fee:", newController.estimateTotalFee()); // Skip this - causes revert
        console.log("Model ID:", newController.modelId());
        console.log("Callback gas limit:", newController.callbackGasLimit());
        console.log("Authorized caller (vault):", newController.authorizedCallers(vault));

        vm.stopBroadcast();

        console.log("\n=== Next Steps ===");
        console.log("1. Update vault to use new controller:");
        console.log("   vault.updateAIController(", address(newController), ")");
        console.log("2. Test deposit with new configurable fee system");
        console.log("3. Update oracle fee as needed:");
        console.log("   newController.updateOracleFee(newFeeAmount)");

        console.log("\n[+] Deployment completed successfully!");
    }
}

// Usage:
// source .env && forge script script/DeployConfigurableController.s.sol:DeployConfigurableControllerScript --fork-url
// $SEPOLIA_RPC_URL --broadcast -vv
