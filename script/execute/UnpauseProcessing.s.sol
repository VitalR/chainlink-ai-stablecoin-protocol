// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "forge-std/Script.sol";
import { RiskOracleController } from "src/RiskOracleController.sol";

/// @title UnpauseProcessing - Resume AI processing
contract UnpauseProcessingScript is Script {
    address public constant RISK_ORACLE_CONTROLLER = 0xf8D3A0d5dE0368319123a43b925d01D867Af2229;

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        RiskOracleController controller = RiskOracleController(RISK_ORACLE_CONTROLLER);

        // Check current status
        (bool paused, uint256 failures, uint256 lastFailure, bool circuitBreakerActive) = controller.getSystemStatus();

        console.log("=== UNPAUSING AI PROCESSING ===");
        console.log("Controller address:", RISK_ORACLE_CONTROLLER);
        console.log("Current status:");
        console.log("- Processing paused:", paused);
        console.log("- Failure count:", failures);
        console.log("- Circuit breaker active:", circuitBreakerActive);

        if (paused) {
            controller.resumeProcessing();
            console.log("[SUCCESS] AI processing resumed!");
        } else {
            console.log("[INFO] AI processing was already running");
        }

        // Verify final status
        (bool nowPaused,,,) = controller.getSystemStatus();
        console.log("Final status - Processing paused:", nowPaused);

        vm.stopBroadcast();
    }
}
