// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { RiskOracleController } from "../../src/RiskOracleController.sol";
import { SepoliaConfig } from "../../config/SepoliaConfig.sol";

/// @title Setup Price Feeds Deployment Script
/// @notice Configures Chainlink price feeds for the RiskOracleController on Sepolia testnet
/// @dev Sets up all 6 supported price feeds (BTC, ETH, LINK, DAI, USDC, OUSG) using verified Sepolia addresses
contract SetupPriceFeedsScript is Script {
    address deployerPublicKey;
    uint256 deployerPrivateKey;

    function setUp() public {
        deployerPublicKey = vm.envAddress("DEPLOYER_PUBLIC_KEY");
        deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
    }

    /// @notice Main deployment function
    /// @dev Deploys and configures price feeds for an existing RiskOracleController
    function run() external {
        // Get controller address from config
        address controllerAddress = SepoliaConfig.RISK_ORACLE_CONTROLLER;

        console.log("Setting up price feeds for RiskOracleController at:", controllerAddress);

        vm.startBroadcast(deployerPrivateKey);

        RiskOracleController controller = RiskOracleController(controllerAddress);

        // Setup Sepolia price feeds (all 6 supported tokens)
        controller.setupSepoliaFeeds();

        vm.stopBroadcast();

        console.log("Price feeds configured successfully!");
        console.log("- BTC/USD feed:", SepoliaConfig.BTC_USD_PRICE_FEED);
        console.log("- ETH/USD feed:", SepoliaConfig.ETH_USD_PRICE_FEED);
        console.log("- LINK/USD feed:", SepoliaConfig.LINK_USD_PRICE_FEED);
        console.log("- DAI/USD feed:", SepoliaConfig.DAI_USD_PRICE_FEED);
        console.log("- USDC/USD feed:", SepoliaConfig.USDC_USD_PRICE_FEED);
        console.log("- OUSG/USD feed (RWA):", SepoliaConfig.OUSG_USD_PRICE_FEED);
    }

    /// @notice Alternative setup function for custom controller address
    /// @param controllerAddress Address of deployed RiskOracleController
    function setupFeeds(address controllerAddress) external {
        vm.startBroadcast();

        RiskOracleController controller = RiskOracleController(controllerAddress);
        controller.setupSepoliaFeeds();

        vm.stopBroadcast();

        console.log("Price feeds configured for controller:", controllerAddress);
    }
}
