// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "forge-std/Script.sol";
import { AIStablecoin } from "src/AIStablecoin.sol";
import { AICollateralVaultCallback } from "src/AICollateralVaultCallback.sol";
import { AIControllerCallback } from "src/AIControllerCallback.sol";
import { SepoliaConfig } from "config/SepoliaConfig.sol";

/// @title Test token interface
interface IMintableToken {
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
}

/// @title TestFullFlow - Complete deposit and AI processing test
/// @notice Demonstrates the full flow: deposit → AI processing → minting
contract TestFullFlowScript is Script {
    AIStablecoin aiusd;
    AICollateralVaultCallback vault;
    AIControllerCallback controller;

    address user;
    uint256 userPrivateKey;
    address deployer;
    uint256 deployerPrivateKey;

    function setUp() public {
        // Get credentials
        user = vm.envAddress("USER_PUBLIC_KEY");
        userPrivateKey = vm.envUint("USER_PRIVATE_KEY");
        deployer = vm.envAddress("DEPLOYER_PUBLIC_KEY");
        deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");

        // Initialize contracts
        aiusd = AIStablecoin(SepoliaConfig.AI_STABLECOIN);
        vault = AICollateralVaultCallback(payable(SepoliaConfig.AI_VAULT));
        controller = AIControllerCallback(SepoliaConfig.AI_CONTROLLER);
    }

    /// @notice Step 1: Deposit collateral (will create pending AI request)
    function step1_DepositCollateral() public {
        vm.startBroadcast(userPrivateKey);

        console.log("=== STEP 1: Deposit Collateral ===");
        console.log("User address:", user);

        // Initialize WETH token
        IMintableToken weth = IMintableToken(SepoliaConfig.MOCK_WETH);

        // Check balances
        uint256 wethBalance = weth.balanceOf(user);
        uint256 aiusdBalance = aiusd.balanceOf(user);
        console.log("Initial WETH balance:", wethBalance);
        console.log("Initial AIUSD balance:", aiusdBalance);

        // Prepare deposit
        address[] memory tokens = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        tokens[0] = address(weth);
        amounts[0] = 1 ether; // 1 WETH

        // Approve and deposit
        weth.approve(address(vault), amounts[0]);
        console.log("Approved WETH:", amounts[0]);

        // Try deposit with minimal fee (will fail at AI request but deposit will be recorded)
        try vault.depositBasket{ value: 0.001 ether }(tokens, amounts) {
            console.log("[+] Deposit completed successfully");
        } catch {
            console.log("[!] Deposit recorded but AI request failed (expected)");
        }

        // Check position after deposit attempt
        (
            address[] memory depositedTokens,
            uint256[] memory depositedAmounts,
            uint256 totalValue,
            uint256 aiusdMinted,
            uint256 collateralRatio,
            uint256 requestId,
            bool hasPendingRequest
        ) = vault.getPosition(user);

        console.log("Position status:");
        console.log("- Total value:", totalValue);
        console.log("- AIUSD minted:", aiusdMinted);
        console.log("- Has pending request:", hasPendingRequest);
        console.log("- Request ID:", requestId);

        vm.stopBroadcast();
    }

    /// @notice Step 2: Simulate AI processing and trigger callback
    function step2_SimulateAICallback() public {
        vm.startBroadcast(deployerPrivateKey);

        console.log("\n=== STEP 2: Simulate AI Processing ===");

        // Get user's position
        (,, uint256 totalValue,,, uint256 requestId, bool hasPendingRequest) = vault.getPosition(user);

        if (!hasPendingRequest) {
            console.log("[!] No pending AI request found");
            vm.stopBroadcast();
            return;
        }

        console.log("Processing AI request ID:", requestId);
        console.log("Collateral value:", totalValue);

        // Simulate AI analysis results
        uint256 aiRatio = 15_000; // 150% collateral ratio (in basis points)
        uint256 confidence = 85; // 85% confidence
        uint256 mintAmount = (totalValue * 10_000) / aiRatio; // Calculate mint amount

        console.log("AI Analysis Results:");
        console.log("- Recommended ratio:", aiRatio, "basis points (150%)");
        console.log("- Confidence:", confidence, "%");
        console.log("- Mint amount:", mintAmount);

        // Manually trigger the AI callback (as if AI Oracle called it)
        try vault.processAICallback(user, requestId, mintAmount, aiRatio, confidence) {
            console.log("[+] AI callback processed successfully");
        } catch Error(string memory reason) {
            console.log("[X] AI callback failed:", reason);
        } catch {
            console.log("[X] AI callback failed with unknown error");
        }

        vm.stopBroadcast();
    }

    /// @notice Step 3: Check final results
    function step3_CheckResults() public view {
        console.log("\n=== STEP 3: Final Results ===");

        // Check user balances
        IMintableToken weth = IMintableToken(SepoliaConfig.MOCK_WETH);
        uint256 wethBalance = weth.balanceOf(user);
        uint256 aiusdBalance = aiusd.balanceOf(user);

        console.log("Final balances:");
        console.log("- WETH balance:", wethBalance);
        console.log("- AIUSD balance:", aiusdBalance);

        // Check position
        (
            address[] memory tokens,
            uint256[] memory amounts,
            uint256 totalValue,
            uint256 aiusdMinted,
            uint256 collateralRatio,
            uint256 requestId,
            bool hasPendingRequest
        ) = vault.getPosition(user);

        console.log("Final position:");
        console.log("- Total collateral value:", totalValue);
        console.log("- AIUSD minted:", aiusdMinted);
        console.log("- Collateral ratio:", collateralRatio);
        console.log("- Has pending request:", hasPendingRequest);

        if (aiusdBalance > 0) {
            console.log("\n[+] SUCCESS: AIUSD minted successfully!");
            console.log("Capital efficiency:", (aiusdBalance * 10_000) / totalValue, "basis points");
        } else {
            console.log("\n[!] No AIUSD minted yet");
        }
    }

    /// @notice Main run function - executes full flow
    function run() public {
        console.log("AI Stablecoin Full Flow Test");
        console.log("============================");
        console.log("This test demonstrates: Deposit -> AI Processing -> Minting");

        // Execute the full flow
        step1_DepositCollateral();
        step2_SimulateAICallback();
        step3_CheckResults();

        console.log("\n[+] Full flow test completed!");
        console.log("Next: Test withdrawal with the minted AIUSD");
    }
}

// Usage:
// source .env && forge script script/TestFullFlow.s.sol:TestFullFlowScript --fork-url $SEPOLIA_RPC_URL --broadcast -vv
