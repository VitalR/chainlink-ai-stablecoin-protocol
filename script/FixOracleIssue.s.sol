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

/// @title FixOracleIssue - Test with fixed fee to bypass Oracle estimation
/// @notice Demonstrates working deposit flow using fixed fee instead of Oracle estimation
contract FixOracleIssueScript is Script {
    AIStablecoin aiusd;
    AICollateralVaultCallback vault;
    AIControllerCallback controller;

    address user;
    uint256 userPrivateKey;

    function setUp() public {
        // Get user credentials
        user = vm.envAddress("USER_PUBLIC_KEY");
        userPrivateKey = vm.envUint("USER_PRIVATE_KEY");

        // Initialize contracts
        aiusd = AIStablecoin(SepoliaConfig.AI_STABLECOIN);
        vault = AICollateralVaultCallback(payable(SepoliaConfig.AI_VAULT));
        controller = AIControllerCallback(SepoliaConfig.AI_CONTROLLER);
    }

    /// @notice Test deposit with various fixed fee amounts
    function testDepositWithFixedFees() public {
        vm.startBroadcast(userPrivateKey);

        console.log("=== Testing Deposit with Fixed Fees ===");
        console.log("User address:", user);

        // Initialize WETH token
        IMintableToken weth = IMintableToken(SepoliaConfig.MOCK_WETH);

        // Check balances
        uint256 wethBalance = weth.balanceOf(user);
        uint256 ethBalance = user.balance;
        console.log("User WETH balance:", wethBalance);
        console.log("User ETH balance:", ethBalance);

        require(wethBalance >= 1 ether, "Insufficient WETH balance");

        // Prepare deposit
        address[] memory tokens = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        tokens[0] = address(weth);
        amounts[0] = 1 ether; // 1 WETH

        // Approve tokens
        weth.approve(address(vault), amounts[0]);
        console.log("Approved WETH:", amounts[0]);

        // Try different fixed fee amounts to find what works
        uint256[] memory testFees = new uint256[](4);
        testFees[0] = 0.001 ether; // 0.001 ETH
        testFees[1] = 0.01 ether; // 0.01 ETH
        testFees[2] = 0.02 ether; // 0.02 ETH
        testFees[3] = 0.05 ether; // 0.05 ETH

        for (uint256 i = 0; i < testFees.length; i++) {
            uint256 testFee = testFees[i];
            console.log("\n--- Testing with fee:", testFee, "---");

            if (user.balance < testFee) {
                console.log("[!] Insufficient ETH for fee:", testFee);
                continue;
            }

            try vault.depositBasket{ value: testFee }(tokens, amounts) {
                console.log("[+] SUCCESS! Deposit worked with fee:", testFee);

                // Check position
                (,, uint256 totalValue,,, uint256 requestId, bool hasPendingRequest) = vault.getPosition(user);
                console.log("- Total value:", totalValue);
                console.log("- Request ID:", requestId);
                console.log("- Has pending request:", hasPendingRequest);

                // If successful, we're done
                break;
            } catch Error(string memory reason) {
                console.log("[X] Failed with fee", testFee, "- Reason:", reason);
            } catch {
                console.log("[X] Failed with fee", testFee, "- Unknown error");
            }
        }

        vm.stopBroadcast();
    }

    /// @notice Check current system state
    function checkSystemState() public view {
        console.log("=== System State Check ===");

        IMintableToken weth = IMintableToken(SepoliaConfig.MOCK_WETH);

        console.log("User balances:");
        console.log("- WETH:", weth.balanceOf(user));
        console.log("- AIUSD:", aiusd.balanceOf(user));
        console.log("- ETH:", user.balance);

        // Check position
        (,, uint256 totalValue, uint256 aiusdMinted,, uint256 requestId, bool hasPendingRequest) =
            vault.getPosition(user);
        console.log("User position:");
        console.log("- Total value:", totalValue);
        console.log("- AIUSD minted:", aiusdMinted);
        console.log("- Request ID:", requestId);
        console.log("- Has pending request:", hasPendingRequest);
    }

    /// @notice Main run function
    function run() public {
        console.log("Oracle Fee Issue Fix Test");
        console.log("========================");
        console.log("Testing fixed fee approach to bypass Oracle estimation");

        // Check initial state
        checkSystemState();

        // Test deposit with different fees
        testDepositWithFixedFees();

        // Check final state
        console.log("\n=== Final State ===");
        checkSystemState();

        console.log("\n[+] Oracle fix test completed!");
    }
}

// Usage:
// source .env && forge script script/FixOracleIssue.s.sol:FixOracleIssueScript --fork-url $SEPOLIA_RPC_URL --broadcast
// -vv
