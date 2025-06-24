// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "forge-std/Script.sol";
import { CollateralVault } from "src/CollateralVault.sol";
import { RiskOracleController } from "src/RiskOracleController.sol";
import { SepoliaConfig } from "config/SepoliaConfig.sol";

/// @title Integrate RWA Price Feed Script
/// @notice Connects the deployed MockRWAPriceFeed with the vault and oracle systems
contract IntegrateRWAPriceFeedScript is Script {
    CollateralVault public vault;
    RiskOracleController public controller;
    
    address deployerPublicKey;
    uint256 deployerPrivateKey;

    function setUp() public {
        deployerPublicKey = vm.envAddress("DEPLOYER_PUBLIC_KEY");
        deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        
        vault = CollateralVault(payable(SepoliaConfig.COLLATERAL_VAULT));
        controller = RiskOracleController(SepoliaConfig.RISK_ORACLE_CONTROLLER);
    }

    function run() public {
        vm.startBroadcast(deployerPrivateKey);
        
        console.log("=== Integrating MockRWAPriceFeed with System ===");
        console.log("OUSG Token:", SepoliaConfig.MOCK_OUSG);
        console.log("OUSG Price Feed:", SepoliaConfig.OUSG_USD_PRICE_FEED);
        
        // 1. Set OUSG price feed in CollateralVault for dynamic pricing
        console.log("Setting OUSG price feed in CollateralVault...");
        vault.setTokenPriceFeed(SepoliaConfig.MOCK_OUSG, SepoliaConfig.OUSG_USD_PRICE_FEED);
        console.log("SUCCESS: OUSG price feed set in vault");
        
        // 2. Add OUSG price feed to RiskOracleController for AI analysis
        console.log("Adding OUSG to RiskOracleController price feeds...");
        string[] memory tokens = new string[](1);
        address[] memory feeds = new address[](1);
        tokens[0] = "OUSG";
        feeds[0] = SepoliaConfig.OUSG_USD_PRICE_FEED;
        
        controller.setPriceFeeds(tokens, feeds);
        console.log("SUCCESS: OUSG price feed added to RiskOracleController");
        
        // 3. Verify integration
        console.log("\n=== Verification ===");
        
        // Check vault price feed
        address vaultFeed = vault.tokenPriceFeeds(SepoliaConfig.MOCK_OUSG);
        console.log("Vault OUSG price feed:", vaultFeed);
        require(vaultFeed == SepoliaConfig.OUSG_USD_PRICE_FEED, "Vault price feed not set correctly");
        
        // Check controller price feed
        int256 ousgPrice = controller.getLatestPrice("OUSG");
        console.log("Controller OUSG price: $", uint256(ousgPrice) / 1e8);
        require(ousgPrice > 0, "Controller price feed not working");
        
        // Test AI price JSON includes OUSG
        string memory priceJson = controller.getCurrentPricesForTesting();
        console.log("AI Price JSON:", priceJson);
        
        vm.stopBroadcast();
        
        console.log("SUCCESS: MockRWAPriceFeed fully integrated!");
        console.log("==========================================");
        console.log("SUCCESS: CollateralVault now uses dynamic OUSG pricing");
        console.log("SUCCESS: AI system now sees real-time OUSG prices");
        console.log("SUCCESS: Treasury yield appreciation tracked in real-time");
        console.log("==========================================");
    }
} 