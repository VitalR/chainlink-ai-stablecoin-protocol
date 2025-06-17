// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "forge-std/Script.sol";

import { RiskOracleController } from "src/RiskOracleController.sol";
import { SepoliaConfig } from "config/SepoliaConfig.sol";

/// @title ProcessManualRequest - Process stuck AI requests manually
contract ProcessManualRequestScript is Script {
    RiskOracleController controller;

    function setUp() public {
        controller = RiskOracleController(SepoliaConfig.RISK_ORACLE_CONTROLLER);
    }

    /// @notice Request manual processing (user calls this first)
    function requestManualProcessing(uint256 requestId) public {
        vm.startBroadcast();

        console.log("=== Requesting Manual Processing ===");
        console.log("Request ID:", requestId);

        controller.requestManualProcessing(requestId);

        console.log("Manual processing requested successfully");

        vm.stopBroadcast();
    }

    /// @notice Process with force default mint strategy (owner/authorized processor)
    function processWithDefaultMint(uint256 requestId) public {
        vm.startBroadcast();

        console.log("=== Processing with Default Mint ===");
        console.log("Request ID:", requestId);

        // Use FORCE_DEFAULT_MINT strategy directly
        controller.processWithOffChainAI(requestId, "", RiskOracleController.ManualStrategy.FORCE_DEFAULT_MINT);

        console.log("Manual processing completed with default mint strategy");

        vm.stopBroadcast();
    }

    /// @notice Emergency withdrawal (user calls this)
    function emergencyWithdraw(uint256 requestId) public {
        vm.startBroadcast();

        console.log("=== Emergency Withdrawal ===");
        console.log("Request ID:", requestId);

        controller.emergencyWithdraw(requestId);

        console.log("Emergency withdrawal completed");

        vm.stopBroadcast();
    }

    /// @notice Process with simulated AI response (owner/authorized processor)
    function processWithAIResponse(uint256 requestId, string memory aiResponse) public {
        vm.startBroadcast();

        console.log("=== Processing with AI Response ===");
        console.log("Request ID:", requestId);
        console.log("AI Response:", aiResponse);

        controller.processWithOffChainAI(
            requestId, aiResponse, RiskOracleController.ManualStrategy.PROCESS_WITH_OFFCHAIN_AI
        );

        console.log("Manual processing completed with AI response");

        vm.stopBroadcast();
    }

    function run() public {
        console.log("Manual Request Processor");
        console.log("========================");

        // Get request ID from environment or default to 1
        uint256 requestId = vm.envOr("REQUEST_ID", uint256(1));
        string memory action = vm.envOr("ACTION", string("request"));

        if (keccak256(bytes(action)) == keccak256(bytes("request"))) {
            requestManualProcessing(requestId);
        } else if (keccak256(bytes(action)) == keccak256(bytes("default"))) {
            processWithDefaultMint(requestId);
        } else if (keccak256(bytes(action)) == keccak256(bytes("emergency"))) {
            emergencyWithdraw(requestId);
        } else if (keccak256(bytes(action)) == keccak256(bytes("ai"))) {
            string memory aiResponse = vm.envOr("AI_RESPONSE", string("15000")); // 150%
            processWithAIResponse(requestId, aiResponse);
        } else {
            console.log("Unknown action. Use: request, default, emergency, ai");
            revert("Invalid action");
        }
    }
}
