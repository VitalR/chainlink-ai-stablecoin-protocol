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

/// @title TestDepositSimple - Simple deposit test bypassing Oracle issues
/// @notice Tests deposit functionality with a fixed fee amount
contract TestDepositSimpleScript is Script {
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

    /// @notice Test deposit with fixed fee (bypassing Oracle fee estimation)
    function testDepositWithFixedFee() public {
        vm.startBroadcast(userPrivateKey);

        console.log("=== Simple Deposit Test (Fixed Fee) ===");
        console.log("User address:", user);

        // Initialize WETH token
        IMintableToken weth = IMintableToken(SepoliaConfig.MOCK_WETH);

        // Check WETH balance
        uint256 wethBalance = weth.balanceOf(user);
        console.log("User WETH balance:", wethBalance);
        require(wethBalance >= 1 ether, "Insufficient WETH balance");

        // Prepare deposit
        address[] memory tokens = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        tokens[0] = address(weth);
        amounts[0] = 1 ether; // 1 WETH

        // Approve tokens
        weth.approve(address(vault), amounts[0]);
        console.log("Approved WETH:", amounts[0]);

        // Use a fixed fee amount (0.01 ETH) instead of estimating
        uint256 fixedFee = 0.01 ether;
        console.log("Using fixed AI fee:", fixedFee);
        require(user.balance >= fixedFee, "Insufficient ETH for AI fee");

        // Execute deposit with fixed fee
        try vault.depositBasket{ value: fixedFee }(tokens, amounts) {
            console.log("[+] Deposit executed successfully!");

            // Check position
            (
                address[] memory depositedTokens,
                uint256[] memory depositedAmounts,
                uint256 totalValue,
                uint256 aiusdMinted,
                uint256 collateralRatio,
                uint256 requestId,
                bool hasPendingRequest
            ) = vault.getPosition(user);

            console.log("Position created:");
            console.log("- Total value:", totalValue);
            console.log("- Request ID:", requestId);
            console.log("- Has pending request:", hasPendingRequest);
            console.log("- AIUSD minted:", aiusdMinted);
        } catch Error(string memory reason) {
            console.log("[X] Deposit failed:", reason);
        } catch {
            console.log("[X] Deposit failed with unknown error");
        }

        vm.stopBroadcast();
    }

    /// @notice Check system status
    function checkStatus() public view {
        console.log("=== System Status ===");
        console.log("User address:", user);
        console.log("User ETH balance:", user.balance);

        IMintableToken weth = IMintableToken(SepoliaConfig.MOCK_WETH);
        IMintableToken dai = IMintableToken(SepoliaConfig.MOCK_DAI);
        IMintableToken wbtc = IMintableToken(SepoliaConfig.MOCK_WBTC);

        console.log("WETH balance:", weth.balanceOf(user));
        console.log("DAI balance:", dai.balanceOf(user));
        console.log("WBTC balance:", wbtc.balanceOf(user));
        console.log("AIUSD balance:", aiusd.balanceOf(user));
    }

    /// @notice Main run function
    function run() public {
        console.log("Simple Deposit Test (Bypass Oracle)");
        console.log("======================================");

        // Check status first
        checkStatus();

        // Test deposit
        testDepositWithFixedFee();

        console.log("\n[+] Test completed!");
    }
}

// Usage:
// source .env && forge script script/TestDepositSimple.s.sol:TestDepositSimpleScript --fork-url $SEPOLIA_RPC_URL
// --broadcast -vv
