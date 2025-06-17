// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "forge-std/Script.sol";
import { RiskOracleController } from "src/RiskOracleController.sol";
import { SepoliaConfig } from "config/SepoliaConfig.sol";

contract TestRiskOracleControllerScript is Script {
    address constant CONTROLLER_ADDRESS = 0x067b6c730DBFc6F180A70eae12D45305D12fe58A; // Update with deployed address

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");

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

        // Test 2: Request AI risk assessment
        console.log("\n=== Testing Chainlink Functions AI Assessment ===");

        // Create a test portfolio
        string[] memory tokens = new string[](3);
        tokens[0] = "ETH";
        tokens[1] = "WBTC";
        tokens[2] = "DAI";

        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 50_000e18; // 50k USD worth of ETH
        amounts[1] = 30_000e18; // 30k USD worth of BTC
        amounts[2] = 20_000e18; // 20k USD worth of DAI

        uint256[] memory prices = new uint256[](3);
        prices[0] = 3500e8; // $3500 ETH
        prices[1] = 95_000e8; // $95000 BTC
        prices[2] = 1e8; // $1 DAI

        try controller.requestRiskAssessment(tokens, amounts, prices) returns (bytes32 requestId) {
            console.log("Risk assessment requested with ID: %s", vm.toString(requestId));
            console.log("Check back in ~1 minute for results");
        } catch Error(string memory reason) {
            console.log("Failed to request risk assessment: %s", reason);
        } catch {
            console.log("Failed to request risk assessment: Unknown error");
        }

        // Test 3: Check if there are any pending requests
        console.log("\n=== Checking System Status ===");
        console.log("Controller address: %s", address(controller));
        console.log("Emergency stopped: %s", controller.emergencyStop() ? "true" : "false");

        vm.stopBroadcast();
    }
}

// Usage:
// source .env && forge script script/TestRiskOracleController.s.sol:TestRiskOracleControllerScript --rpc-url
// $SEPOLIA_RPC_URL --broadcast --private-key $DEPLOYER_PRIVATE_KEY -vvvv
