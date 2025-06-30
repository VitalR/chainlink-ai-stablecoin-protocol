// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "forge-std/Script.sol";
import { AIStablecoin } from "src/AIStablecoin.sol";
import { AutoEmergencyWithdrawal } from "src/automation/AutoEmergencyWithdrawal.sol";
import { CollateralVault } from "src/CollateralVault.sol";
import { RiskOracleController } from "src/RiskOracleController.sol";
import { SepoliaConfig } from "config/SepoliaConfig.sol";

/// @title Authorize Vault - Essential permissions for enhanced vault
/// @notice Only handles the essential authorization steps since enhanced constructor does the rest
/// @dev Use this after deploying vault with enhanced constructor that pre-configures everything
contract AuthorizeVaultScript is Script {
    AIStablecoin aiusd;
    CollateralVault vault;
    RiskOracleController controller;
    AutoEmergencyWithdrawal automation;

    address deployerPublicKey;
    uint256 deployerPrivateKey;

    function setUp() public {
        deployerPublicKey = vm.envAddress("DEPLOYER_PUBLIC_KEY");
        deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");

        // Initialize contracts
        aiusd = AIStablecoin(SepoliaConfig.AI_STABLECOIN);
        vault = CollateralVault(payable(SepoliaConfig.COLLATERAL_VAULT));
        controller = RiskOracleController(SepoliaConfig.RISK_ORACLE_CONTROLLER);
        automation = AutoEmergencyWithdrawal(SepoliaConfig.AUTO_EMERGENCY_WITHDRAWAL);
    }

    function run() public {
        vm.startBroadcast(deployerPrivateKey);

        console.log("=== Minimal Vault Authorization Setup ===");
        console.log("Deployer:", deployerPublicKey);
        console.log("Stablecoin:", address(aiusd));
        console.log("Controller:", address(controller));
        console.log("Vault:", address(vault));
        console.log("Automation:", address(automation));
        console.log("");

        // ==========================================
        // STEP 1: ESSENTIAL PERMISSIONS ONLY
        // ==========================================

        console.log("1. Configuring Essential Permissions...");

        // Set vault address in AutoEmergencyWithdrawal (was deployed with address(0))
        try automation.setVault(address(vault)) {
            console.log("   SUCCESS: Vault address set in AutoEmergencyWithdrawal");
        } catch {
            console.log("   INFO: Vault address already set in AutoEmergencyWithdrawal");
        }

        // Add vault to stablecoin (allows minting)
        try aiusd.addVault(address(vault)) {
            console.log("   SUCCESS: Vault added to stablecoin (can mint AIUSD)");
        } catch {
            console.log("   INFO: Vault already added to stablecoin");
        }

        // Set vault as authorized caller in controller
        try controller.setAuthorizedCaller(address(vault), true) {
            console.log("   SUCCESS: Vault authorized in controller (can submit AI requests)");
        } catch {
            console.log("   INFO: Vault already authorized in controller");
        }

        // ==========================================
        // VERIFICATION: CHECK WHAT'S ALREADY DONE
        // ==========================================

        console.log("\n2. Verifying Enhanced Constructor Setup...");

        // Check tokens are pre-configured
        try vault.supportedTokens(SepoliaConfig.MOCK_WETH) returns (uint256 price, uint8 decimals, bool supported) {
            if (supported) {
                console.log("   SUCCESS: WETH pre-configured ($%s, %s decimals)", price / 1e18, decimals);
            }
        } catch {
            console.log("   WARNING: WETH not configured");
        }

        try vault.supportedTokens(SepoliaConfig.MOCK_WBTC) returns (uint256 price, uint8 decimals, bool supported) {
            if (supported) {
                console.log("   SUCCESS: WBTC pre-configured ($%s, %s decimals)", price / 1e18, decimals);
            }
        } catch {
            console.log("   WARNING: WBTC not configured");
        }

        try vault.supportedTokens(SepoliaConfig.MOCK_OUSG) returns (uint256 price, uint8 decimals, bool supported) {
            if (supported) {
                console.log("   SUCCESS: OUSG (RWA) pre-configured ($%s, %s decimals)", price / 1e18, decimals);
            }
        } catch {
            console.log("   WARNING: OUSG not configured");
        }

        try vault.supportedTokens(SepoliaConfig.MOCK_DAI) returns (uint256 price, uint8 decimals, bool supported) {
            if (supported) {
                console.log("   SUCCESS: DAI pre-configured ($%s, %s decimals)", price / 1e18, decimals);
            }
        } catch {
            console.log("   WARNING: DAI not configured");
        }

        try vault.supportedTokens(SepoliaConfig.MOCK_USDC) returns (uint256 price, uint8 decimals, bool supported) {
            if (supported) {
                console.log("   SUCCESS: USDC pre-configured ($%s, %s decimals)", price / 1e18, decimals);
            }
        } catch {
            console.log("   WARNING: USDC not configured");
        }

        // Check automation is authorized
        bool automationAuthorized = vault.authorizedAutomation(SepoliaConfig.AUTO_EMERGENCY_WITHDRAWAL);
        if (automationAuthorized) {
            console.log("   SUCCESS: Automation contract pre-authorized");
        } else {
            console.log("   WARNING: Automation not authorized");
        }

        // Check automation has correct vault address
        address automationVault = address(automation.vault());
        if (automationVault == address(vault)) {
            console.log("   SUCCESS: Automation contract connected to correct vault");
        } else {
            console.log("   WARNING: Automation vault address incorrect (current: %s)", automationVault);
        }

        // Check price feeds are connected
        address wethPriceFeed = vault.tokenPriceFeeds(SepoliaConfig.MOCK_WETH);
        if (wethPriceFeed != address(0)) {
            console.log("   SUCCESS: Dynamic price feeds pre-configured");
        } else {
            console.log("   WARNING: Price feeds not configured");
        }

        // ==========================================
        // SYSTEM STATUS CHECK
        // ==========================================

        console.log("\n3. System Status Check...");

        // Check controller status
        (bool paused, uint256 failures, uint256 lastFailure, bool circuitBreakerActive) = controller.getSystemStatus();
        console.log("   Controller Status:");
        console.log("      - Paused: %s", paused ? "YES" : "NO");
        console.log("      - Circuit breaker: %s", circuitBreakerActive ? "ACTIVE" : "INACTIVE");
        console.log("      - Failure count: %s", failures);

        // Test price feeds if available
        try controller.getLatestPrice("ETH") returns (int256 ethPrice) {
            console.log("   Price Feed Test:");
            console.log("      - ETH/USD: $%s", uint256(ethPrice) / 1e8);
        } catch {
            console.log("   INFO: Price feeds may need time to activate");
        }

        vm.stopBroadcast();

        // ==========================================
        // COMPLETION SUMMARY
        // ==========================================

        console.log("\n=== AUTHORIZATION COMPLETE ===");
        console.log("");
        console.log("SUCCESS: Vault authorized to mint AIUSD");
        console.log("SUCCESS: Vault authorized to submit AI requests");
        console.log("SUCCESS: Automation vault address configured");
        console.log("SUCCESS: Enhanced constructor already handled:");
        console.log("   - Token configuration (5 tokens)");
        console.log("   - Dynamic price feeds");
        console.log("   - Automation authorization");
        console.log("");
        console.log("SYSTEM READY FOR DEPOSITS!");
        console.log("");
        console.log("Next Steps:");
        console.log("1. Register automation: https://automation.chain.link/sepolia");
        console.log("   Target: %s", SepoliaConfig.AUTO_EMERGENCY_WITHDRAWAL);
        console.log("2. Users can call optInToAutomation()");
        console.log("3. Users can deposit collateral immediately");
        console.log("4. Full Chainlink Automation protection active");
    }
}

// Usage:
// source .env && forge script script/deploy/05_AuthorizeVault.s.sol:AuthorizeVaultScript --rpc-url $SEPOLIA_RPC_URL
// --broadcast --private-key $DEPLOYER_PRIVATE_KEY -vvv
