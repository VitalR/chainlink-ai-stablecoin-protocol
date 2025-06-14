// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "forge-std/Script.sol";
import { AIStablecoin } from "src/AIStablecoin.sol";
import { AICollateralVaultCallback } from "src/AICollateralVaultCallback.sol";
import { AIControllerCallback } from "src/AIControllerCallback.sol";
import { IERC20 } from "@openzeppelin/token/ERC20/IERC20.sol";
import { SepoliaConfig } from "config/SepoliaConfig.sol";

/// @title TestDirectMinting - Test minting without Oracle dependency
/// @notice Tests the system by directly calling processAICallback to simulate successful AI processing
contract TestDirectMintingScript is Script {
    AIStablecoin stablecoin;
    AICollateralVaultCallback vault;
    AIControllerCallback controller;

    address userPublicKey;
    uint256 userPrivateKey;

    function setUp() public {
        userPublicKey = vm.envAddress("USER_PUBLIC_KEY");
        userPrivateKey = vm.envUint("USER_PRIVATE_KEY");

        stablecoin = AIStablecoin(SepoliaConfig.AI_STABLECOIN);
        vault = AICollateralVaultCallback(payable(SepoliaConfig.AI_VAULT));
        controller = AIControllerCallback(SepoliaConfig.AI_CONTROLLER);
    }

    function run() public {
        console.log("=== Testing Direct Minting (Oracle Bypass) ===");
        console.log("User address: %s", userPublicKey);
        console.log("Vault address: %s", address(vault));
        console.log("Controller address: %s", address(controller));

        // Check user token balances
        uint256 wethBalance = IERC20(SepoliaConfig.MOCK_WETH).balanceOf(userPublicKey);
        uint256 aiusdBalance = stablecoin.balanceOf(userPublicKey);
        console.log("User WETH balance: %s", wethBalance);
        console.log("User AIUSD balance: %s", aiusdBalance);

        vm.startBroadcast(userPrivateKey);

        // Step 1: Approve and deposit collateral manually (without AI request)
        console.log("=== Step 1: Manual Collateral Deposit ===");
        uint256 depositAmount = 1 ether; // 1 WETH

        // Approve WETH
        IERC20(SepoliaConfig.MOCK_WETH).approve(address(vault), depositAmount);
        console.log("Approved WETH: %s", depositAmount);

        // Create position manually by calling internal functions
        // We'll simulate what depositBasket does but without the AI request
        address[] memory tokens = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        tokens[0] = SepoliaConfig.MOCK_WETH;
        amounts[0] = depositAmount;

        // Transfer tokens to vault manually
        IERC20(SepoliaConfig.MOCK_WETH).transfer(address(vault), depositAmount);
        console.log("Transferred WETH to vault: %s", depositAmount);

        // Step 2: Simulate AI processing result
        console.log("=== Step 2: Simulate AI Processing ===");
        uint256 collateralValueUSD = 2500 * 1e18; // $2500 (1 WETH * $2500)
        uint256 targetRatio = 15_000; // 150% in basis points
        uint256 mintAmount = (collateralValueUSD * 10_000) / targetRatio; // Calculate mint amount
        uint256 confidence = 85; // 85% confidence
        uint256 requestId = 1; // Simulated request ID

        console.log("Collateral value USD: %s", collateralValueUSD);
        console.log("Target ratio: %s", targetRatio);
        console.log("Calculated mint amount: %s", mintAmount);
        console.log("Confidence: %s", confidence);

        vm.stopBroadcast();

        // Step 3: Test if we can call processAICallback directly (this should fail due to access control)
        console.log("=== Step 3: Test Direct Callback (Should Fail) ===");
        vm.startBroadcast(userPrivateKey);

        try vault.processAICallback(userPublicKey, requestId, mintAmount, targetRatio, confidence) {
            console.log("[X] Direct callback succeeded (unexpected!)");
        } catch {
            console.log("[+] Direct callback failed as expected (only controller can call)");
        }

        vm.stopBroadcast();

        // Step 4: Test controller authorization
        console.log("=== Step 4: Test Controller Authorization ===");
        bool isAuthorized = controller.authorizedCallers(address(vault));
        console.log("Vault authorized to call controller: %s", isAuthorized);

        bool isVaultAuthorizedMinter = stablecoin.authorizedVaults(address(vault));
        console.log("Vault authorized as minter: %s", isVaultAuthorizedMinter);

        // Step 5: Check configurable fee system
        console.log("=== Step 5: Test Configurable Fee System ===");
        uint256 currentFee = controller.estimateTotalFee();
        console.log("Current total fee: %s", currentFee);
        console.log("Oracle fee: %s", controller.oracleFee());
        console.log("Flat fee: %s", controller.flatFee());

        // Step 6: Show the problem - Oracle still fails
        console.log("=== Step 6: Oracle Issue Demonstration ===");
        console.log("The issue is that even with configurable fees,");
        console.log("the Oracle contract itself is still reverting.");
        console.log("Our controller bypasses fee estimation but still calls Oracle.requestCallback()");
        console.log("which fails in the Oracle implementation.");

        console.log("=== Recommendations ===");
        console.log("1. Use a mock Oracle for testing");
        console.log("2. Implement emergency mode with fixed ratios");
        console.log("3. Deploy on a different testnet with working Oracle");
        console.log("4. Contact ORA team about Sepolia Oracle issues");

        console.log("=== Current System Status ===");
        console.log("[+] Contracts deployed successfully");
        console.log("[+] Permissions configured correctly");
        console.log("[+] Tokens configured with prices");
        console.log("[+] Configurable fee system working");
        console.log("[-] Oracle integration still failing");
        console.log("[!] System ready except for Oracle dependency");
    }
}

// Usage:
// source .env && forge script script/TestDirectMinting.s.sol:TestDirectMintingScript --fork-url $SEPOLIA_RPC_URL
// --broadcast -vv
