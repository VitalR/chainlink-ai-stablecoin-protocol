// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "forge-std/Script.sol";
import { AIStablecoin } from "src/AIStablecoin.sol";
import { AIControllerCallback } from "src/AIControllerCallback.sol";
import { AICollateralVaultCallback } from "src/AICollateralVaultCallback.sol";
import { SepoliaConfig } from "config/SepoliaConfig.sol";

/// @title DeployAndSetupConfigurable - Complete fresh deployment with configurable fees
/// @notice Deploys both new controller and new vault with configurable fees, then sets up the complete system
contract DeployAndSetupConfigurableScript is Script {
    AIStablecoin stablecoin;
    AIControllerCallback newController;
    AICollateralVaultCallback newVault;

    address deployerPublicKey;
    uint256 deployerPrivateKey;

    // Configuration constants
    uint256 constant MODEL_ID = 11; // Llama3 8B Instruct
    uint64 constant CALLBACK_GAS_LIMIT = 500_000;
    uint256 constant INITIAL_ORACLE_FEE = 0.01 ether; // 0.01 ETH initial fee

    function setUp() public {
        deployerPublicKey = vm.envAddress("DEPLOYER_PUBLIC_KEY");
        deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");

        // Initialize existing stablecoin contract
        stablecoin = AIStablecoin(SepoliaConfig.AI_STABLECOIN);
    }

    function run() public {
        console.log("=== Deploy Fresh System with Configurable Fees ===");
        console.log("Deployer: %s", deployerPublicKey);
        console.log("Existing stablecoin: %s", address(stablecoin));
        console.log("Oracle address: %s", SepoliaConfig.ORA_ORACLE);

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy new configurable controller
        console.log("=== Deploying New Controller ===");
        newController =
            new AIControllerCallback(SepoliaConfig.ORA_ORACLE, MODEL_ID, CALLBACK_GAS_LIMIT, INITIAL_ORACLE_FEE);
        console.log("==AIControllerCallback addr=%s", address(newController));

        // 2. Deploy new vault with new controller
        console.log("=== Deploying New Vault ===");
        newVault = new AICollateralVaultCallback(address(stablecoin), address(newController));
        console.log("==AICollateralVaultCallback addr=%s", address(newVault));

        // 3. Setup system permissions
        console.log("=== Setting up system permissions ===");

        // Add new vault as authorized minter for stablecoin
        stablecoin.addVault(address(newVault));
        console.log("[+] Added vault as authorized minter");

        // Authorize vault to call controller
        newController.setAuthorizedCaller(address(newVault), true);
        console.log("[+] Authorized vault to call controller");

        // 4. Add supported tokens to vault
        console.log("=== Adding supported tokens ===");

        // Add WETH ($2500)
        newVault.addSupportedToken(SepoliaConfig.MOCK_WETH, 2500 * 1e18, 18, "WETH");
        console.log("[+] Added WETH support");

        // Add WBTC ($100,000)
        newVault.addSupportedToken(SepoliaConfig.MOCK_WBTC, 100_000 * 1e18, 8, "WBTC");
        console.log("[+] Added WBTC support");

        // Add DAI ($1)
        newVault.addSupportedToken(SepoliaConfig.MOCK_DAI, 1 * 1e18, 18, "DAI");
        console.log("[+] Added DAI support");

        // 5. Test configurable fee system
        console.log("=== Testing Configurable Fee System ===");
        uint256 currentFee = newController.estimateTotalFee();
        console.log("Current total fee: %s", currentFee);

        // Test updating oracle fee
        uint256 newOracleFee = 0.005 ether; // 0.005 ETH
        newController.updateOracleFee(newOracleFee);
        uint256 updatedFee = newController.estimateTotalFee();
        console.log("Updated total fee: %s", updatedFee);
        require(updatedFee == newOracleFee, "Fee update test failed");
        console.log("[+] Fee update test passed");

        // Reset to original fee
        newController.updateOracleFee(INITIAL_ORACLE_FEE);
        console.log("[+] Reset fee to 0.01 ETH");

        vm.stopBroadcast();

        // 6. Verify configuration (read-only)
        console.log("=== Verifying Configuration ===");
        console.log("Controller oracle fee: %s", newController.oracleFee());
        console.log("Controller flat fee: %s", newController.flatFee());
        console.log("Controller model ID: %s", newController.modelId());
        console.log("Controller callback gas limit: %s", newController.callbackGasLimit());
        console.log("Vault authorized caller: %s", newController.authorizedCallers(address(newVault)));

        // Verify supported tokens
        console.log("=== Verifying Supported Tokens ===");
        (uint256 wethPrice, uint8 wethDecimals, bool wethSupported) = newVault.supportedTokens(SepoliaConfig.MOCK_WETH);
        console.log("WETH - Price: %s, Decimals: %s, Supported: %s", wethPrice, wethDecimals, wethSupported);

        (uint256 wbtcPrice, uint8 wbtcDecimals, bool wbtcSupported) = newVault.supportedTokens(SepoliaConfig.MOCK_WBTC);
        console.log("WBTC - Price: %s, Decimals: %s, Supported: %s", wbtcPrice, wbtcDecimals, wbtcSupported);

        (uint256 daiPrice, uint8 daiDecimals, bool daiSupported) = newVault.supportedTokens(SepoliaConfig.MOCK_DAI);
        console.log("DAI - Price: %s, Decimals: %s, Supported: %s", daiPrice, daiDecimals, daiSupported);

        console.log("=== Deployment Summary ===");
        console.log("New Controller: %s", address(newController));
        console.log("New Vault: %s", address(newVault));
        console.log("Oracle Fee: %s", newController.oracleFee());
        console.log("System Status: READY");

        console.log("=== Configuration Update Required ===");
        console.log("Update SepoliaConfig.sol with new addresses:");
        console.log("AI_CONTROLLER = %s;", address(newController));
        console.log("AI_VAULT = %s;", address(newVault));

        console.log("[+] Fresh system deployment completed successfully!");
    }
}

// source .env && forge script script/DeployAndSetupConfigurable.s.sol:DeployAndSetupConfigurableScript --rpc-url
// $SEPOLIA_RPC_URL
// --broadcast --private-key $DEPLOYER_PRIVATE_KEY --etherscan-api-key $ETHERSCAN_API_KEY --gas-limit $GAS_LIMIT
// --gas-price $GAS_PRICE --verify -vvvv
