// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "forge-std/Script.sol";

import { MockDAI } from "test/mocks/MockDAI.sol";
import { MockWETH } from "test/mocks/MockWETH.sol";
import { MockWBTC } from "test/mocks/MockWBTC.sol";
import { MockUSDC } from "test/mocks/MockUSDC.sol";
import { MockOUSG } from "test/mocks/MockOUSG.sol";
import { MockRWAPriceFeed } from "test/mocks/MockRWAPriceFeed.sol";

/// @title Deploy Tokens Script
/// @notice Deploys all foundational tokens: test tokens (DAI, WETH, WBTC, USDC) and RWA tokens (OUSG + price feed)
contract DeployTokensScript is Script {
    // Test tokens
    MockDAI dai;
    MockWETH weth;
    MockWBTC wbtc;
    MockUSDC usdc;
    
    // RWA tokens
    MockOUSG ousg;
    MockRWAPriceFeed ousgPriceFeed;
    
    address deployerPublicKey;
    uint256 deployerPrivateKey;

    function setUp() public {
        deployerPublicKey = vm.envAddress("DEPLOYER_PUBLIC_KEY");
        deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
    }

    function run() public {
        vm.startBroadcast(deployerPrivateKey);
        
        console.log("=== Deploying All Foundational Tokens ===");
        
        // Deploy test tokens
        console.log("Deploying test tokens...");
        dai = new MockDAI();
        weth = new MockWETH();
        wbtc = new MockWBTC();
        usdc = new MockUSDC();
        
        console.log("Test tokens deployed:");
        console.log("==DAI addr=%s", address(dai));
        console.log("==WETH addr=%s", address(weth));
        console.log("==WBTC addr=%s", address(wbtc));
        console.log("==USDC addr=%s", address(usdc));
        
        // Deploy RWA tokens
        console.log("\nDeploying RWA infrastructure...");
        ousg = new MockOUSG();
        console.log("==OUSG addr=%s", address(ousg));
        
        ousgPriceFeed = new MockRWAPriceFeed(
            "OUSG / USD",
            10000000000, // $100.00 in 8 decimals
            500,         // 5.0% annual yield (500 basis points)
            false        // Not stable - appreciates over time
        );
        console.log("==OUSG Price Feed addr=%s", address(ousgPriceFeed));
        
        // Mint initial OUSG supply
        ousg.mint(deployerPublicKey, 1000000 * 1e18); // 1M OUSG
        console.log("==Minted 1,000,000 OUSG to deployer");
        
        vm.stopBroadcast();
        
        console.log("\n=== Token Deployment Complete ===");
        console.log("==========================================");
        console.log("Test Tokens: DAI, WETH, WBTC, USDC");
        console.log("RWA Tokens: OUSG + USD Price Feed");
        console.log("==========================================");
        
        console.log("\n=== NEXT STEPS ===");
        console.log("1. Update SepoliaConfig.sol with all deployed addresses");
        console.log("2. Continue with stablecoin deployment");
        console.log("3. RWA price feeds will be auto-configured in RiskOracleController");
    }
}

// DEPLOYMENT COMMENTS:
// - Unified token deployment (test + RWA) ensures proper dependency sequencing
// - RWA price feeds will be auto-integrated by RiskOracleController during deployment
// - This resolves the dependency issue where OUSG_USD_PRICE_FEED must exist before oracle deployment

// source .env && forge script script/deploy/00_DeployTokens.s.sol:DeployTokensScript --rpc-url $SEPOLIA_RPC_URL
// --private-key $DEPLOYER_PRIVATE_KEY --broadcast --etherscan-api-key $ETHERSCAN_API_KEY --verify -vvvv
