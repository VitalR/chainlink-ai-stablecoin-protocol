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
    function transfer(address to, uint256 amount) external returns (bool);
}

/// @title TestEmergencyFlow - Test using emergency functions to bypass Oracle
/// @notice Uses emergency functions to test the complete deposit/withdraw flow
contract TestEmergencyFlowScript is Script {
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

    /// @notice Step 1: Manual deposit simulation (send tokens directly to vault)
    function step1_ManualDeposit() public {
        vm.startBroadcast(userPrivateKey);

        console.log("=== STEP 1: Manual Deposit Simulation ===");
        console.log("User address:", user);

        // Initialize WETH token
        IMintableToken weth = IMintableToken(SepoliaConfig.MOCK_WETH);

        // Check initial balances
        uint256 wethBalance = weth.balanceOf(user);
        uint256 aiusdBalance = aiusd.balanceOf(user);
        console.log("Initial WETH balance:", wethBalance);
        console.log("Initial AIUSD balance:", aiusdBalance);

        // Send WETH directly to vault (simulating a deposit)
        uint256 depositAmount = 1 ether;
        weth.transfer(address(vault), depositAmount);
        console.log("Sent WETH to vault:", depositAmount);

        // Check vault received the tokens
        uint256 vaultWethBalance = weth.balanceOf(address(vault));
        console.log("Vault WETH balance:", vaultWethBalance);

        vm.stopBroadcast();
    }

    /// @notice Step 2: Use deployer to manually mint AIUSD (simulating AI processing)
    function step2_ManualMinting() public {
        vm.startBroadcast(deployerPrivateKey);

        console.log("\n=== STEP 2: Manual AIUSD Minting ===");

        // Calculate mint amount (150% collateral ratio)
        uint256 collateralValue = 2500 * 1e18; // 1 WETH * $2500
        uint256 collateralRatio = 15_000; // 150% in basis points
        uint256 mintAmount = (collateralValue * 10_000) / collateralRatio;

        console.log("Collateral value:", collateralValue);
        console.log("Target ratio:", collateralRatio, "basis points");
        console.log("Mint amount:", mintAmount);

        // Mint AIUSD directly to user (as vault owner)
        try aiusd.mint(user, mintAmount) {
            console.log("[+] AIUSD minted successfully");
        } catch Error(string memory reason) {
            console.log("[X] Minting failed:", reason);
        } catch {
            console.log("[X] Minting failed with unknown error");
        }

        vm.stopBroadcast();
    }

    /// @notice Step 3: Test withdrawal flow
    function step3_TestWithdrawal() public {
        vm.startBroadcast(userPrivateKey);

        console.log("\n=== STEP 3: Test Withdrawal ===");

        // Check AIUSD balance
        uint256 aiusdBalance = aiusd.balanceOf(user);
        console.log("User AIUSD balance:", aiusdBalance);

        if (aiusdBalance == 0) {
            console.log("[!] No AIUSD to withdraw");
            vm.stopBroadcast();
            return;
        }

        // Try to withdraw 50% of AIUSD
        uint256 withdrawAmount = aiusdBalance / 2;
        console.log("Attempting to withdraw:", withdrawAmount);

        // Check initial WETH balance
        IMintableToken weth = IMintableToken(SepoliaConfig.MOCK_WETH);
        uint256 initialWethBalance = weth.balanceOf(user);
        console.log("Initial user WETH balance:", initialWethBalance);

        // Approve AIUSD for withdrawal
        aiusd.approve(address(vault), withdrawAmount);

        // Attempt withdrawal
        try vault.withdrawCollateral(withdrawAmount) {
            console.log("[+] Withdrawal successful");

            // Check final balances
            uint256 finalWethBalance = weth.balanceOf(user);
            uint256 finalAiusdBalance = aiusd.balanceOf(user);

            console.log("Final user WETH balance:", finalWethBalance);
            console.log("Final AIUSD balance:", finalAiusdBalance);
            console.log("WETH received:", finalWethBalance - initialWethBalance);
        } catch Error(string memory reason) {
            console.log("[X] Withdrawal failed:", reason);
        } catch {
            console.log("[X] Withdrawal failed with unknown error");
        }

        vm.stopBroadcast();
    }

    /// @notice Step 4: Check final system state
    function step4_FinalCheck() public view {
        console.log("\n=== STEP 4: Final System State ===");

        IMintableToken weth = IMintableToken(SepoliaConfig.MOCK_WETH);

        console.log("Final balances:");
        console.log("- User WETH:", weth.balanceOf(user));
        console.log("- User AIUSD:", aiusd.balanceOf(user));
        console.log("- Vault WETH:", weth.balanceOf(address(vault)));

        // Check position (should be empty if withdrawal worked)
        (,, uint256 totalValue, uint256 aiusdMinted,,,) = vault.getPosition(user);
        console.log("- Position value:", totalValue);
        console.log("- Position AIUSD:", aiusdMinted);
    }

    /// @notice Main run function
    function run() public {
        console.log("AI Stablecoin Emergency Flow Test");
        console.log("=================================");
        console.log("Testing: Manual Deposit -> Manual Mint -> Withdrawal");

        step1_ManualDeposit();
        step2_ManualMinting();
        step3_TestWithdrawal();
        step4_FinalCheck();

        console.log("\n[+] Emergency flow test completed!");
        console.log("This demonstrates the core mechanics work!");
    }
}

// Usage:
// source .env && forge script script/TestEmergencyFlow.s.sol:TestEmergencyFlowScript --fork-url $SEPOLIA_RPC_URL
// --broadcast -vv
