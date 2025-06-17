// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "forge-std/Script.sol";
import { RiskOracleController } from "src/RiskOracleController.sol";
import { SepoliaConfig } from "config/SepoliaConfig.sol";

contract TestRiskOracleControllerScript is Script {
    address constant CONTROLLER_ADDRESS = 0x067b6c730DBFc6F180A70eae12D45305D12fe58A; // Update with deployed address

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployerAddress = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        RiskOracleController controller = RiskOracleController(CONTROLLER_ADDRESS);

        // Test 1: Check if we can read price feeds
        console.log("=== Testing Chainlink Data Feeds ===");

        try controller.getLatestPrice("ETH") returns (int256 price) {
            console.log("ETH/USD Price: %s", vm.toString(price));
        } catch {
            console.log("Failed to get ETH price");
        }

        try controller.getLatestPrice("WBTC") returns (int256 price) {
            console.log("BTC/USD Price: %s", vm.toString(price));
        } catch {
            console.log("Failed to get BTC price");
        }

        // Test 2: Submit AI request (this would normally be called by vault)
        console.log("=== Testing AI Request Submission ===");

        // Create test data
        address[] memory tokens = new address[](2);
        tokens[0] = address(0x1); // Mock WETH
        tokens[1] = address(0x2); // Mock DAI

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 5 ether;
        amounts[1] = 1000e18;

        // Simulate vault calling the controller
        try controller.submitAIRequest(deployerAddress, abi.encode(tokens, amounts), 10_000e18) returns (
            uint256 requestId
        ) {
            console.log("AI request submitted successfully");
            console.log("Request ID:", requestId);
        } catch {
            console.log("AI request submission failed (expected - only vault can call)");
        }

        // Test 3: Check system status
        console.log("=== System Status ===");
        (bool paused, uint256 failures, uint256 lastFailure, bool circuitBreakerActive) = controller.getSystemStatus();
        console.log("Processing paused:", paused);
        console.log("Failure count:", failures);
        console.log("Circuit breaker active:", circuitBreakerActive);

        vm.stopBroadcast();
    }
}

// Usage:
// source .env && forge script script/TestRiskOracleController.s.sol:TestRiskOracleControllerScript --rpc-url
// $SEPOLIA_RPC_URL --broadcast --private-key $DEPLOYER_PRIVATE_KEY -vvvv
