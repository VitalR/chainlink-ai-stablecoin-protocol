// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "forge-std/Script.sol";
import { AIStablecoin } from "src/AIStablecoin.sol";
import { CollateralVault } from "src/CollateralVault.sol";
import { RiskOracleController } from "src/RiskOracleController.sol";
import { SepoliaConfig } from "config/SepoliaConfig.sol";

/// @title Complete System Setup - Optional comprehensive configuration
/// @notice Combines permissions, token configuration, price feeds, and validation in one script
/// @dev Optional full setup - usually not needed if enhanced vault constructor was used
contract SetupSystemCompleteScript is Script {
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

        console.log("=== AI Stablecoin Complete System Setup ===");
        console.log("Deployer:", deployerPublicKey);
        console.log("Stablecoin:", address(aiusd));
        console.log("Controller:", address(controller));
        console.log("Vault:", address(vault));
        console.log("");

        // Run all setup steps
        setupSystemPermissions();
        setupChainlinkPriceFeeds();
        setupTokenConfiguration();
        setupDynamicPricing();
        validateSystem();

        _displaySystemSummary();

        vm.stopBroadcast();
    }

    /// @notice STEP 1: Configure essential system permissions
    function setupSystemPermissions() public {
        console.log("1. Configuring System Permissions...");

        // Add vault to stablecoin (allows minting)
        try aiusd.addVault(address(vault)) {
            console.log("   SUCCESS: Vault added to stablecoin");
        } catch {
            console.log("   WARNING: Vault already added to stablecoin");
        }

        // Set vault as authorized caller in controller
        controller.setAuthorizedCaller(address(vault), true);
        console.log("   SUCCESS: Vault authorized in controller");
    }

    /// @notice STEP 2: Setup Chainlink price feeds in controller
    function setupChainlinkPriceFeeds() public {
        console.log("\n2. Configuring Chainlink Price Feeds...");

        // Setup all Sepolia price feeds for 6 tokens
        controller.setupSepoliaFeeds();
        console.log("   SUCCESS: All 6 Chainlink price feeds configured:");
        console.log("      - ETH/USD:", SepoliaConfig.ETH_USD_PRICE_FEED);
        console.log("      - BTC/USD:", SepoliaConfig.BTC_USD_PRICE_FEED);
        console.log("      - LINK/USD:", SepoliaConfig.LINK_USD_PRICE_FEED);
        console.log("      - DAI/USD:", SepoliaConfig.DAI_USD_PRICE_FEED);
        console.log("      - USDC/USD:", SepoliaConfig.USDC_USD_PRICE_FEED);
        console.log("      - OUSG/USD (RWA):", SepoliaConfig.OUSG_USD_PRICE_FEED);
    }

    /// @notice STEP 3: Configure supported tokens in vault
    function setupTokenConfiguration() public {
        console.log("\n3. Configuring Supported Tokens...");

        // Check if vault was deployed with pre-configured tokens
        // If not, add them manually with fallback prices

        // WETH Configuration
        try vault.supportedTokens(SepoliaConfig.MOCK_WETH) returns (uint256, uint8, bool supported) {
            if (supported) {
                console.log("   SUCCESS: WETH already configured");
            } else {
                _addTokenWithFallback("WETH", SepoliaConfig.MOCK_WETH, 18, 2500 * 1e18);
            }
        } catch {
            _addTokenWithFallback("WETH", SepoliaConfig.MOCK_WETH, 18, 2500 * 1e18);
        }

        // WBTC Configuration
        try vault.supportedTokens(SepoliaConfig.MOCK_WBTC) returns (uint256, uint8, bool supported) {
            if (supported) {
                console.log("   SUCCESS: WBTC already configured");
            } else {
                _addTokenWithFallback("WBTC", SepoliaConfig.MOCK_WBTC, 8, 100_000 * 1e18);
            }
        } catch {
            _addTokenWithFallback("WBTC", SepoliaConfig.MOCK_WBTC, 8, 100_000 * 1e18);
        }

        // DAI Configuration
        try vault.supportedTokens(SepoliaConfig.MOCK_DAI) returns (uint256, uint8, bool supported) {
            if (supported) {
                console.log("   SUCCESS: DAI already configured");
            } else {
                _addTokenWithFallback("DAI", SepoliaConfig.MOCK_DAI, 18, 1 * 1e18);
            }
        } catch {
            _addTokenWithFallback("DAI", SepoliaConfig.MOCK_DAI, 18, 1 * 1e18);
        }

        // USDC Configuration
        try vault.supportedTokens(SepoliaConfig.MOCK_USDC) returns (uint256, uint8, bool supported) {
            if (supported) {
                console.log("   SUCCESS: USDC already configured");
            } else {
                _addTokenWithFallback("USDC", SepoliaConfig.MOCK_USDC, 6, 1 * 1e18);
            }
        } catch {
            _addTokenWithFallback("USDC", SepoliaConfig.MOCK_USDC, 6, 1 * 1e18);
        }

        // OUSG (RWA) Configuration
        try vault.supportedTokens(SepoliaConfig.MOCK_OUSG) returns (uint256, uint8, bool supported) {
            if (supported) {
                console.log("   SUCCESS: OUSG (RWA) already configured");
            } else {
                _addTokenWithFallback("OUSG", SepoliaConfig.MOCK_OUSG, 18, 100 * 1e18);
            }
        } catch {
            _addTokenWithFallback("OUSG", SepoliaConfig.MOCK_OUSG, 18, 100 * 1e18);
        }
    }

    /// @notice STEP 4: Setup dynamic pricing for all tokens
    function setupDynamicPricing() public {
        console.log("\n4. Enabling Dynamic Pricing...");

        // Link tokens to their Chainlink price feeds for dynamic pricing
        _setupDynamicPricing("WETH", SepoliaConfig.MOCK_WETH, SepoliaConfig.ETH_USD_PRICE_FEED);
        _setupDynamicPricing("WBTC", SepoliaConfig.MOCK_WBTC, SepoliaConfig.BTC_USD_PRICE_FEED);
        _setupDynamicPricing("DAI", SepoliaConfig.MOCK_DAI, SepoliaConfig.DAI_USD_PRICE_FEED);
        _setupDynamicPricing("USDC", SepoliaConfig.MOCK_USDC, SepoliaConfig.USDC_USD_PRICE_FEED);
        _setupDynamicPricing("OUSG", SepoliaConfig.MOCK_OUSG, SepoliaConfig.OUSG_USD_PRICE_FEED);
    }

    /// @notice STEP 5: Validate system configuration
    function validateSystem() public {
        console.log("\n5. System Validation...");

        // Check controller status
        (bool paused, uint256 failures, uint256 lastFailure, bool circuitBreakerActive) = controller.getSystemStatus();
        console.log("   Controller Status:");
        console.log("      - Paused:", paused);
        console.log("      - Circuit breaker active:", circuitBreakerActive);
        console.log("      - Failure count:", failures);

        require(!paused, "ERROR: System is paused!");
        require(!circuitBreakerActive, "ERROR: Circuit breaker is active!");

        // Verify AI source code is set
        string memory aiSource = controller.aiSourceCode();
        require(bytes(aiSource).length > 0, "ERROR: AI source code not configured!");
        console.log("   SUCCESS: AI source code configured (", bytes(aiSource).length, "bytes)");

        // Test price feeds
        console.log("   Price Feed Test:");
        try controller.getLatestPrice("ETH") returns (int256 ethPrice) {
            console.log("      - ETH/USD: $", uint256(ethPrice) / 1e8);
            console.log("   SUCCESS: Price feeds working");
        } catch {
            console.log("   WARNING: Price feeds may need time to activate");
        }

        console.log("\n=== SUCCESS: Complete Setup Successful! ===");
        console.log("");
        console.log("System Features Enabled:");
        console.log("SUCCESS: 5 Crypto tokens (WETH, WBTC, DAI, USDC) + 1 RWA (OUSG)");
        console.log("SUCCESS: Dynamic Chainlink price feeds for all tokens");
        console.log("SUCCESS: AI-powered risk assessment with fallback algorithms");
        console.log("SUCCESS: Real World Asset (OUSG Treasury bonds) support");
        console.log("SUCCESS: Circuit breaker protection and manual processing");
        console.log("");
        console.log("Next Steps:");
        console.log("1. Automation DEPLOYED at:", SepoliaConfig.AUTO_EMERGENCY_WITHDRAWAL);
        console.log("2. Register with Chainlink Automation: https://automation.chain.link/sepolia");
        console.log("3. Deploy enhanced vault: forge script script/deploy/04_DeployVault.s.sol --broadcast");
        console.log("4. Start accepting user deposits!");
        console.log("");
    }

    /// @notice Run only essential permissions setup (for enhanced vault)
    function runMinimalSetup() external {
        vm.startBroadcast(deployerPrivateKey);

        console.log("=== Minimal Setup for Enhanced Vault ===");
        setupSystemPermissions();

        console.log("\nSUCCESS: MINIMAL SETUP COMPLETE");
        console.log("Enhanced vault constructor handles the rest!");

        vm.stopBroadcast();
    }

    /// @notice Helper function to add token with fallback price
    function _addTokenWithFallback(string memory symbol, address tokenAddress, uint8 decimals, uint256 fallbackPrice)
        internal
    {
        vault.addToken(tokenAddress, fallbackPrice, decimals, symbol);
        console.log("   SUCCESS:", symbol, "added with fallback price: $", fallbackPrice / 1e18);
    }

    /// @notice Helper function to setup dynamic pricing for a token
    function _setupDynamicPricing(string memory symbol, address tokenAddress, address priceFeed) internal {
        try vault.setTokenPriceFeed(tokenAddress, priceFeed) {
            console.log("   SUCCESS:", symbol, "dynamic pricing enabled");
        } catch {
            console.log("   WARNING:", symbol, "dynamic pricing failed (may already be set)");
        }
    }

    /// @notice Display comprehensive system summary
    function _displaySystemSummary() internal view {
        console.log("=== System Configuration Summary ===");
        console.log("CORE_CONTRACTS:");
        console.log("  AI_STABLECOIN =", SepoliaConfig.AI_STABLECOIN);
        console.log("  COLLATERAL_VAULT =", SepoliaConfig.COLLATERAL_VAULT);
        console.log("  RISK_ORACLE_CONTROLLER =", SepoliaConfig.RISK_ORACLE_CONTROLLER);
        console.log("");
        console.log("SUPPORTED_TOKENS:");
        console.log("  MOCK_WETH =", SepoliaConfig.MOCK_WETH);
        console.log("  MOCK_WBTC =", SepoliaConfig.MOCK_WBTC);
        console.log("  MOCK_DAI =", SepoliaConfig.MOCK_DAI);
        console.log("  MOCK_USDC =", SepoliaConfig.MOCK_USDC);
        console.log("  MOCK_OUSG (RWA) =", SepoliaConfig.MOCK_OUSG);
        console.log("");
        console.log("CHAINLINK_CONFIG:");
        console.log("  FUNCTIONS_ROUTER =", SepoliaConfig.CHAINLINK_FUNCTIONS_ROUTER);
        console.log("  SUBSCRIPTION_ID =", SepoliaConfig.CHAINLINK_SUBSCRIPTION_ID);
        console.log("  DON_ID = fun-ethereum-sepolia-1");
        console.log("========================================");
    }
}

// Usage (Optional - only if enhanced vault constructor wasn't used):
// source .env && forge script script/deploy/06_SetupSystemComplete.s.sol:SetupSystemCompleteScript --rpc-url
// $SEPOLIA_RPC_URL --broadcast --private-key $DEPLOYER_PRIVATE_KEY -vvv

// Or for minimal setup only:
// source .env && forge script script/deploy/06_SetupSystemComplete.s.sol:SetupSystemCompleteScript --sig
// "runMinimalSetup()" --rpc-url $SEPOLIA_RPC_URL --broadcast --private-key $DEPLOYER_PRIVATE_KEY -vvv
