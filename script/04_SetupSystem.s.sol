// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "forge-std/Script.sol";
import { AIStablecoin } from "src/AIStablecoin.sol";
import { CollateralVault } from "src/CollateralVault.sol";
import { AIController } from "src/AIController.sol";
import { SepoliaConfig } from "config/SepoliaConfig.sol";

/// @title SetupSystem - Configure the deployed AI Stablecoin system
/// @notice Sets up permissions and token prices for the new deployment
contract SetupSystemScript is Script {
    AIStablecoin aiusd;
    CollateralVault vault;
    AIController controller;

    address deployerPublicKey;
    uint256 deployerPrivateKey;

    function setUp() public {
        deployerPublicKey = vm.envAddress("DEPLOYER_PUBLIC_KEY");
        deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");

        // Initialize contracts
        aiusd = AIStablecoin(SepoliaConfig.AI_STABLECOIN);
        vault = CollateralVault(payable(SepoliaConfig.AI_VAULT));
        controller = AIController(SepoliaConfig.AI_CONTROLLER);
    }

    function run() public {
        vm.startBroadcast(deployerPrivateKey);

        console.log("=== AI Stablecoin System Setup ===");
        console.log("Stablecoin:", address(aiusd));
        console.log("Controller:", address(controller));
        console.log("Vault:", address(vault));

        // 1. Add vault to stablecoin (allows minting)
        console.log("\n1. Adding vault to stablecoin...");
        aiusd.addVault(address(vault));
        console.log("Vault added to stablecoin");

        // 2. Set vault as authorized caller in controller
        console.log("\n2. Authorizing vault in controller...");
        controller.setAuthorizedCaller(address(vault), true);
        console.log("Vault authorized in controller");

        // 3. Add token prices to vault
        console.log("\n3. Adding token prices to vault...");

        // Add WETH: $2000 per ETH
        vault.addToken(
            SepoliaConfig.MOCK_WETH,
            2000 * 1e18, // $2000 with 18 decimals
            18, // WETH decimals
            "WETH"
        );
        console.log("WETH added: $2000");

        // Add WBTC: $50000 per BTC
        vault.addToken(
            SepoliaConfig.MOCK_WBTC,
            50_000 * 1e18, // $50000 with 18 decimals
            8, // WBTC decimals (8)
            "WBTC"
        );
        console.log("WBTC added: $50000");

        // Add DAI: $1 per DAI
        vault.addToken(
            SepoliaConfig.MOCK_DAI,
            1 * 1e18, // $1 with 18 decimals
            18, // DAI decimals
            "DAI"
        );
        console.log("DAI added: $1");

        console.log("\n=== Setup Complete ===");
        console.log("System is ready for deposits!");

        // Display key addresses
        console.log("\n=== Key Addresses ===");
        console.log("AI Stablecoin:", address(aiusd));
        console.log("AI Controller:", address(controller));
        console.log("Collateral Vault:", address(vault));
        console.log("ORA Oracle:", SepoliaConfig.ORA_ORACLE);
        console.log("\nTest Tokens:");
        console.log("WETH:", SepoliaConfig.MOCK_WETH);
        console.log("WBTC:", SepoliaConfig.MOCK_WBTC);
        console.log("DAI:", SepoliaConfig.MOCK_DAI);

        vm.stopBroadcast();
    }
}
