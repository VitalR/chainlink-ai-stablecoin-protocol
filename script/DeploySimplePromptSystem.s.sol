// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "forge-std/Script.sol";
import { AIStablecoin } from "src/AIStablecoin.sol";
import { AISimplePromptController } from "src/AISimplePromptController.sol";
import { AICollateralVaultSimple } from "src/AICollateralVaultSimple.sol";
import { AIEventProcessor } from "src/AIEventProcessor.sol";
import { SepoliaConfig } from "config/SepoliaConfig.sol";

/// @title DeploySimplePromptSystem - Deploy the SimplePrompt-based AI stablecoin system
/// @notice Deploys all contracts for the event-based AI processing system
contract DeploySimplePromptSystemScript is Script {
    // Deployment addresses
    AIStablecoin aiusd;
    AISimplePromptController controller;
    AICollateralVaultSimple vault;
    AIEventProcessor processor;

    // Configuration
    address constant ORA_ORACLE_SEPOLIA = 0x0A0f4321214BB6C7811dD8a71cF587bdaF03f0A0;
    uint256 constant MODEL_ID = 11; // Llama3 8B Instruct
    uint64 constant CALLBACK_GAS_LIMIT = 200_000; // Lower gas for SimplePrompt
    uint256 constant ORACLE_FEE = 0.01 ether; // Sepolia testnet fee

    address deployerPublicKey;
    uint256 deployerPrivateKey;

    function setUp() public {
        deployerPublicKey = vm.envAddress("DEPLOYER_PUBLIC_KEY");
        deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
    }

    function run() public {
        vm.startBroadcast(deployerPrivateKey);

        console.log("=== Deploying SimplePrompt AI Stablecoin System ===");
        console.log("Deployer:", deployerPublicKey);
        console.log("ORA Oracle:", ORA_ORACLE_SEPOLIA);

        // 1. Deploy AI Stablecoin (reuse existing if available)
        if (SepoliaConfig.AI_STABLECOIN != address(0)) {
            aiusd = AIStablecoin(SepoliaConfig.AI_STABLECOIN);
            console.log("Using existing AIUSD:", address(aiusd));
        } else {
            aiusd = new AIStablecoin();
            console.log("Deployed AIUSD:", address(aiusd));
        }

        // 2. Deploy SimplePrompt Controller
        controller = new AISimplePromptController(ORA_ORACLE_SEPOLIA, MODEL_ID, CALLBACK_GAS_LIMIT, ORACLE_FEE);
        console.log("Deployed SimplePrompt Controller:", address(controller));

        // 3. Deploy SimplePrompt Vault
        vault = new AICollateralVaultSimple(address(aiusd), address(controller));
        console.log("Deployed SimplePrompt Vault:", address(vault));

        // 4. Deploy Event Processor
        processor = new AIEventProcessor(address(controller), payable(address(vault)));
        console.log("Deployed Event Processor:", address(processor));

        // 5. Configure permissions
        console.log("\n=== Configuring Permissions ===");

        // Authorize vault to call controller
        controller.setAuthorizedCaller(address(vault), true);
        console.log("Authorized vault to call controller");

        // Authorize processor to process vault requests
        vault.setAuthorizedProcessor(address(processor), true);
        console.log("Authorized processor to process vault requests");

        // Give vault minting permission on AIUSD
        aiusd.addVault(address(vault));
        console.log("Added vault as authorized minter");

        // 6. Add test tokens (if not already added)
        console.log("\n=== Adding Test Tokens ===");

        // Add WETH
        try vault.addToken(SepoliaConfig.MOCK_WETH, 2500 * 1e18, 18, "WETH") {
            console.log("Added WETH token");
        } catch {
            console.log("WETH token already exists or failed to add");
        }

        // Add DAI
        try vault.addToken(SepoliaConfig.MOCK_DAI, 1 * 1e18, 18, "DAI") {
            console.log("Added DAI token");
        } catch {
            console.log("DAI token already exists or failed to add");
        }

        // Add WBTC
        try vault.addToken(SepoliaConfig.MOCK_WBTC, 45_000 * 1e18, 8, "WBTC") {
            console.log("Added WBTC token");
        } catch {
            console.log("WBTC token already exists or failed to add");
        }

        console.log("\n=== Deployment Summary ===");
        console.log("AIUSD Stablecoin:", address(aiusd));
        console.log("SimplePrompt Controller:", address(controller));
        console.log("SimplePrompt Vault:", address(vault));
        console.log("Event Processor:", address(processor));

        console.log("\n=== Usage Instructions ===");
        console.log("1. Users call vault.depositBasket() to deposit collateral");
        console.log("2. AI request is submitted automatically (emits events)");
        console.log("3. Anyone can call processor.processAndFinalize() with event data");
        console.log("4. AIUSD is minted to the user");

        console.log("\n=== Gas Savings ===");
        console.log("- SimplePrompt uses ~200k gas vs 500k for callbacks");
        console.log("- Event-based processing allows batch operations");
        console.log("- Permissionless processing enables decentralized operation");

        vm.stopBroadcast();
    }

    /// @notice Helper function to estimate deployment costs
    function estimateDeploymentCost() public view returns (uint256) {
        // Rough estimates based on contract sizes
        uint256 controllerCost = 2_000_000; // ~2M gas
        uint256 vaultCost = 3_000_000; // ~3M gas
        uint256 processorCost = 1_500_000; // ~1.5M gas
        uint256 configurationCost = 500_000; // ~500k gas

        return controllerCost + vaultCost + processorCost + configurationCost;
    }
}

// Usage:
// source .env && forge script script/DeploySimplePromptSystem.s.sol:DeploySimplePromptSystemScript --fork-url
// $SEPOLIA_RPC_URL --broadcast --verify -vv
