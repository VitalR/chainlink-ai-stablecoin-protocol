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

/// @title TestConfigurableFee - Test configurable oracle fee functionality
/// @notice Tests the new configurable fee system
contract TestConfigurableFeeScript is Script {
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

    /// @notice Test fee configuration
    function testFeeConfiguration() public {
        console.log("=== Testing Fee Configuration ===");
        console.log("Oracle address:", SepoliaConfig.ORA_ORACLE);

        // Check current fees
        uint256 currentOracleFee = controller.oracleFee();
        uint256 currentFlatFee = controller.flatFee();
        uint256 totalFee = controller.estimateTotalFee();

        console.log("Current oracle fee:", currentOracleFee);
        console.log("Current flat fee:", currentFlatFee);
        console.log("Total estimated fee:", totalFee);

        // Test updating oracle fee as deployer
        vm.startBroadcast(deployerPrivateKey);

        uint256 newOracleFee = 0.005 ether; // 0.005 ETH
        console.log("\nUpdating oracle fee to:", newOracleFee);

        try controller.updateOracleFee(newOracleFee) {
            console.log("[+] Successfully updated oracle fee");

            uint256 updatedOracleFee = controller.oracleFee();
            uint256 updatedTotalFee = controller.estimateTotalFee();

            console.log("New oracle fee:", updatedOracleFee);
            console.log("New total fee:", updatedTotalFee);

            require(updatedOracleFee == newOracleFee, "Oracle fee not updated correctly");
            require(updatedTotalFee == newOracleFee + currentFlatFee, "Total fee calculation incorrect");
        } catch Error(string memory reason) {
            console.log("[X] Failed to update oracle fee:", reason);
        }

        vm.stopBroadcast();
    }

    /// @notice Test deposit with configurable fee
    function testDepositWithConfigurableFee() public {
        console.log("\n=== Testing Deposit with Configurable Fee ===");

        vm.startBroadcast(userPrivateKey);

        // Initialize WETH token
        IMintableToken weth = IMintableToken(SepoliaConfig.MOCK_WETH);

        // Check balances
        uint256 wethBalance = weth.balanceOf(user);
        uint256 ethBalance = user.balance;
        console.log("User WETH balance:", wethBalance);
        console.log("User ETH balance:", ethBalance);

        if (wethBalance < 1 ether) {
            console.log("[!] Insufficient WETH balance for test");
            vm.stopBroadcast();
            return;
        }

        // Get current fee estimate
        uint256 estimatedFee = controller.estimateTotalFee();
        console.log("Estimated fee for deposit:", estimatedFee);

        if (ethBalance < estimatedFee) {
            console.log("[!] Insufficient ETH for estimated fee");
            vm.stopBroadcast();
            return;
        }

        // Prepare deposit
        address[] memory tokens = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        tokens[0] = address(weth);
        amounts[0] = 1 ether; // 1 WETH

        // Approve tokens
        weth.approve(address(vault), amounts[0]);
        console.log("Approved WETH:", amounts[0]);

        // Try deposit with estimated fee
        console.log("Attempting deposit with estimated fee:", estimatedFee);

        try vault.depositBasket{ value: estimatedFee }(tokens, amounts) {
            console.log("[+] SUCCESS! Deposit worked with estimated fee");

            // Check position
            (,, uint256 totalValue,,, uint256 requestId, bool hasPendingRequest) = vault.getPosition(user);
            console.log("- Total value:", totalValue);
            console.log("- Request ID:", requestId);
            console.log("- Has pending request:", hasPendingRequest);
        } catch Error(string memory reason) {
            console.log("[X] Deposit failed with reason:", reason);
        } catch {
            console.log("[X] Deposit failed with unknown error");
        }

        vm.stopBroadcast();
    }

    /// @notice Main run function
    function run() public {
        console.log("Configurable Fee Test");
        console.log("====================");

        // Test fee configuration
        testFeeConfiguration();

        // Test deposit with configurable fee
        testDepositWithConfigurableFee();

        console.log("\n[+] Configurable fee test completed!");
    }
}

// Usage:
// source .env && forge script script/TestConfigurableFee.s.sol:TestConfigurableFeeScript --fork-url $SEPOLIA_RPC_URL
// --broadcast -vv
