// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "forge-std/Script.sol";
import { AIStablecoin } from "src/AIStablecoin.sol";
import { CollateralVault } from "src/CollateralVault.sol";
import { RiskOracleController } from "src/RiskOracleController.sol";
import { SepoliaConfig } from "config/SepoliaConfig.sol";

/// @title SetupSystemEnhanced - Configure the enhanced AI Stablecoin system with RWA support
/// @notice Sets up permissions and validates enhanced dynamic pricing system
contract SetupSystemEnhancedScript is Script {
    AIStablecoin aiusd;
    CollateralVault vault;
    RiskOracleController controller;

    address deployerPublicKey;
    uint256 deployerPrivateKey;

    function setUp() public {
        deployerPublicKey = vm.envAddress("DEPLOYER_PUBLIC_KEY");
        deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");

        // Initialize contracts
        aiusd = AIStablecoin(SepoliaConfig.AI_STABLECOIN);
        vault = CollateralVault(payable(SepoliaConfig.COLLATERAL_VAULT));
        controller = RiskOracleController(SepoliaConfig.RISK_ORACLE_CONTROLLER);
    }

    function run() public {
        vm.startBroadcast(deployerPrivateKey);

        console.log("=== Enhanced AI Stablecoin System Setup ===");
        console.log("Stablecoin:", address(aiusd));
        console.log("Controller:", address(controller));
        console.log("Vault:", address(vault));

        // 1. Add vault to stablecoin (allows minting)
        console.log("\n1. Adding vault to stablecoin...");
        try aiusd.addVault(address(vault)) {
            console.log("Vault added to stablecoin");
        } catch {
            console.log("Vault already added to stablecoin (or other issue)");
        }

        // 2. Set vault as authorized caller in controller
        console.log("\n2. Authorizing vault in controller...");
        controller.setAuthorizedCaller(address(vault), true);
        console.log("Vault authorized in controller");

        // 3. The new enhanced vault should already have tokens configured from deployment
        // But let's verify and add any missing tokens
        console.log("\n3. Configuring enhanced token support...");

        // Note: The enhanced vault was deployed with all tokens pre-configured
        // This includes DAI, WETH, WBTC, USDC, and OUSG with dynamic pricing

        // Verify OUSG RWA support is properly configured
        try vault.tokenPriceFeeds(SepoliaConfig.MOCK_OUSG) returns (address ousgFeed) {
            if (ousgFeed == SepoliaConfig.OUSG_USD_PRICE_FEED) {
                console.log("OUSG RWA integration: CONFIRMED");
                console.log("OUSG price feed:", ousgFeed);
            } else {
                console.log("OUSG price feed needs configuration");
                vault.setTokenPriceFeed(SepoliaConfig.MOCK_OUSG, SepoliaConfig.OUSG_USD_PRICE_FEED);
                console.log("OUSG price feed configured");
            }
        } catch {
            console.log("Configuring OUSG RWA support...");
            // Add OUSG with dynamic pricing
            vault.addToken(
                SepoliaConfig.MOCK_OUSG,
                100 * 1e18, // $100 base price (will use dynamic pricing)
                18, // OUSG decimals
                "OUSG"
            );
            vault.setTokenPriceFeed(SepoliaConfig.MOCK_OUSG, SepoliaConfig.OUSG_USD_PRICE_FEED);
            console.log("OUSG RWA token added with dynamic pricing");
        }

        // 4. Verify system status
        console.log("\n4. System Status Check...");

        (bool paused, uint256 failures, uint256 lastFailure, bool circuitBreakerActive) = controller.getSystemStatus();
        console.log("Controller paused:", paused);
        console.log("Circuit breaker active:", circuitBreakerActive);

        require(!paused, "System is paused!");
        require(!circuitBreakerActive, "Circuit breaker is active!");

        console.log("\n=== Enhanced Setup Complete ===");
        console.log("System is ready for:");
        console.log("- Traditional crypto deposits (WETH, WBTC, DAI, USDC)");
        console.log("- Real World Asset deposits (OUSG Treasury bonds)");
        console.log("- Dynamic price feed integration");
        console.log("- AI-enhanced risk assessment");

        // Display key addresses
        console.log("\n=== Enhanced System Configuration ===");
        console.log("AI Stablecoin:", address(aiusd));
        console.log("Enhanced Controller (6 tokens):", address(controller));
        console.log("Enhanced Vault (dynamic pricing):", address(vault));
        console.log("OUSG RWA Token:", SepoliaConfig.MOCK_OUSG);
        console.log("OUSG Price Feed:", SepoliaConfig.OUSG_USD_PRICE_FEED);

        vm.stopBroadcast();
    }
}

// Usage:
// source .env && forge script script/deploy/04_SetupSystemEnhanced.s.sol:SetupSystemEnhancedScript --rpc-url
// $SEPOLIA_RPC_URL --broadcast --private-key $DEPLOYER_PRIVATE_KEY -vvvv
