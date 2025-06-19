// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "forge-std/Script.sol";
import { RiskOracleController } from "src/RiskOracleController.sol";
import { SepoliaConfig } from "config/SepoliaConfig.sol";

contract DeployRiskOracleControllerScript is Script {
    RiskOracleController controller;
    address deployerPublicKey;
    uint256 deployerPrivateKey;

    function setUp() public {
        deployerPublicKey = vm.envAddress("DEPLOYER_PUBLIC_KEY");
        deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
    }

    function run() public {
        // Chainlink Functions configuration
        address functionsRouter = SepoliaConfig.CHAINLINK_FUNCTIONS_ROUTER;
        bytes32 donId = SepoliaConfig.CHAINLINK_DON_ID;
        uint64 subscriptionId = SepoliaConfig.CHAINLINK_SUBSCRIPTION_ID;
        uint32 gasLimit = SepoliaConfig.CHAINLINK_GAS_LIMIT;
        string memory aiSourceCode = "return '150,75';"; // Simple AI response for testing

        vm.startBroadcast(deployerPrivateKey);

        console.log("=== Deploying RiskOracleController ===");
        console.log("Functions Router:", functionsRouter);
        console.log("DON ID:", vm.toString(donId));
        console.log("Subscription ID:", subscriptionId);
        console.log("Gas Limit:", gasLimit);

        // Deploy RiskOracleController with correct parameter order
        controller = new RiskOracleController(functionsRouter, donId, subscriptionId, aiSourceCode);

        // Setup price feeds using arrays (alternative: call controller.setupSepoliaFeeds() for convenience)
        string[] memory tokens = new string[](5);
        address[] memory feeds = new address[](5);

        tokens[0] = "BTC"; // BTC price feed used for WBTC token pricing
        feeds[0] = SepoliaConfig.BTC_USD_PRICE_FEED;

        tokens[1] = "ETH";
        feeds[1] = SepoliaConfig.ETH_USD_PRICE_FEED;

        tokens[2] = "LINK";
        feeds[2] = SepoliaConfig.LINK_USD_PRICE_FEED;

        tokens[3] = "DAI";
        feeds[3] = SepoliaConfig.DAI_USD_PRICE_FEED;

        tokens[4] = "USDC";
        feeds[4] = SepoliaConfig.USDC_USD_PRICE_FEED;

        controller.setPriceFeeds(tokens, feeds);

        console.log("RiskOracleController deployed at:", address(controller));
        console.log("Price feeds configured for 5 tokens (BTC, ETH, LINK, DAI, USDC)");

        vm.stopBroadcast();
    }
}

// Usage:
// 1. First create Chainlink Functions subscription at https://functions.chain.link
// 2. Update CHAINLINK_SUBSCRIPTION_ID in SepoliaConfig.sol
// 3. Run deployment:
// source .env && forge script script/02_DeployRiskOracleController.s.sol:DeployRiskOracleControllerScript --rpc-url
// $SEPOLIA_RPC_URL --broadcast --private-key $DEPLOYER_PRIVATE_KEY --etherscan-api-key $ETHERSCAN_API_KEY --gas-limit
// $GAS_LIMIT --gas-price $GAS_PRICE --verify -vvvv
