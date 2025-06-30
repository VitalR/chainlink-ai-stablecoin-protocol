// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "forge-std/Script.sol";
import { SepoliaConfig } from "config/SepoliaConfig.sol";

/// @title Test token interface with mint function
interface IMintableToken {
    function mint(address account, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function symbol() external view returns (string memory);
}

/// @title MintTestTokens - Mint test tokens to user account for testing
/// @notice Mints test tokens (DAI, WETH, WBTC) to user account for deposit testing
contract MintTestTokensScript is Script {
    address user;
    uint256 userPrivateKey;

    function setUp() public {
        // Get target user (default to USER, or USER_2 if specified)
        string memory targetUser = vm.envOr("MINT_TARGET_USER", string("USER"));

        if (keccak256(abi.encodePacked(targetUser)) == keccak256(abi.encodePacked("USER_2"))) {
            user = vm.envAddress("USER_2_PUBLIC_KEY");
            userPrivateKey = vm.envUint("USER_2_PRIVATE_KEY");
            console.log("Using USER_2 credentials");
        } else {
            user = vm.envAddress("USER_PUBLIC_KEY");
            userPrivateKey = vm.envUint("USER_PRIVATE_KEY");
            console.log("Using USER credentials");
        }
    }

    /// @notice Mint generous amounts of test tokens to user
    function mintTokensToUser() public {
        vm.startBroadcast(userPrivateKey);

        console.log("=== Minting Test Tokens to User ===");
        console.log("User address:", user);

        // Initialize token contracts
        IMintableToken dai = IMintableToken(SepoliaConfig.MOCK_DAI);
        IMintableToken weth = IMintableToken(SepoliaConfig.MOCK_WETH);
        IMintableToken wbtc = IMintableToken(SepoliaConfig.MOCK_WBTC);

        // Mint amounts (generous for testing)
        uint256 daiAmount = 10_000 * 1e18; // 10,000 DAI
        uint256 wethAmount = 10 * 1e18; // 10 WETH
        uint256 wbtcAmount = 1 * 1e18; // 1 WBTC (note: using 18 decimals in test contract)

        console.log("\n=== Minting Tokens ===");

        // Mint DAI
        dai.mint(user, daiAmount);
        console.log("Minted DAI:", daiAmount);
        console.log("DAI balance:", dai.balanceOf(user));

        // Mint WETH
        weth.mint(user, wethAmount);
        console.log("Minted WETH:", wethAmount);
        console.log("WETH balance:", weth.balanceOf(user));

        // Mint WBTC
        wbtc.mint(user, wbtcAmount);
        console.log("Minted WBTC:", wbtcAmount);
        console.log("WBTC balance:", wbtc.balanceOf(user));

        console.log("\n[+] All test tokens minted successfully!");

        vm.stopBroadcast();
    }

    /// @notice Check current token balances
    function checkBalances() public view {
        console.log("=== Current Token Balances ===");
        console.log("User address:", user);

        IMintableToken dai = IMintableToken(SepoliaConfig.MOCK_DAI);
        IMintableToken weth = IMintableToken(SepoliaConfig.MOCK_WETH);
        IMintableToken wbtc = IMintableToken(SepoliaConfig.MOCK_WBTC);

        console.log("DAI balance:", dai.balanceOf(user));
        console.log("WETH balance:", weth.balanceOf(user));
        console.log("WBTC balance:", wbtc.balanceOf(user));
        console.log("ETH balance:", user.balance);
    }

    /// @notice Main run function
    function run() public {
        console.log("AI Stablecoin Test Token Minter");
        console.log("==================================");

        // Check current balances
        checkBalances();

        // Mint tokens
        mintTokensToUser();

        console.log("\n[+] Ready for deposit testing!");
        console.log("You can now run:");
        console.log(
            "DEPOSIT_SCENARIO=single forge script script/ExecuteDeposit.s.sol --fork-url $SEPOLIA_RPC_URL --broadcast"
        );
    }
}

// Usage:
// source .env && forge script script/MintTestTokens.s.sol:MintTestTokensScript --fork-url $SEPOLIA_RPC_URL --broadcast
// -vvv
