// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "forge-std/Script.sol";
import { IERC20 } from "@openzeppelin/token/ERC20/IERC20.sol";

import { AIStablecoin } from "src/AIStablecoin.sol";
import { CollateralVault } from "src/CollateralVault.sol";
import { RiskOracleController } from "src/RiskOracleController.sol";
import { SepoliaConfig } from "config/SepoliaConfig.sol";

/// @title ExecuteWithdraw - Test withdrawal scenarios for AI Stablecoin with Enhanced Position Management
/// @notice Executes various withdrawal scenarios to test the system functionality with multiple positions
contract ExecuteWithdrawScript is Script {
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
        // Get target user (default to DEPLOYER, or USER if specified)
        string memory targetUser = vm.envOr("WITHDRAW_TARGET_USER", string("DEPLOYER"));

        if (keccak256(abi.encodePacked(targetUser)) == keccak256(abi.encodePacked("USER"))) {
            user = vm.envAddress("USER_PUBLIC_KEY");
            userPrivateKey = vm.envUint("USER_PRIVATE_KEY");
            console.log("Using USER credentials");
        } else {
            user = vm.envAddress("DEPLOYER_PUBLIC_KEY");
            userPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
            console.log("Using DEPLOYER credentials");
        }

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

    /// @notice Execute partial withdrawal from a specific position (25% of position)
    function runPartialWithdraw() public {
        vm.startBroadcast(userPrivateKey);

        console.log("=== Partial Withdrawal from Position (25%) ===");

        _checkUserStatus();

        // Get position index from environment or default to latest
        uint256 positionIndex = vm.envOr("POSITION_INDEX", uint256(0));

        CollateralVault.Position memory position = vault.getUserDepositInfo(user, positionIndex);
        require(position.timestamp > 0, "Position does not exist");
        require(!position.hasPendingRequest, "Cannot withdraw with pending AI request");
        require(position.aiusdMinted > 0, "No AIUSD minted in this position");

        console.log("Withdrawing from Position", positionIndex);
        console.log("Position AIUSD minted:", position.aiusdMinted);

        // Calculate withdrawal amount (25%)
        uint256 withdrawAmount = position.aiusdMinted / 4;
        console.log("Withdrawing 25% of position:", withdrawAmount);

        // Get initial token balances
        _logTokenBalances("Initial");

        // Execute withdrawal
        aiusd.approve(address(vault), withdrawAmount);
        vault.withdrawFromPosition(positionIndex, withdrawAmount);

        console.log("Partial withdrawal executed successfully");

        // Check final balances and status
        _logTokenBalances("Final");
        _checkUserStatus();

        vm.stopBroadcast();
    }

    /// @notice Execute full withdrawal from a specific position (100% of position)
    function runFullWithdraw() public {
        vm.startBroadcast(userPrivateKey);

        console.log("=== Full Withdrawal from Position (100%) ===");

        _checkUserStatus();

        // Get position index from environment or default to latest
        uint256 positionIndex = vm.envOr("POSITION_INDEX", uint256(0));

        CollateralVault.Position memory position = vault.getUserDepositInfo(user, positionIndex);
        require(position.timestamp > 0, "Position does not exist");
        require(!position.hasPendingRequest, "Cannot withdraw with pending AI request");
        require(position.aiusdMinted > 0, "No AIUSD minted in this position");

        console.log("Full withdrawal from Position", positionIndex);
        console.log("Position AIUSD minted:", position.aiusdMinted);

        // Get initial token balances
        _logTokenBalances("Initial");

        // Execute full withdrawal
        aiusd.approve(address(vault), position.aiusdMinted);
        vault.withdrawFromPosition(positionIndex, position.aiusdMinted);

        console.log("Full withdrawal executed successfully");

        // Verify position is cleared
        CollateralVault.Position memory updatedPosition = vault.getUserDepositInfo(user, positionIndex);
        console.log("Position cleared - AIUSD minted:", updatedPosition.aiusdMinted);

        // Check final balances and status
        _logTokenBalances("Final");
        _checkUserStatus();

        vm.stopBroadcast();
    }

    /// @notice Execute multiple small withdrawals from different positions
    function runMultiplePositionWithdrawals() public {
        vm.startBroadcast(userPrivateKey);

        console.log("=== Multiple Position Withdrawals ===");

        _checkUserStatus();

        // Get position summary
        (uint256 totalPositions, uint256 activePositions,,) = vault.getPositionSummary(user);
        require(activePositions > 0, "No active positions");

        console.log("Withdrawing from multiple positions...");

        // Withdraw from first 2 active positions (or all if less than 2)
        uint256 positionsToProcess = activePositions > 2 ? 2 : activePositions;

        for (uint256 i = 0; i < positionsToProcess; i++) {
            CollateralVault.Position memory position = vault.getUserDepositInfo(user, i);

            if (position.timestamp > 0 && position.aiusdMinted > 0 && !position.hasPendingRequest) {
                console.log("Processing Position", i);
                console.log("- AIUSD minted:", position.aiusdMinted);

                // Withdraw 10% from each position
                uint256 withdrawAmount = position.aiusdMinted / 10;

                if (withdrawAmount > 0) {
                    aiusd.approve(address(vault), withdrawAmount);
                    vault.withdrawFromPosition(i, withdrawAmount);
                    console.log("- Withdrew:", withdrawAmount);
                } else {
                    console.log("- Skipped: Amount too small");
                }
                console.log("---");
            }
        }

        console.log("Multiple position withdrawals completed");
        _checkUserStatus();

        vm.stopBroadcast();
    }

    /// @notice Check withdrawal eligibility and position status
    function checkWithdrawEligibility() public view {
        console.log("=== WITHDRAWAL ELIGIBILITY CHECK ===");

        uint256 aiusdBalance = aiusd.balanceOf(user);
        console.log("User AIUSD balance:", aiusdBalance);

        if (aiusdBalance == 0) {
            console.log("[X] No AIUSD balance to withdraw");
            return;
        }

        // Get position summary
        (uint256 totalPositions, uint256 activePositions, uint256 totalValueUSD, uint256 totalAIUSDMinted) =
            vault.getPositionSummary(user);

        console.log("");
        console.log("=== POSITION SUMMARY ===");
        console.log("Total positions:", totalPositions);
        console.log("Active positions:", activePositions);
        console.log("Total collateral value: $", totalValueUSD / 1e18);
        console.log("Total AIUSD minted:", totalAIUSDMinted);

        if (activePositions == 0) {
            console.log("[X] No active positions");
            return;
        }

        console.log("");
        console.log("=== POSITION DETAILS ===");

        // Check each position for withdrawal eligibility
        bool hasWithdrawablePosition = false;

        for (uint256 i = 0; i < totalPositions; i++) {
            try vault.getUserDepositInfo(user, i) returns (CollateralVault.Position memory position) {
                if (position.timestamp > 0) {
                    console.log("Position", i, ":");
                    console.log("  - Value: $", position.totalValueUSD / 1e18);
                    console.log("  - AIUSD minted:", position.aiusdMinted);
                    console.log("  - Collateral ratio:", position.collateralRatio, "bps");
                    console.log("  - Pending request:", position.hasPendingRequest);
                    console.log("  - Token count:", position.tokens.length);

                    if (position.hasPendingRequest) {
                        console.log("  - Status: [X] PENDING AI REQUEST");
                    } else if (position.aiusdMinted == 0) {
                        console.log("  - Status: [X] NO AIUSD MINTED");
                    } else {
                        console.log("  - Status: [+] WITHDRAWABLE");
                        hasWithdrawablePosition = true;

                        // Show potential withdrawal amounts
                        console.log("  - 25% withdrawal:", position.aiusdMinted / 4);
                        console.log("  - 50% withdrawal:", position.aiusdMinted / 2);
                        console.log("  - 100% withdrawal:", position.aiusdMinted);
                    }
                    console.log("");
                }
            } catch {
                console.log("Position", i, ": [EMPTY/DELETED]");
            }
        }

        if (hasWithdrawablePosition) {
            console.log("[+] USER IS ELIGIBLE FOR WITHDRAWAL");
        } else {
            console.log("[X] NO WITHDRAWABLE POSITIONS AVAILABLE");
        }
    }

    /// @notice Enhanced status check with multiple position support
    function _checkUserStatus() internal view {
        console.log("=== USER STATUS CHECK ===");
        console.log("User address:", user);
        console.log("User AIUSD balance:", aiusd.balanceOf(user));

        // Get position summary
        (uint256 totalPositions, uint256 activePositions, uint256 totalValueUSD, uint256 totalAIUSDMinted) =
            vault.getPositionSummary(user);

        console.log("");
        console.log("=== POSITION SUMMARY ===");
        console.log("Total positions created:", totalPositions);
        console.log("Active positions:", activePositions);
        console.log("Total collateral value: $", totalValueUSD / 1e18);
        console.log("Total AIUSD minted:", totalAIUSDMinted);
        console.log("");
    }

    /// @notice Log current token balances
    function _logTokenBalances(string memory label) internal view {
        console.log(label, "token balances:");
        console.log("- WETH:", weth.balanceOf(user));
        console.log("- WBTC:", wbtc.balanceOf(user));
        console.log("- DAI:", dai.balanceOf(user));
        console.log("- USDC:", usdc.balanceOf(user));
        console.log("- AIUSD:", aiusd.balanceOf(user));
        console.log("");
    }

    /// @notice Run all withdrawal scenarios
    function run() public {
        console.log("AI STABLECOIN ENHANCED WITHDRAWAL EXECUTION");
        console.log("==========================================");

        // Check withdrawal eligibility first
        checkWithdrawEligibility();

        // Choose scenario based on environment variable
        string memory scenario = vm.envOr("WITHDRAW_SCENARIO", string("partial"));

        if (keccak256(bytes(scenario)) == keccak256(bytes("partial"))) {
            runPartialWithdraw();
        } else if (keccak256(bytes(scenario)) == keccak256(bytes("full"))) {
            runFullWithdraw();
        } else if (keccak256(bytes(scenario)) == keccak256(bytes("multiple"))) {
            runMultiplePositionWithdrawals();
        } else {
            console.log("Unknown scenario. Available: partial, full, multiple");
            console.log("Set WITHDRAW_SCENARIO environment variable");
            console.log("Set POSITION_INDEX environment variable (default: 0)");
            revert("Invalid scenario");
        }

        console.log("");
        console.log("=== WITHDRAWAL EXECUTION COMPLETED ===");
        console.log("Collateral tokens have been returned proportionally.");
        console.log("AIUSD has been burned from user balance.");
    }
}
