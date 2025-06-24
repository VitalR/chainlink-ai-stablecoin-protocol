// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "forge-std/Script.sol";
import { IERC20 } from "@openzeppelin/token/ERC20/IERC20.sol";

import { AIStablecoin } from "src/AIStablecoin.sol";
import { CollateralVault } from "src/CollateralVault.sol";
import { RiskOracleController } from "src/RiskOracleController.sol";
import { SepoliaConfig } from "config/SepoliaConfig.sol";

/// @title ExecuteWithdraw - Test withdrawal scenarios for AI Stablecoin
/// @notice Executes various withdrawal scenarios to test the system functionality
contract ExecuteWithdrawScript is Script {
    AIStablecoin aiusd;
    CollateralVault vault;
    RiskOracleController controller;

    IERC20 dai;
    IERC20 weth;
    IERC20 wbtc;

    address user;
    uint256 userPrivateKey;

    function setUp() public {
        // Get user credentials
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
    }

    /// @notice Execute partial withdrawal (25% of position)
    function runPartialWithdraw() public {
        vm.startBroadcast(userPrivateKey);

        console.log("=== Partial Withdrawal (25%) ===");

        // 1. Check current position
        uint256 aiusdBalance = aiusd.balanceOf(user);
        console.log("Current AIUSD balance:", aiusdBalance);
        require(aiusdBalance > 0, "No AIUSD to withdraw");

        (,,,,, uint256 requestId, bool hasPendingRequest) = vault.getPosition(user);
        require(!hasPendingRequest, "Cannot withdraw with pending AI request");

        // 2. Calculate withdrawal amount (25%)
        uint256 withdrawAmount = aiusdBalance / 4;
        console.log("Withdrawing 25% of position:", withdrawAmount);

        // 3. Get initial token balances
        uint256 initialWethBalance = weth.balanceOf(user);
        uint256 initialWbtcBalance = wbtc.balanceOf(user);
        uint256 initialDaiBalance = dai.balanceOf(user);

        console.log("Initial token balances:");
        console.log("- WETH:", initialWethBalance);
        console.log("- WBTC:", initialWbtcBalance);
        console.log("- DAI:", initialDaiBalance);

        // 4. Approve and execute withdrawal
        aiusd.approve(address(vault), withdrawAmount);
        vault.withdrawFromPosition(0, withdrawAmount);

        console.log("Partial withdrawal executed successfully");

        // 5. Check final balances
        uint256 finalAiusdBalance = aiusd.balanceOf(user);
        uint256 finalWethBalance = weth.balanceOf(user);
        uint256 finalWbtcBalance = wbtc.balanceOf(user);
        uint256 finalDaiBalance = dai.balanceOf(user);

        console.log("Final balances:");
        console.log("- AIUSD:", finalAiusdBalance);
        console.log("- WETH:", finalWethBalance);
        console.log("- WBTC:", finalWbtcBalance);
        console.log("- DAI:", finalDaiBalance);

        console.log("Tokens received:");
        console.log("- WETH:", finalWethBalance - initialWethBalance);
        console.log("- WBTC:", finalWbtcBalance - initialWbtcBalance);
        console.log("- DAI:", finalDaiBalance - initialDaiBalance);

        vm.stopBroadcast();
    }

    /// @notice Execute full withdrawal (100% of position)
    function runFullWithdraw() public {
        vm.startBroadcast(userPrivateKey);

        console.log("=== Full Withdrawal (100%) ===");

        // 1. Check current position
        uint256 aiusdBalance = aiusd.balanceOf(user);
        console.log("Current AIUSD balance:", aiusdBalance);
        require(aiusdBalance > 0, "No AIUSD to withdraw");

        (,,,,, uint256 requestId, bool hasPendingRequest) = vault.getPosition(user);
        require(!hasPendingRequest, "Cannot withdraw with pending AI request");

        // 2. Get initial token balances
        uint256 initialWethBalance = weth.balanceOf(user);
        uint256 initialWbtcBalance = wbtc.balanceOf(user);
        uint256 initialDaiBalance = dai.balanceOf(user);

        // 3. Execute full withdrawal
        aiusd.approve(address(vault), aiusdBalance);
        vault.withdrawFromPosition(0, aiusdBalance);

        console.log("Full withdrawal executed successfully");

        // 4. Verify complete withdrawal
        uint256 finalAiusdBalance = aiusd.balanceOf(user);
        (,, uint256 finalTotalValue, uint256 finalAiusdMinted,,,) = vault.getPosition(user);

        console.log("Final position state:");
        console.log("- AIUSD balance:", finalAiusdBalance);
        console.log("- Total collateral value:", finalTotalValue);
        console.log("- AIUSD minted:", finalAiusdMinted);

        // Should be zero after full withdrawal
        require(finalAiusdBalance == 0, "AIUSD balance should be zero");
        require(finalTotalValue == 0, "Collateral value should be zero");
        require(finalAiusdMinted == 0, "Minted amount should be zero");

        // 5. Show tokens received
        uint256 finalWethBalance = weth.balanceOf(user);
        uint256 finalWbtcBalance = wbtc.balanceOf(user);
        uint256 finalDaiBalance = dai.balanceOf(user);

        console.log("Total tokens received:");
        console.log("- WETH:", finalWethBalance - initialWethBalance);
        console.log("- WBTC:", finalWbtcBalance - initialWbtcBalance);
        console.log("- DAI:", finalDaiBalance - initialDaiBalance);

        vm.stopBroadcast();
    }

    /// @notice Execute multiple small withdrawals
    function runMultipleWithdrawals() public {
        vm.startBroadcast(userPrivateKey);

        console.log("=== Multiple Small Withdrawals ===");

        uint256 initialAiusdBalance = aiusd.balanceOf(user);
        console.log("Initial AIUSD balance:", initialAiusdBalance);
        require(initialAiusdBalance > 0, "No AIUSD to withdraw");

        // Execute 3 small withdrawals (10% each)
        uint256 withdrawAmount = initialAiusdBalance / 10;

        for (uint256 i = 1; i <= 3; i++) {
            console.log("Withdrawal #", i);

            uint256 currentBalance = aiusd.balanceOf(user);
            console.log("Current AIUSD balance:", currentBalance);

            if (currentBalance < withdrawAmount) {
                withdrawAmount = currentBalance;
            }

            aiusd.approve(address(vault), withdrawAmount);
            vault.withdrawFromPosition(0, withdrawAmount);

            uint256 newBalance = aiusd.balanceOf(user);
            console.log("New AIUSD balance:", newBalance);
            console.log("Withdrawn:", currentBalance - newBalance);
            console.log("---");
        }

        console.log("Multiple withdrawals completed");

        vm.stopBroadcast();
    }

    /// @notice Check withdrawal eligibility and position status
    function checkWithdrawEligibility() public view {
        console.log("=== Withdrawal Eligibility Check ===");

        uint256 aiusdBalance = aiusd.balanceOf(user);
        console.log("User AIUSD balance:", aiusdBalance);

        if (aiusdBalance == 0) {
            console.log("[X] No AIUSD balance to withdraw");
            return;
        }

        (
            address[] memory tokens,
            uint256[] memory amounts,
            uint256 totalValue,
            uint256 aiusdMinted,
            uint256 collateralRatio,
            uint256 requestId,
            bool hasPendingRequest
        ) = vault.getPosition(user);

        console.log("Position details:");
        console.log("- Total collateral value:", totalValue);
        console.log("- AIUSD minted:", aiusdMinted);
        console.log("- Collateral ratio:", collateralRatio);
        console.log("- Request ID:", requestId);
        console.log("- Has pending request:", hasPendingRequest);

        if (hasPendingRequest) {
            console.log("[X] Cannot withdraw: AI request pending");
            return;
        }

        if (totalValue == 0) {
            console.log("[X] No collateral position");
            return;
        }

        console.log("[+] Eligible for withdrawal");

        // Show deposited tokens
        if (tokens.length > 0) {
            console.log("\nDeposited tokens:");
            for (uint256 i = 0; i < tokens.length; i++) {
                console.log("- Token:", tokens[i]);
                console.log("  Amount:", amounts[i]);
            }
        }

        // Calculate potential withdrawal amounts
        console.log("\nPotential withdrawals:");
        console.log("- 25% withdrawal:", aiusdBalance / 4);
        console.log("- 50% withdrawal:", aiusdBalance / 2);
        console.log("- 100% withdrawal:", aiusdBalance);
    }

    /// @notice Run all withdrawal scenarios
    function run() public {
        console.log("AI Stablecoin Withdrawal Execution Tests");
        console.log("===========================================");

        // Check withdrawal eligibility first
        checkWithdrawEligibility();

        // Choose scenario based on environment variable
        string memory scenario = vm.envOr("WITHDRAW_SCENARIO", string("partial"));

        if (keccak256(bytes(scenario)) == keccak256(bytes("partial"))) {
            runPartialWithdraw();
        } else if (keccak256(bytes(scenario)) == keccak256(bytes("full"))) {
            runFullWithdraw();
        } else if (keccak256(bytes(scenario)) == keccak256(bytes("multiple"))) {
            runMultipleWithdrawals();
        } else {
            console.log("Available scenarios: partial, full, multiple");
            console.log("Set WITHDRAW_SCENARIO environment variable");
        }

        console.log("\nWithdrawal execution completed");
    }
}
