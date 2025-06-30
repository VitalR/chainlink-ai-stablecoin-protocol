// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";

import { AIStablecoinCCIPBridge } from "../../src/crosschain/AIStablecoinCCIPBridge.sol";
import { AIStablecoin } from "../../src/AIStablecoin.sol";
import { SepoliaConfig } from "../../config/SepoliaConfig.sol";
import { FujiConfig } from "../../config/FujiConfig.sol";

/// @title Setup CCIP Bridge Script
/// @notice Configures deployed CCIP bridges for cross-chain communication using config files
/// @dev This script sets up the production bridge configuration with verified addresses
contract SetupCCIPBridgeScript is Script {
    function run() external {
        // Get environment variables
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");

        console.log("=== AI Stablecoin CCIP Bridge Setup ===");
        console.log("Chain ID:", block.chainid);
        console.log("");

        // Determine which network we're on and configure accordingly
        if (block.chainid == SepoliaConfig.CHAIN_ID) {
            // Ethereum Sepolia
            setupEthereumSepolia();
        } else if (block.chainid == FujiConfig.CHAIN_ID) {
            // Avalanche Fuji
            setupAvalancheFuji();
        } else {
            revert("Unsupported network - only Sepolia and Fuji supported");
        }
    }

    function setupEthereumSepolia() internal {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        
        console.log("=== Configuring Ethereum Sepolia Bridge ===");
        console.log("Bridge Address:", SepoliaConfig.AI_STABLECOIN_BRIDGE);
        console.log("AIUSD Address:", SepoliaConfig.AI_STABLECOIN);
        console.log("Target: Avalanche Fuji Chain");
        console.log("");

        // Verify contracts exist
        require(SepoliaConfig.AI_STABLECOIN_BRIDGE.code.length > 0, "Sepolia bridge contract not deployed");
        require(SepoliaConfig.AI_STABLECOIN.code.length > 0, "Sepolia AIUSD contract not deployed");

        vm.startBroadcast(deployerPrivateKey);

        // Get contracts
        AIStablecoinCCIPBridge bridge = AIStablecoinCCIPBridge(payable(SepoliaConfig.AI_STABLECOIN_BRIDGE));
        AIStablecoin stablecoin = AIStablecoin(SepoliaConfig.AI_STABLECOIN);

        console.log("Step 1: Authorizing bridge as vault...");

        // Authorize bridge as vault (if not already authorized)
        if (!stablecoin.authorizedVaults(SepoliaConfig.AI_STABLECOIN_BRIDGE)) {
            stablecoin.addVault(SepoliaConfig.AI_STABLECOIN_BRIDGE);
            console.log("[SUCCESS] Bridge authorized as vault - can now burn/mint AIUSD");
        } else {
            console.log("[INFO] Bridge already authorized as vault");
        }

        console.log("Step 2: Configuring cross-chain connections...");

        // Configure supported destination chains
        bridge.setSupportedChain(FujiConfig.FUJI_CHAIN_SELECTOR, true);
        console.log("[SUCCESS] Added Avalanche Fuji as supported destination");
        console.log("         Chain Selector:", FujiConfig.FUJI_CHAIN_SELECTOR);

        // Set trusted remote bridge
        bridge.setTrustedRemote(FujiConfig.FUJI_CHAIN_SELECTOR, FujiConfig.AI_STABLECOIN_CCIP_BRIDGE);
        console.log("[SUCCESS] Set Fuji bridge as trusted remote");
        console.log("         Remote Bridge:", FujiConfig.AI_STABLECOIN_CCIP_BRIDGE);

        vm.stopBroadcast();

        console.log("");
        console.log("=== Sepolia Bridge Configuration Complete ===");
        console.log("[OK] Bridge can burn AIUSD on Sepolia");
        console.log("[OK] Cross-chain messages can be sent to Fuji");
        console.log("[OK] Trusted remote relationship established");
        console.log("");
        verifySepoliaConfiguration(bridge, stablecoin);
    }

    function setupAvalancheFuji() internal {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");

        console.log("=== Configuring Avalanche Fuji Bridge ===");
        console.log("Bridge Address:", FujiConfig.AI_STABLECOIN_CCIP_BRIDGE);
        console.log("AIUSD Address:", FujiConfig.AI_STABLECOIN);
        console.log("Source: Ethereum Sepolia Chain");
        console.log("");

        // Verify contracts exist
        require(FujiConfig.AI_STABLECOIN_CCIP_BRIDGE.code.length > 0, "Fuji bridge contract not deployed");
        require(FujiConfig.AI_STABLECOIN.code.length > 0, "Fuji AIUSD contract not deployed");

        vm.startBroadcast(deployerPrivateKey);

        // Get contracts
        AIStablecoinCCIPBridge bridge = AIStablecoinCCIPBridge(payable(FujiConfig.AI_STABLECOIN_CCIP_BRIDGE));
        AIStablecoin stablecoin = AIStablecoin(FujiConfig.AI_STABLECOIN);

        console.log("Step 1: Authorizing bridge as vault...");

        // Authorize bridge as vault (if not already authorized)
        if (!stablecoin.authorizedVaults(FujiConfig.AI_STABLECOIN_CCIP_BRIDGE)) {
            stablecoin.addVault(FujiConfig.AI_STABLECOIN_CCIP_BRIDGE);
            console.log("[SUCCESS] Bridge authorized as vault - can now mint AIUSD");
        } else {
            console.log("[INFO] Bridge already authorized as vault");
        }

        console.log("Step 2: Configuring cross-chain connections...");

        // Configure supported source chains
        bridge.setSupportedChain(FujiConfig.ETHEREUM_SEPOLIA_SELECTOR, true);
        console.log("[SUCCESS] Added Ethereum Sepolia as supported source");
        console.log("         Chain Selector:", FujiConfig.ETHEREUM_SEPOLIA_SELECTOR);

        // Set trusted remote bridge
        bridge.setTrustedRemote(FujiConfig.ETHEREUM_SEPOLIA_SELECTOR, SepoliaConfig.AI_STABLECOIN_BRIDGE);
        console.log("[SUCCESS] Set Sepolia bridge as trusted remote");
        console.log("         Remote Bridge:", SepoliaConfig.AI_STABLECOIN_BRIDGE);

        vm.stopBroadcast();

        console.log("");
        console.log("=== Fuji Bridge Configuration Complete ===");
        console.log("[OK] Bridge can mint AIUSD on Fuji");
        console.log("[OK] Cross-chain messages accepted from Sepolia");
        console.log("[OK] Trusted remote relationship established");
        console.log("");
        verifyFujiConfiguration(bridge, stablecoin);
    }

    function verifySepoliaConfiguration(AIStablecoinCCIPBridge bridge, AIStablecoin stablecoin) internal view {
        console.log("=== Verification: Sepolia Bridge Status ===");

        // Check vault authorization
        bool isAuthorized = stablecoin.authorizedVaults(address(bridge));
        console.log("Bridge Vault Authorization:", isAuthorized ? "[PASS] AUTHORIZED" : "[FAIL] NOT AUTHORIZED");

        // Check supported chains
        bool isFujiSupported = bridge.supportedChains(FujiConfig.FUJI_CHAIN_SELECTOR);
        console.log("Fuji Chain Supported:", isFujiSupported ? "[PASS] SUPPORTED" : "[FAIL] NOT SUPPORTED");

        // Check trusted remotes
        address trustedFujiBridge = bridge.trustedRemoteBridges(FujiConfig.FUJI_CHAIN_SELECTOR);
        bool isTrustedCorrect = (trustedFujiBridge == FujiConfig.AI_STABLECOIN_CCIP_BRIDGE);
        console.log("Trusted Fuji Bridge:", isTrustedCorrect ? "[PASS] CONFIGURED" : "[FAIL] NOT CONFIGURED");
        console.log("         Expected:", FujiConfig.AI_STABLECOIN_CCIP_BRIDGE);
        console.log("         Actual:  ", trustedFujiBridge);

        console.log("");
        if (isAuthorized && isFujiSupported && isTrustedCorrect) {
            console.log("[READY] SEPOLIA BRIDGE READY FOR PRODUCTION");
            console.log("        Users can bridge AIUSD: Sepolia -> Fuji");
        } else {
            console.log("[ERROR] Configuration incomplete - check failed items above");
        }
    }

    function verifyFujiConfiguration(AIStablecoinCCIPBridge bridge, AIStablecoin stablecoin) internal view {
        console.log("=== Verification: Fuji Bridge Status ===");

        // Check vault authorization
        bool isAuthorized = stablecoin.authorizedVaults(address(bridge));
        console.log("Bridge Vault Authorization:", isAuthorized ? "[PASS] AUTHORIZED" : "[FAIL] NOT AUTHORIZED");
        
        // Check supported chains
        bool isSepoliaSupported = bridge.supportedChains(FujiConfig.ETHEREUM_SEPOLIA_SELECTOR);
        console.log("Sepolia Chain Supported:", isSepoliaSupported ? "[PASS] SUPPORTED" : "[FAIL] NOT SUPPORTED");

        // Check trusted remotes
        address trustedSepolia = bridge.trustedRemoteBridges(FujiConfig.ETHEREUM_SEPOLIA_SELECTOR);
        bool isTrustedCorrect = (trustedSepolia == SepoliaConfig.AI_STABLECOIN_BRIDGE);
        console.log("Trusted Sepolia Bridge:", isTrustedCorrect ? "[PASS] CONFIGURED" : "[FAIL] NOT CONFIGURED");
        console.log("         Expected:", SepoliaConfig.AI_STABLECOIN_BRIDGE);
        console.log("         Actual:  ", trustedSepolia);

        console.log("");
        if (isAuthorized && isSepoliaSupported && isTrustedCorrect) {
            console.log("[READY] FUJI BRIDGE READY FOR PRODUCTION");
            console.log("        Bridge can receive AIUSD from Sepolia");
            console.log("        Users can bridge AIUSD: Fuji -> Sepolia");
        } else {
            console.log("[ERROR] Configuration incomplete - check failed items above");
        }

        console.log("");
        console.log("=== CROSS-CHAIN BRIDGE STATUS ===");
        console.log("    Bidirectional bridging enabled");
        console.log("    Burn-and-mint security model active");
        console.log("    Production addresses from config");
    }
}
