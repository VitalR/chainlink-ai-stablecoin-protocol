// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";

import { AIStablecoin } from "../../src/AIStablecoin.sol";
import { SepoliaConfig } from "../../config/SepoliaConfig.sol";

/// @title BurnOldTokens - Clean up old AIUSD tokens from previous protocol version
/// @notice Script to burn legacy AIUSD tokens for system clarity
contract BurnOldTokensScript is Script {
    AIStablecoin aiusd;

    address deployer = vm.envAddress("DEPLOYER_PUBLIC_KEY");
    uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");

    function setUp() public {
        aiusd = AIStablecoin(SepoliaConfig.AI_STABLECOIN);
    }

    /// @notice Main function to burn old tokens from a specific address
    function burnOldTokens(address userAddress) external {
        vm.startBroadcast(deployerPrivateKey);

        console.log("=== Burning Old AIUSD Tokens ===");
        console.log("Target user:", userAddress);
        console.log("AIUSD contract:", address(aiusd));

        // Check current balance
        uint256 balance = aiusd.balanceOf(userAddress);
        console.log("Current AIUSD balance:", balance);

        if (balance == 0) {
            console.log("No tokens to burn");
            vm.stopBroadcast();
            return;
        }

        // Check if user has approved deployer to burn tokens
        uint256 allowance = aiusd.allowance(userAddress, deployer);
        console.log("Current allowance:", allowance);

        if (allowance < balance) {
            console.log("ERROR: Insufficient allowance to burn tokens");
            console.log("User needs to approve deployer to spend their tokens first");
            console.log("Required allowance:", balance);
            vm.stopBroadcast();
            return;
        }

        // Since burn function is restricted, we need to temporarily authorize deployer as vault
        bool wasAuthorized = aiusd.authorizedVaults(deployer);

        if (!wasAuthorized) {
            console.log("Temporarily authorizing deployer as vault...");
            aiusd.addVault(deployer);
        }

        // Burn the tokens using burnFrom
        console.log("Burning", balance, "AIUSD tokens...");
        aiusd.burnFrom(userAddress, balance);

        // Verify burn was successful
        uint256 newBalance = aiusd.balanceOf(userAddress);
        console.log("New balance after burn:", newBalance);

        if (!wasAuthorized) {
            console.log("Removing deployer vault authorization...");
            aiusd.removeVault(deployer);
        }

        console.log("[SUCCESS] Successfully burned old AIUSD tokens");

        vm.stopBroadcast();
    }

    /// @notice Check token status for a specific address
    function checkTokenStatus(address userAddress) external view {
        console.log("=== AIUSD Token Status ===");
        console.log("User address:", userAddress);
        console.log("AIUSD contract:", address(aiusd));

        uint256 balance = aiusd.balanceOf(userAddress);
        console.log("AIUSD balance:", balance);

        if (balance > 0) {
            console.log("Balance in ether units:", balance / 1e18);

            uint256 allowance = aiusd.allowance(userAddress, deployer);
            console.log("Allowance to deployer:", allowance);

            if (allowance < balance) {
                console.log("");
                console.log("To burn these tokens, user must first approve:");
                console.log("Contract:", address(aiusd));
                console.log("Spender:", deployer);
                console.log("Amount:", balance);
            }
        }

        console.log("Deployer is authorized vault:", aiusd.authorizedVaults(deployer));
    }

    /// @notice Generate approval transaction for user
    function generateApprovalCommand(address userAddress) external view {
        uint256 balance = aiusd.balanceOf(userAddress);

        if (balance == 0) {
            console.log("No tokens to burn");
            return;
        }

        console.log("=== User Approval Command ===");
        console.log("The user needs to run this command to approve token burning:");
        console.log("");
        console.log("source .env && cast send", address(aiusd));
        console.log("  \"approve(address,uint256)\"");
        console.log("  ", deployer);
        console.log("  ", balance);
        console.log("  --rpc-url $SEPOLIA_RPC_URL");
        console.log("  --private-key [USER_PRIVATE_KEY]");
        console.log("");
        console.log("After approval, run the burn command:");
        console.log("forge script script/execute/BurnOldTokens.s.sol:BurnOldTokensScript");
        console.log("  --sig \"burnOldTokens(address)\"", userAddress);
        console.log("  --rpc-url $SEPOLIA_RPC_URL --broadcast");
    }
}
