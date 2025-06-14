// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "forge-std/Script.sol";
import { AIStablecoin } from "src/AIStablecoin.sol";
import { AICollateralVaultCallback } from "src/AICollateralVaultCallback.sol";
import { AIControllerCallback } from "src/AIControllerCallback.sol";
import { SepoliaConfig } from "config/SepoliaConfig.sol";

contract SetupSystemScript is Script {
    address deployerPublicKey;
    uint256 deployerPrivateKey;

    function setUp() public {
        deployerPublicKey = vm.envAddress("DEPLOYER_PUBLIC_KEY");
        deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
    }

    function run() public {
        // Get deployed contract addresses
        address stablecoinAddr = SepoliaConfig.AI_STABLECOIN;
        address controllerAddr = SepoliaConfig.AI_CONTROLLER;
        address payable vaultAddr = payable(SepoliaConfig.AI_VAULT);

        require(stablecoinAddr != address(0), "Stablecoin address not set");
        require(controllerAddr != address(0), "Controller address not set");
        require(vaultAddr != address(0), "Vault address not set");

        vm.startBroadcast(deployerPrivateKey);

        // Initialize contracts
        AIStablecoin stablecoin = AIStablecoin(stablecoinAddr);
        AIControllerCallback controller = AIControllerCallback(controllerAddr);
        AICollateralVaultCallback vault = AICollateralVaultCallback(vaultAddr);

        console.log("=== Setting up system permissions ===");

        // 1. Add vault as authorized minter for stablecoin
        stablecoin.addVault(vaultAddr);
        console.log("[+] Added vault as authorized minter");

        // 2. Authorize vault to call controller
        controller.setAuthorizedCaller(vaultAddr, true);
        console.log("[+] Authorized vault to call controller");

        // 3. Add supported tokens to vault with prices
        console.log("=== Adding supported tokens ===");

        // Add WETH ($2000)
        vault.addSupportedToken(
            SepoliaConfig.MOCK_WETH,
            2500 * 1e18, // $2500 per ETH
            18,
            "WETH"
        );
        console.log("[+] Added WETH support");

        // Add WBTC ($50000)
        vault.addSupportedToken(
            SepoliaConfig.MOCK_WBTC,
            100_000 * 1e18, // $100,000 per BTC
            8,
            "WBTC"
        );
        console.log("[+] Added WBTC support");

        // Add DAI ($1)
        vault.addSupportedToken(
            SepoliaConfig.MOCK_DAI,
            1 * 1e18, // $1 per DAI
            18,
            "DAI"
        );
        console.log("[+] Added DAI support");

        console.log("=== System setup completed ===");
        console.log("Stablecoin: %s", stablecoinAddr);
        console.log("Controller: %s", controllerAddr);
        console.log("Vault: %s", vaultAddr);

        vm.stopBroadcast();
    }
}

// source .env && forge script script/04_SetupSystem.s.sol:SetupSystemScript --rpc-url $SEPOLIA_RPC_URL
// --broadcast --private-key $DEPLOYER_PRIVATE_KEY --etherscan-api-key $ETHERSCAN_API_KEY --gas-limit $GAS_LIMIT
// --gas-price $GAS_PRICE --verify -vvvv
