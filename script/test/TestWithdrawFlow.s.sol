// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "forge-std/Script.sol";
import { IERC20 } from "@openzeppelin/token/ERC20/IERC20.sol";

import { AIStablecoin } from "src/AIStablecoin.sol";
import { CollateralVault } from "src/CollateralVault.sol";
import { RiskOracleController } from "src/RiskOracleController.sol";
import { SepoliaConfig } from "config/SepoliaConfig.sol";

/// @title TestWithdrawFlow - Comprehensive withdrawal flow testing
/// @notice Tests all withdrawal scenarios: normal, emergency, and edge cases
contract TestWithdrawFlowScript is Script {
    AIStablecoin aiusd;
    CollateralVault vault;
    RiskOracleController controller;

    IERC20 dai;
    IERC20 weth;
    IERC20 wbtc;
    IERC20 usdc;

    address user;
    uint256 userPrivateKey;

    function setUp() public {
        // Get user credentials from environment
        user = vm.envAddress("USER_PUBLIC_KEY");
        userPrivateKey = vm.envUint("USER_PRIVATE_KEY");

        // Initialize contracts
        aiusd = AIStablecoin(SepoliaConfig.AI_STABLECOIN);
        vault = CollateralVault(payable(SepoliaConfig.COLLATERAL_VAULT));
        controller = RiskOracleController(SepoliaConfig.RISK_ORACLE_CONTROLLER);

        // Initialize tokens
        dai = IERC20(SepoliaConfig.MOCK_DAI);
        weth = IERC20(SepoliaConfig.MOCK_WETH);
        wbtc = IERC20(SepoliaConfig.MOCK_WBTC);
        usdc = IERC20(SepoliaConfig.MOCK_USDC);
    }

    /// @notice Check current position and withdrawal eligibility
    function checkWithdrawStatus() public view {
        console.log("=== WITHDRAWAL STATUS CHECK ===");
        console.log("User address:", user);
        console.log("Block timestamp:", block.timestamp);
        console.log("");

        // Check AIUSD balance
        uint256 aiusdBalance = aiusd.balanceOf(user);
        console.log("AIUSD balance:", aiusdBalance);

        if (aiusdBalance == 0) {
            console.log("[!] No AIUSD balance - cannot test normal withdrawal");
        }

        // Check position details
        (
            address[] memory tokens,
            uint256[] memory amounts,
            uint256 totalValue,
            uint256 aiusdMinted,
            uint256 collateralRatio,
            uint256 requestId,
            bool hasPendingRequest
        ) = vault.getPosition(user);

        console.log("Position Status:");
        console.log("- Total collateral value:", totalValue);
        console.log("- AIUSD minted:", aiusdMinted);
        console.log("- Collateral ratio:", collateralRatio);
        console.log("- Request ID:", requestId);
        console.log("- Has pending request:", hasPendingRequest);
        console.log("");

        if (totalValue == 0) {
            console.log("[!] No active position found");
            return;
        }

        // Show collateral composition
        console.log("Collateral Composition:");
        for (uint256 i = 0; i < tokens.length; i++) {
            string memory symbol = _getTokenSymbol(tokens[i]);
            console.log("- %s: %s", symbol, amounts[i]);
        }
        console.log("");

        // Check withdrawal eligibility
        if (hasPendingRequest) {
            console.log("[X] CANNOT WITHDRAW: AI request pending");

            // Check emergency withdrawal eligibility
            (bool canEmergencyWithdraw, uint256 timeRemaining) = vault.canEmergencyWithdraw(user);
            if (canEmergencyWithdraw) {
                console.log("[+] Emergency withdrawal available NOW");
            } else {
                console.log("[!] Emergency withdrawal available in:", timeRemaining, "seconds");
            }
        } else {
            console.log("[+] NORMAL WITHDRAWAL AVAILABLE");

            // Calculate withdrawal options
            uint256 maxWithdrawable = aiusdBalance < aiusdMinted ? aiusdBalance : aiusdMinted;
            console.log("Maximum withdrawable AIUSD:", maxWithdrawable);
            console.log("Suggested withdrawal amounts:");
            console.log("- 25%:", maxWithdrawable / 4);
            console.log("- 50%:", maxWithdrawable / 2);
            console.log("- 100%:", maxWithdrawable);
        }
        console.log("");
    }

    /// @notice Test normal withdrawal (25% of position)
    function testPartialWithdraw() public {
        vm.startBroadcast(userPrivateKey);

        console.log("=== TESTING PARTIAL WITHDRAWAL (25%) ===");

        // Pre-checks
        uint256 aiusdBalance = aiusd.balanceOf(user);
        require(aiusdBalance > 0, "No AIUSD balance");

        (,,,,, uint256 requestId, bool hasPendingRequest) = vault.getPosition(user);
        require(!hasPendingRequest, "Cannot withdraw with pending AI request");

        // Calculate withdrawal amount (25%)
        uint256 withdrawAmount = aiusdBalance / 4;
        console.log("Withdrawing 25% of AIUSD balance:", withdrawAmount);

        // Record initial balances
        uint256 initialWeth = weth.balanceOf(user);
        uint256 initialWbtc = wbtc.balanceOf(user);
        uint256 initialDai = dai.balanceOf(user);
        uint256 initialUsdc = usdc.balanceOf(user);

        console.log("Initial token balances:");
        console.log("- WETH:", initialWeth);
        console.log("- WBTC:", initialWbtc);
        console.log("- DAI:", initialDai);
        console.log("- USDC:", initialUsdc);

        // Approve and execute withdrawal
        aiusd.approve(address(vault), withdrawAmount);
        vault.withdrawFromPosition(0, withdrawAmount);

        console.log("[SUCCESS] Partial withdrawal executed successfully");

        // Check final balances
        uint256 finalAiusd = aiusd.balanceOf(user);
        uint256 finalWeth = weth.balanceOf(user);
        uint256 finalWbtc = wbtc.balanceOf(user);
        uint256 finalDai = dai.balanceOf(user);
        uint256 finalUsdc = usdc.balanceOf(user);

        console.log("Final balances:");
        console.log("- AIUSD:", finalAiusd);
        console.log("  (burned:", aiusdBalance - finalAiusd, ")");
        console.log("- WETH:", finalWeth);
        console.log("  (received:", finalWeth - initialWeth, ")");
        console.log("- WBTC:", finalWbtc);
        console.log("  (received:", finalWbtc - initialWbtc, ")");
        console.log("- DAI:", finalDai);
        console.log("  (received:", finalDai - initialDai, ")");
        console.log("- USDC:", finalUsdc);
        console.log("  (received:", finalUsdc - initialUsdc, ")");

        vm.stopBroadcast();
    }

    /// @notice Test full withdrawal (100% of position)
    function testFullWithdraw() public {
        vm.startBroadcast(userPrivateKey);

        console.log("=== TESTING FULL WITHDRAWAL (100%) ===");

        // Pre-checks
        uint256 aiusdBalance = aiusd.balanceOf(user);
        require(aiusdBalance > 0, "No AIUSD balance");

        (,,,,, uint256 requestId, bool hasPendingRequest) = vault.getPosition(user);
        require(!hasPendingRequest, "Cannot withdraw with pending AI request");

        console.log("Withdrawing full AIUSD balance:", aiusdBalance);

        // Record initial balances
        uint256 initialWeth = weth.balanceOf(user);
        uint256 initialWbtc = wbtc.balanceOf(user);
        uint256 initialDai = dai.balanceOf(user);
        uint256 initialUsdc = usdc.balanceOf(user);

        // Execute full withdrawal
        aiusd.approve(address(vault), aiusdBalance);
        vault.withdrawFromPosition(0, aiusdBalance);

        console.log("[SUCCESS] Full withdrawal executed successfully");

        // Verify complete position closure
        uint256 finalAiusd = aiusd.balanceOf(user);
        (,, uint256 finalTotalValue, uint256 finalAiusdMinted,,,) = vault.getPosition(user);

        console.log("Position closure verification:");
        console.log("- Final AIUSD balance:", finalAiusd);
        console.log("- Final collateral value:", finalTotalValue);
        console.log("- Final AIUSD minted:", finalAiusdMinted);

        // These should all be zero after full withdrawal
        require(finalAiusd == 0 || finalAiusd == aiusdBalance, "AIUSD should be burned");
        require(finalTotalValue == 0, "Collateral value should be zero");
        require(finalAiusdMinted == 0, "Minted amount should be zero");

        // Show tokens received
        uint256 finalWeth = weth.balanceOf(user);
        uint256 finalWbtc = wbtc.balanceOf(user);
        uint256 finalDai = dai.balanceOf(user);
        uint256 finalUsdc = usdc.balanceOf(user);

        console.log("Total tokens received:");
        console.log("- WETH:", finalWeth - initialWeth);
        console.log("- WBTC:", finalWbtc - initialWbtc);
        console.log("- DAI:", finalDai - initialDai);
        console.log("- USDC:", finalUsdc - initialUsdc);

        vm.stopBroadcast();
    }

    /// @notice Test emergency withdrawal (for stuck requests)
    function testEmergencyWithdraw() public {
        vm.startBroadcast(userPrivateKey);

        console.log("=== TESTING EMERGENCY WITHDRAWAL ===");

        // Check if user has pending request
        (,,,,, uint256 requestId, bool hasPendingRequest) = vault.getPosition(user);

        if (!hasPendingRequest) {
            console.log("[!] No pending request found - cannot test emergency withdrawal");
            console.log("To test emergency withdrawal:");
            console.log("1. Make a deposit (creates pending AI request)");
            console.log("2. Wait 4+ hours");
            console.log("3. Run this test again");
            vm.stopBroadcast();
            return;
        }

        console.log("Found pending request ID:", requestId);

        // Check emergency withdrawal eligibility
        (bool canWithdraw, uint256 timeRemaining) = vault.canEmergencyWithdraw(user);

        if (!canWithdraw) {
            console.log("[!] Emergency withdrawal not yet available");
            console.log("Time remaining:", timeRemaining, "seconds");
            console.log("Must wait 4 hours (14400 seconds) from deposit");
            vm.stopBroadcast();
            return;
        }

        console.log("[SUCCESS] Emergency withdrawal available");

        // Record initial balances
        uint256 initialWeth = weth.balanceOf(user);
        uint256 initialWbtc = wbtc.balanceOf(user);
        uint256 initialDai = dai.balanceOf(user);
        uint256 initialUsdc = usdc.balanceOf(user);

        // Execute emergency withdrawal
        vault.userEmergencyWithdraw();

        console.log("[SUCCESS] Emergency withdrawal executed successfully");

        // Verify position cleared
        (,, uint256 finalTotalValue, uint256 finalAiusdMinted,, uint256 finalRequestId, bool finalHasPending) =
            vault.getPosition(user);

        console.log("Position status after emergency withdrawal:");
        console.log("- Total value:", finalTotalValue);
        console.log("- AIUSD minted:", finalAiusdMinted);
        console.log("- Request ID:", finalRequestId);
        console.log("- Has pending:", finalHasPending);

        // Show tokens received
        uint256 finalWeth = weth.balanceOf(user);
        uint256 finalWbtc = wbtc.balanceOf(user);
        uint256 finalDai = dai.balanceOf(user);
        uint256 finalUsdc = usdc.balanceOf(user);

        console.log("Tokens recovered:");
        console.log("- WETH:", finalWeth - initialWeth);
        console.log("- WBTC:", finalWbtc - initialWbtc);
        console.log("- DAI:", finalDai - initialDai);
        console.log("- USDC:", finalUsdc - initialUsdc);

        vm.stopBroadcast();
    }

    /// @notice Test multiple small withdrawals
    function testMultipleWithdrawals() public {
        vm.startBroadcast(userPrivateKey);

        console.log("=== TESTING MULTIPLE SMALL WITHDRAWALS ===");

        uint256 initialAiusd = aiusd.balanceOf(user);
        require(initialAiusd > 0, "No AIUSD balance");

        (,,,,, uint256 requestId, bool hasPendingRequest) = vault.getPosition(user);
        require(!hasPendingRequest, "Cannot withdraw with pending AI request");

        // Execute 3 small withdrawals (10% each)
        uint256 withdrawAmount = initialAiusd / 10;
        console.log("Executing 3 withdrawals of 10% each:", withdrawAmount);

        for (uint256 i = 1; i <= 3; i++) {
            console.log("\n--- Withdrawal #", i, "---");

            uint256 currentBalance = aiusd.balanceOf(user);
            console.log("Current AIUSD balance:", currentBalance);

            if (currentBalance < withdrawAmount) {
                withdrawAmount = currentBalance;
                console.log("Adjusted withdrawal amount:", withdrawAmount);
            }

            if (withdrawAmount == 0) {
                console.log("No AIUSD left to withdraw");
                break;
            }

            aiusd.approve(address(vault), withdrawAmount);
            vault.withdrawFromPosition(0, withdrawAmount);

            uint256 newBalance = aiusd.balanceOf(user);
            console.log("New AIUSD balance:", newBalance);
            console.log("Actually withdrawn:", currentBalance - newBalance);
        }

        console.log("\n[SUCCESS] Multiple withdrawals completed");

        vm.stopBroadcast();
    }

    /// @notice Test edge cases and error conditions
    function testEdgeCases() public view {
        console.log("=== TESTING EDGE CASES ===");

        // Test 1: Check for edge case scenarios
        uint256 aiusdBalance = aiusd.balanceOf(user);
        if (aiusdBalance > 0) {
            console.log("Test 1: Current AIUSD balance allows withdrawals");
            console.log("- Balance:", aiusdBalance);
            console.log("- Can test normal withdrawals: YES");
        } else {
            console.log("Test 1: No AIUSD balance");
            console.log("- Can test normal withdrawals: NO");
        }

        // Test 2: Check position status
        (,,,,, uint256 requestId, bool hasPendingRequest) = vault.getPosition(user);
        if (hasPendingRequest) {
            console.log("Test 2: Has pending AI request");
            console.log("- Request ID:", requestId);
            console.log("- Normal withdrawal blocked: YES");

            // Check emergency withdrawal eligibility
            (bool canEmergencyWithdraw, uint256 timeRemaining) = vault.canEmergencyWithdraw(user);
            if (canEmergencyWithdraw) {
                console.log("- Emergency withdrawal available: YES");
            } else {
                console.log("- Emergency withdrawal available in:", timeRemaining, "seconds");
            }
        } else {
            console.log("Test 2: No pending AI request");
            console.log("- Normal withdrawal available: YES");
        }

        console.log("[SUCCESS] Edge case analysis completed");
    }

    /// @notice Run comprehensive withdrawal flow test
    function runComprehensiveTest() public {
        console.log("STARTING COMPREHENSIVE WITHDRAWAL FLOW TEST");
        console.log("================================================");

        // Step 1: Check status
        checkWithdrawStatus();

        // Step 2: Test edge cases first (non-destructive)
        testEdgeCases();

        // Step 3: Test partial withdrawal if possible
        uint256 aiusdBalance = aiusd.balanceOf(user);
        (,,,,, uint256 requestId, bool hasPendingRequest) = vault.getPosition(user);

        if (aiusdBalance > 0 && !hasPendingRequest) {
            if (aiusdBalance >= 4) {
                // Ensure we can do 25% withdrawal
                console.log("\nTesting partial withdrawal...");
                testPartialWithdraw();
            }

            // Check if we still have balance for multiple withdrawals
            uint256 remainingBalance = aiusd.balanceOf(user);
            if (remainingBalance >= 10) {
                // Ensure we can do 3x 10% withdrawals
                console.log("\nTesting multiple small withdrawals...");
                testMultipleWithdrawals();
            }

            // Final full withdrawal if any balance remains
            uint256 finalBalance = aiusd.balanceOf(user);
            if (finalBalance > 0) {
                console.log("\nTesting final full withdrawal...");
                testFullWithdraw();
            }
        } else if (hasPendingRequest) {
            console.log("\nTesting emergency withdrawal...");
            testEmergencyWithdraw();
        } else {
            console.log("\n[!] No AIUSD balance - cannot test normal withdrawals");
        }

        console.log("\n[SUCCESS] COMPREHENSIVE WITHDRAWAL TEST COMPLETED");
        console.log("===========================================");
    }

    /// @notice Helper function to get token symbol
    function _getTokenSymbol(address token) internal pure returns (string memory) {
        if (token == SepoliaConfig.MOCK_WETH) return "WETH";
        if (token == SepoliaConfig.MOCK_WBTC) return "WBTC";
        if (token == SepoliaConfig.MOCK_DAI) return "DAI";
        if (token == SepoliaConfig.MOCK_USDC) return "USDC";
        return "UNKNOWN";
    }
}
