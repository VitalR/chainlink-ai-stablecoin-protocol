// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";
import { AIStablecoinCCIPBridge } from "../../src/crosschain/AIStablecoinCCIPBridge.sol";

/// @title Deploy CCIP Bridge Script
/// @notice Deploys CCIP bridge contracts for cross-chain AIUSD transfers to Avalanche testnet
contract DeployCCIPBridgeScript is Script {
    // =============================================================
    //                    NETWORK CONFIGURATIONS
    // =============================================================

    struct NetworkConfig {
        address ccipRouter;
        address linkToken;
        uint64 chainSelector;
        string name;
    }

    mapping(uint256 => NetworkConfig) public networkConfigs;

    // =============================================================
    //                    INITIALIZATION
    // =============================================================

    constructor() {
        // Ethereum Sepolia (where AI analysis happens)
        networkConfigs[11_155_111] = NetworkConfig({
            ccipRouter: 0x0BF3dE8c5D3e8A2B34D2BEeB17ABfCeBaf363A59,
            linkToken: 0x779877A7B0D9E8603169DdbD7836e478b4624789,
            chainSelector: 16_015_286_601_757_825_753,
            name: "Ethereum Sepolia"
        });

        // Avalanche Fuji (main destination - hackathon partner)
        networkConfigs[43_113] = NetworkConfig({
            ccipRouter: 0xF694E193200268f9a4868e4Aa017A0118C9a8177,
            linkToken: 0x0b9d5D9136855f6FEc3c0993feE6E9CE8a297846,
            chainSelector: 14_767_482_510_784_806_043,
            name: "Avalanche Fuji"
        });

        // Arbitrum Sepolia (additional option)
        networkConfigs[421_614] = NetworkConfig({
            ccipRouter: 0x2a9C5afB0d0e4BAb2BCdaE109EC4b0c4Be15a165,
            linkToken: 0xb1D4538B4571d411F07960EF2838Ce337FE1E80E,
            chainSelector: 3_478_487_238_524_512_106,
            name: "Arbitrum Sepolia"
        });
    }

    // =============================================================
    //                    DEPLOYMENT LOGIC
    // =============================================================

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address aiStablecoinAddress = vm.envAddress("AI_STABLECOIN_ADDRESS");

        NetworkConfig memory config = networkConfigs[block.chainid];
        require(config.ccipRouter != address(0), "Network not supported");

        console.log("=== AI Stablecoin CCIP Bridge Deployment ===");
        console.log("Network:", config.name);
        console.log("Chain ID:", block.chainid);
        console.log("CCIP Router:", config.ccipRouter);
        console.log("LINK Token:", config.linkToken);
        console.log("AI Stablecoin:", aiStablecoinAddress);
        console.log("Chain Selector:", config.chainSelector);

        if (block.chainid == 11_155_111) {
            console.log("Primary use case: Bridge AIUSD liquidity TO Avalanche Fuji");
        } else if (block.chainid == 43_113) {
            console.log("Avalanche Fuji: Receive AIUSD liquidity FROM Sepolia");
        }

        vm.startBroadcast(deployerPrivateKey);

        // Deploy AI Stablecoin CCIP Bridge
        AIStablecoinCCIPBridge bridge =
            new AIStablecoinCCIPBridge(config.ccipRouter, config.linkToken, aiStablecoinAddress);

        vm.stopBroadcast();

        console.log("AI Stablecoin CCIP Bridge deployed at:", address(bridge));
        console.log("");
        console.log("Next Steps:");
        console.log("1. Run authorization script to authorize bridge as vault");
        console.log("2. Configure supported chains and trusted remotes");
        console.log("3. Deploy matching bridge on destination chains");
        console.log("");
        console.log("Main Feature:");
        console.log("   Bridge AIUSD from Sepolia (AI analysis) to Avalanche (liquidity)");

        // Save deployment info for post-deployment setup
        string memory deploymentInfo =
            string(abi.encodePacked("AI_STABLECOIN_BRIDGE_", config.name, "_ADDRESS=", vm.toString(address(bridge))));
        console.log("");
        console.log("Add to .env:");
        console.log(deploymentInfo);
    }

    // =============================================================
    //                    UTILITY FUNCTIONS
    // =============================================================

    function getNetworkConfig(uint256 chainId) external view returns (NetworkConfig memory) {
        return networkConfigs[chainId];
    }

    function getSupportedNetworks() external view returns (uint256[] memory) {
        uint256[] memory supportedChains = new uint256[](3);
        supportedChains[0] = 11_155_111; // Ethereum Sepolia
        supportedChains[1] = 43_113; // Avalanche Fuji (main target)
        supportedChains[2] = 421_614; // Arbitrum Sepolia
        return supportedChains;
    }
}
