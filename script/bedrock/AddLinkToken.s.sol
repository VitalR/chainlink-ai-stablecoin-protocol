// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "forge-std/Script.sol";
import { IERC20 } from "@openzeppelin/token/ERC20/IERC20.sol";

import { CollateralVault } from "src/CollateralVault.sol";
import { SepoliaConfig } from "config/SepoliaConfig.sol";

/// @title Add LINK Token Support
/// @notice Adds LINK token as a supported collateral asset in the vault with price feed and max approval
contract AddLinkTokenScript is Script {
    CollateralVault vault;
    IERC20 linkToken;

    address deployerPublicKey;
    uint256 deployerPrivateKey;

    function setUp() public {
        deployerPublicKey = vm.envAddress("DEPLOYER_PUBLIC_KEY");
        deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");

        vault = CollateralVault(payable(SepoliaConfig.COLLATERAL_VAULT));
        linkToken = IERC20(SepoliaConfig.LINK_TOKEN);
    }

    function run() public {
        vm.startBroadcast(deployerPrivateKey);

        console.log("=== ADDING LINK TOKEN SUPPORT ===");
        console.log("Deployer:", deployerPublicKey);
        console.log("Vault:", address(vault));
        console.log("LINK Token:", SepoliaConfig.LINK_TOKEN);
        console.log("LINK Price Feed:", SepoliaConfig.LINK_USD_PRICE_FEED);
        console.log("");

        // Check if LINK is already supported
        try vault.supportedTokens(SepoliaConfig.LINK_TOKEN) returns (uint256 price, uint8 decimals, bool supported) {
            if (supported) {
                console.log("INFO: LINK token already supported");
                console.log("Current price: $", price / 1e18);
                console.log("Decimals:", decimals);

                // Still set up price feed and approval even if token exists
                _setupPriceFeed();
                _setupMaxApproval();

                vm.stopBroadcast();
                return;
            }
        } catch {
            console.log("LINK token not yet supported, adding...");
        }

        // Add LINK token support
        // LINK current price: ~$20 USD (will be overridden by price feed)
        uint256 linkPriceUSD = 20 * 1e18; // $20 with 18 decimals
        uint8 linkDecimals = 18; // LINK has 18 decimals
        string memory linkSymbol = "LINK";

        try vault.addToken(SepoliaConfig.LINK_TOKEN, linkPriceUSD, linkDecimals, linkSymbol) {
            console.log("SUCCESS: LINK token added as supported collateral");
            console.log("Initial price set to: $", linkPriceUSD / 1e18);
            console.log("Decimals:", linkDecimals);
            console.log("Symbol:", linkSymbol);
        } catch Error(string memory reason) {
            console.log("ERROR adding LINK token:", reason);
            vm.stopBroadcast();
            return;
        }

        // Set up price feed and approval
        _setupPriceFeed();
        _setupMaxApproval();

        vm.stopBroadcast();

        console.log("");
        console.log("=== LINK TOKEN SETUP COMPLETE ===");
        console.log("");
        console.log("LINK token is now supported for:");
        console.log("- Single token deposits");
        console.log("- Multi-token basket deposits");
        console.log("- Bedrock AI analysis");
        console.log("- Dynamic price updates via Chainlink feed");
        console.log("");
        console.log("Ready for deposits! LINK has max approval for the vault.");
    }

    function _setupPriceFeed() internal {
        // Set up official Chainlink LINK/USD price feed
        try vault.setTokenPriceFeed(SepoliaConfig.LINK_TOKEN, SepoliaConfig.LINK_USD_PRICE_FEED) {
            console.log("SUCCESS: LINK price feed configured");
            console.log("Price feed address:", SepoliaConfig.LINK_USD_PRICE_FEED);
            console.log("Now using live Chainlink LINK/USD prices");
        } catch Error(string memory reason) {
            console.log("WARNING: Could not set LINK price feed:", reason);
        }
    }

    function _setupMaxApproval() internal {
        // Check current allowance
        uint256 currentAllowance = linkToken.allowance(deployerPublicKey, address(vault));
        console.log("Current LINK allowance:", currentAllowance);

        // Check deployer's LINK balance
        uint256 linkBalance = linkToken.balanceOf(deployerPublicKey);
        console.log("Deployer LINK balance:", linkBalance / 1e18, "LINK");

        if (currentAllowance < type(uint256).max / 2) {
            try linkToken.approve(address(vault), type(uint256).max) {
                console.log("SUCCESS: Max approval granted for LINK deposits");
                console.log("Vault can now spend unlimited LINK tokens");
            } catch Error(string memory reason) {
                console.log("WARNING: Could not approve LINK:", reason);
            }
        } else {
            console.log("INFO: LINK already has sufficient approval");
        }
    }
}

// Usage:
// source .env && forge script script/bedrock/AddLinkToken.s.sol:AddLinkTokenScript --rpc-url $SEPOLIA_RPC_URL
// --broadcast --private-key $DEPLOYER_PRIVATE_KEY -vv
