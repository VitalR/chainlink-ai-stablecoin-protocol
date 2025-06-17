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
        uint32 gasLimit = SepoliaConfig.CHAINLINK_GAS_LIMIT;
        uint64 subscriptionId = SepoliaConfig.CHAINLINK_SUBSCRIPTION_ID;

        require(functionsRouter != address(0), "Functions router address not set");
        require(donId != bytes32(0), "DON ID not set");
        require(subscriptionId > 0, "Subscription ID not set - create Functions subscription first");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy RiskOracleController with Chainlink Functions
        controller = new RiskOracleController(
            functionsRouter,
            donId,
            gasLimit,
            subscriptionId
        );

        // Configure price feeds
        controller.setPriceFeeds(
            "ETH",
            SepoliaConfig.ETH_USD_PRICE_FEED
        );
        
        controller.setPriceFeeds(
            "WBTC",
            SepoliaConfig.BTC_USD_PRICE_FEED
        );
        
        controller.setPriceFeeds(
            "LINK",
            SepoliaConfig.LINK_USD_PRICE_FEED
        );
        
        controller.setPriceFeeds(
            "DAI",
            SepoliaConfig.DAI_USD_PRICE_FEED
        );
        
        controller.setPriceFeeds(
            "USDC",
            SepoliaConfig.USDC_USD_PRICE_FEED
        );

        console.log("==RiskOracleController deployed at=%s", address(controller));
        console.log("==Functions Router=%s", functionsRouter);
        console.log("==DON ID=%s", vm.toString(donId));
        console.log("==Gas Limit=%s", gasLimit);
        console.log("==Subscription ID=%s", subscriptionId);
        console.log("==ETH/USD Feed=%s", SepoliaConfig.ETH_USD_PRICE_FEED);
        console.log("==BTC/USD Feed=%s", SepoliaConfig.BTC_USD_PRICE_FEED);

        vm.stopBroadcast();
    }
}

// Usage:
// 1. First create Chainlink Functions subscription at https://functions.chain.link
// 2. Update CHAINLINK_SUBSCRIPTION_ID in SepoliaConfig.sol
// 3. Run deployment:
// source .env && forge script script/02_DeployRiskOracleController.s.sol:DeployRiskOracleControllerScript --rpc-url $SEPOLIA_RPC_URL --broadcast --private-key $DEPLOYER_PRIVATE_KEY --etherscan-api-key $ETHERSCAN_API_KEY --gas-limit $GAS_LIMIT --gas-price $GAS_PRICE --verify -vvvv 