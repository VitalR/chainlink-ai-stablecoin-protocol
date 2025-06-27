// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";

import { AIStablecoin } from "../../src/AIStablecoin.sol";
import { AIStablecoinCCIPBridge } from "../../src/crosschain/AIStablecoinCCIPBridge.sol";
import { FujiConfig } from "../../config/FujiConfig.sol";

/// @title Deploy AI Stablecoin System to Avalanche Fuji
/// @notice Comprehensive deployment script for the complete AI Stablecoin ecosystem on Fuji
/// @dev This deploys both the core system and CCIP bridge for cross-chain functionality
contract DeployToFujiScript is Script {
    // Deployment tracking
    AIStablecoin public aiStablecoin;
    AIStablecoinCCIPBridge public ccipBridge;

    function run() external {
        // Validate we're on Fuji
        require(block.chainid == FujiConfig.CHAIN_ID, "Must deploy on Avalanche Fuji");

        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("=== AI Stablecoin System Deployment to Avalanche Fuji ===");
        console.log("Network:", FujiConfig.getNetworkName());
        console.log("Chain ID:", FujiConfig.CHAIN_ID);
        console.log("Deployer:", deployer);
        console.log("CCIP Router:", FujiConfig.CCIP_ROUTER);
        console.log("LINK Token:", FujiConfig.LINK_TOKEN);
        console.log("");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy AI Stablecoin
        console.log("Deploying AI Stablecoin...");
        aiStablecoin = new AIStablecoin();
        console.log("AI Stablecoin deployed at:", address(aiStablecoin));

        // Deploy CCIP Bridge
        console.log("Deploying CCIP Bridge...");
        ccipBridge = new AIStablecoinCCIPBridge(FujiConfig.CCIP_ROUTER, FujiConfig.LINK_TOKEN, address(aiStablecoin));
        console.log("CCIP Bridge deployed at:", address(ccipBridge));

        // Authorize bridge as vault
        console.log("Authorizing bridge as vault...");
        aiStablecoin.addVault(address(ccipBridge));
        console.log("Bridge authorized as vault");

        // Configure bridge for Sepolia
        console.log("Configuring supported chains...");
        ccipBridge.setSupportedChain(FujiConfig.ETHEREUM_SEPOLIA_SELECTOR, true);
        console.log("Added Ethereum Sepolia as supported source chain");

        vm.stopBroadcast();

        console.log("");
        console.log("=== Deployment Complete ===");
        console.log("AI Stablecoin:", address(aiStablecoin));
        console.log("CCIP Bridge:", address(ccipBridge));
        console.log("");

        _printEnvironmentVariables();
        _printNextSteps();
    }

    function _printEnvironmentVariables() internal view {
        console.log("=== Add to .env ===");
        console.log(string(abi.encodePacked("AI_STABLECOIN_ADDRESS=", vm.toString(address(aiStablecoin)))));
        console.log(
            string(abi.encodePacked("AI_STABLECOIN_BRIDGE_Avalanche_Fuji_ADDRESS=", vm.toString(address(ccipBridge))))
        );
        console.log("");
    }

    function _printNextSteps() internal view {
        console.log("=== Next Steps ===");
        console.log("1. Update FujiConfig.sol with deployed addresses");
        console.log("2. Deploy CCIP bridge on Ethereum Sepolia (if not done)");
        console.log("3. Configure trusted remotes between bridges:");
        console.log("   - Set Sepolia bridge as trusted remote on Fuji");
        console.log("   - Set Fuji bridge as trusted remote on Sepolia");
        console.log("4. Test cross-chain bridging");
        console.log("");
        console.log("=== Bridge Configuration Commands ===");
        console.log("After Sepolia bridge deployment, run:");
        console.log("cast send", vm.toString(address(ccipBridge)));
        console.log("  'setTrustedRemote(uint64,address)'");
        console.log("  ", FujiConfig.ETHEREUM_SEPOLIA_SELECTOR);
        console.log("  <SEPOLIA_BRIDGE_ADDRESS>");
        console.log("  --rpc-url $FUJI_RPC_URL");
        console.log("  --private-key $DEPLOYER_PRIVATE_KEY");
        console.log("");
        console.log("=== Usage Example ===");
        console.log("Bridge 100 AIUSD from Sepolia to Fuji:");
        console.log("1. On Sepolia: Approve bridge to spend AIUSD");
        console.log(
            "2. On Sepolia: Call bridgeTokens(",
            FujiConfig.FUJI_CHAIN_SELECTOR,
            ", recipient, amount, PayFeesIn.Native)"
        );
        console.log("3. AIUSD will be burned on Sepolia and minted on Fuji");
        console.log("");
        console.log("Main Value Proposition:");
        console.log("- AI analysis happens on Sepolia (Chainlink Functions + risk assessment)");
        console.log("- Users can bridge AIUSD to Fuji for better DeFi liquidity");
        console.log("- Access to Avalanche ecosystem: Trader Joe, AAVE, Pangolin");
        console.log("- Lower fees and faster transactions on Avalanche");
    }

    // Helper functions for post-deployment configuration
    function configureTrustedRemote(address sepoliaBridge) external {
        require(block.chainid == FujiConfig.CHAIN_ID, "Must be on Fuji");

        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address bridgeAddress = vm.envAddress("AI_STABLECOIN_BRIDGE_Avalanche_Fuji_ADDRESS");

        vm.startBroadcast(deployerPrivateKey);

        AIStablecoinCCIPBridge bridge = AIStablecoinCCIPBridge(payable(bridgeAddress));
        bridge.setTrustedRemote(FujiConfig.ETHEREUM_SEPOLIA_SELECTOR, sepoliaBridge);

        vm.stopBroadcast();

        console.log("Configured Sepolia bridge as trusted remote:", sepoliaBridge);
    }

    function checkBridgeConfiguration() external view {
        // Try to get bridge address from environment, return early if not set
        try vm.envAddress("AI_STABLECOIN_BRIDGE_Avalanche_Fuji_ADDRESS") returns (address bridgeAddress) {
            AIStablecoinCCIPBridge bridge = AIStablecoinCCIPBridge(payable(bridgeAddress));

            console.log("=== Bridge Configuration Status ===");
            console.log("Bridge Address:", bridgeAddress);
            console.log("Supports Sepolia:", bridge.supportedChains(FujiConfig.ETHEREUM_SEPOLIA_SELECTOR));
            console.log("Trusted Sepolia Bridge:", bridge.trustedRemoteBridges(FujiConfig.ETHEREUM_SEPOLIA_SELECTOR));
            console.log("CCIP Router:", bridge.getRouter());
            console.log("LINK Token:", bridge.getLinkToken());
            console.log("AI Stablecoin:", bridge.getAIStablecoin());
        } catch {
            console.log("=== Bridge Configuration Check ===");
            console.log("Bridge address not found in environment variables.");
            console.log("Please deploy the bridge first using the run() function.");
            console.log("Then add AI_STABLECOIN_BRIDGE_Avalanche_Fuji_ADDRESS to your .env file.");
        }
    }
}
