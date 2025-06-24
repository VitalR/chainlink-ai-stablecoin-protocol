// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "forge-std/Script.sol";
import { CollateralVault } from "src/CollateralVault.sol";
import { AutoEmergencyWithdrawal } from "src/automation/AutoEmergencyWithdrawal.sol";
import { SepoliaConfig } from "config/SepoliaConfig.sol";

contract DeployVaultScript is Script {
    CollateralVault vault;
    AutoEmergencyWithdrawal automation;
    address deployerPublicKey;
    uint256 deployerPrivateKey;

    function setUp() public {
        deployerPublicKey = vm.envAddress("DEPLOYER_PUBLIC_KEY");
        deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
    }

    function run() public {
        // Load deployed contract addresses
        address aiusdAddr = SepoliaConfig.AI_STABLECOIN;
        address controllerAddr = SepoliaConfig.RISK_ORACLE_CONTROLLER;
        address existingAutomationAddr = SepoliaConfig.AUTO_EMERGENCY_WITHDRAWAL;

        require(aiusdAddr != address(0), "AIUSD address not set in config");
        require(controllerAddr != address(0), "Controller address not set in config");

        // Note: Automation address can be address(0) if not deployed yet

        vm.startBroadcast(deployerPrivateKey);

        // Prepare token configurations with price feeds
        CollateralVault.TokenConfig[] memory tokenConfigs = _prepareTokenConfigs();

        console.log("==Deploying with contract addresses:");
        console.log("  AIUSD: %s", aiusdAddr);
        console.log("  Controller: %s", controllerAddr);
        console.log("  Existing Automation: %s", existingAutomationAddr);

        // Deploy vault with enhanced constructor
        // NOTE: This authorizes the existing automation contract during deployment (if it exists)
        vault = new CollateralVault(
            aiusdAddr, // AIUSD stablecoin contract
            controllerAddr, // Risk oracle controller
            existingAutomationAddr, // Pre-deployed automation contract (can be address(0))
            tokenConfigs // Pre-configure all supported tokens
        );

        console.log("==CollateralVault deployed at=%s", address(vault));

        if (existingAutomationAddr != address(0)) {
            console.log("==Pre-deployed automation contract authorized: %s", existingAutomationAddr);
        } else {
            console.log("==No automation contract provided - can be authorized later");
        }

        // OPTIONAL: Deploy a new automation contract for this specific vault
        // (This demonstrates the pattern, but we should use the existing one if available)
        automation = new AutoEmergencyWithdrawal(address(vault));
        console.log("==New AutoEmergencyWithdrawal deployed at=%s", address(automation));

        // Authorize the new automation contract as well (for demonstration)
        vault.setAutomationAuthorized(address(automation), true);
        console.log("==New automation contract also authorized in vault");

        console.log("==Tokens pre-configured: DAI, WETH, WBTC, USDC, OUSG");
        console.log("==All tokens configured with dynamic price feeds");

        vm.stopBroadcast();

        console.log("\n==DEPLOYMENT SUMMARY==");
        console.log("1. Vault deployed with enhanced automation support");
        if (existingAutomationAddr != address(0)) {
            console.log("2. Pre-existing automation contract authorized");
        } else {
            console.log("2. No pre-existing automation (deploy automation first for better integration)");
        }
        console.log("3. Additional automation contract deployed and authorized");
        console.log("4. All tokens pre-configured with Chainlink price feeds");

        console.log("\n==NEXT STEPS==");
        console.log("1. Update SepoliaConfig.sol with new vault address:");
        console.log("   COLLATERAL_VAULT = %s", address(vault));
        console.log("2. Run step 05 to authorize vault:");
        console.log("   forge script script/deploy/05_AuthorizeVault.s.sol --broadcast");
        console.log("3. Register automation at: https://automation.chain.link/sepolia");
        console.log("   Contract: %s", address(automation));
        console.log("4. Users can call optInToAutomation() immediately");
        console.log("5. System ready with full Chainlink Automation integration!");
    }

    /// @notice Prepare comprehensive token configuration for Sepolia
    function _prepareTokenConfigs() internal pure returns (CollateralVault.TokenConfig[] memory) {
        CollateralVault.TokenConfig[] memory configs = new CollateralVault.TokenConfig[](5);

        // WETH with price feed
        configs[0] = CollateralVault.TokenConfig({
            token: SepoliaConfig.MOCK_WETH,
            priceUSD: 3500e18, // $3500 ETH (fallback)
            decimals: 18,
            symbol: "WETH",
            priceFeed: SepoliaConfig.ETH_USD_PRICE_FEED // Dynamic pricing
         });

        // WBTC with price feed
        configs[1] = CollateralVault.TokenConfig({
            token: SepoliaConfig.MOCK_WBTC,
            priceUSD: 95_000e18, // $95000 BTC (fallback)
            decimals: 8,
            symbol: "WBTC",
            priceFeed: SepoliaConfig.BTC_USD_PRICE_FEED // Dynamic pricing
         });

        // DAI with price feed
        configs[2] = CollateralVault.TokenConfig({
            token: SepoliaConfig.MOCK_DAI,
            priceUSD: 1e18, // $1 DAI (fallback)
            decimals: 18,
            symbol: "DAI",
            priceFeed: SepoliaConfig.DAI_USD_PRICE_FEED // Dynamic pricing
         });

        // USDC with price feed
        configs[3] = CollateralVault.TokenConfig({
            token: SepoliaConfig.MOCK_USDC,
            priceUSD: 1e18, // $1 USDC (fallback)
            decimals: 6,
            symbol: "USDC",
            priceFeed: SepoliaConfig.USDC_USD_PRICE_FEED // Dynamic pricing
         });

        // OUSG (RWA) with price feed
        configs[4] = CollateralVault.TokenConfig({
            token: SepoliaConfig.MOCK_OUSG,
            priceUSD: 100e18, // $100 OUSG (fallback)
            decimals: 18,
            symbol: "OUSG",
            priceFeed: SepoliaConfig.OUSG_USD_PRICE_FEED // Dynamic pricing for RWA
         });

        return configs;
    }
}

// Usage:
// source .env && forge script script/deploy/04_DeployVault.s.sol:DeployVaultScript --rpc-url $SEPOLIA_RPC_URL
// --broadcast --private-key $DEPLOYER_PRIVATE_KEY --etherscan-api-key $ETHERSCAN_API_KEY --verify -vvvv
