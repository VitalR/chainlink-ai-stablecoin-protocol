// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "forge-std/Script.sol";
import { IERC20 } from "@openzeppelin/token/ERC20/IERC20.sol";

import { AIStablecoin } from "src/AIStablecoin.sol";
import { CollateralVault } from "src/CollateralVault.sol";
import { RiskOracleController } from "src/RiskOracleController.sol";
import { SepoliaConfig } from "config/SepoliaConfig.sol";

/// @title Complete Flow Test Script
/// @notice Tests the full AI-powered stablecoin system on Sepolia with real Chainlink Functions
contract TestCompleteFlowScript is Script {
    
    AIStablecoin public stablecoin;
    RiskOracleController public riskOracle;
    CollateralVault public vault;
    
    // Mock tokens
    IERC20 public mockDAI;
    IERC20 public mockWETH;
    IERC20 public mockWBTC;
    IERC20 public mockUSDC;
    
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployerAddress = vm.addr(deployerPrivateKey);
        
        console.log("=== AI-Powered Stablecoin Complete Flow Test ===");
        console.log("Deployer address:", deployerAddress);
        console.log("Chain ID:", block.chainid);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Load deployed contracts
        stablecoin = AIStablecoin(SepoliaConfig.AI_STABLECOIN);
        riskOracle = RiskOracleController(SepoliaConfig.RISK_ORACLE_CONTROLLER);
        vault = CollateralVault(payable(SepoliaConfig.COLLATERAL_VAULT));
        
        // Load mock tokens
        mockDAI = IERC20(SepoliaConfig.MOCK_DAI);
        mockWETH = IERC20(SepoliaConfig.MOCK_WETH);
        mockWBTC = IERC20(SepoliaConfig.MOCK_WBTC);
        mockUSDC = IERC20(SepoliaConfig.MOCK_USDC);
        
        console.log("\\n=== Contract Addresses ===");
        console.log("Stablecoin:", address(stablecoin));
        console.log("Risk Oracle:", address(riskOracle));
        console.log("Vault:", address(vault));
        
        // Step 1: System Status Check
        _testSystemStatus();
        
        // Step 2: Price Feed Check
        _testPriceFeeds();
        
        // Step 3: Token Balance Check
        _checkTokenBalances(deployerAddress);
        
        // Step 4: Real AI-Powered Deposit Test
        _testRealAIDeposit(deployerAddress);
        
        vm.stopBroadcast();
        
        console.log("\\n=== Test Complete ===");
        console.log("Check your Chainlink Functions subscription for request activity!");
        console.log("Monitor the transaction for AI callback results.");
    }
    
    function _testSystemStatus() internal view {
        console.log("\\n=== System Status Check ===");
        
        (bool paused, uint256 failures, uint256 lastFailure, bool circuitBreakerActive) = riskOracle.getSystemStatus();
        console.log("Processing paused:", paused);
        console.log("Failure count:", failures);
        console.log("Circuit breaker active:", circuitBreakerActive);
        
        // Check AI source code
        string memory aiCode = riskOracle.aiSourceCode();
        console.log("AI source code length:", bytes(aiCode).length);
        
        require(!paused, "System is paused!");
        require(!circuitBreakerActive, "Circuit breaker is active!");
        require(bytes(aiCode).length > 1000, "AI source code not properly set!");
        
        console.log("System status: OPERATIONAL");
    }
    
    function _testPriceFeeds() internal view {
        console.log("\\n=== Price Feed Check ===");
        
        int256 ethPrice = riskOracle.getLatestPrice("ETH");
        int256 btcPrice = riskOracle.getLatestPrice("BTC");
        int256 linkPrice = riskOracle.getLatestPrice("LINK");
        int256 daiPrice = riskOracle.getLatestPrice("DAI");
        int256 usdcPrice = riskOracle.getLatestPrice("USDC");
        
        console.log("ETH/USD: $", uint256(ethPrice) / 1e8);
        console.log("BTC/USD: $", uint256(btcPrice) / 1e8);
        console.log("LINK/USD: $", uint256(linkPrice) / 1e8);
        console.log("DAI/USD: $", uint256(daiPrice) / 1e8);
        console.log("USDC/USD: $", uint256(usdcPrice) / 1e8);
        
        require(ethPrice > 0, "ETH price feed not working");
        require(btcPrice > 0, "BTC price feed not working");
        
        console.log("Price feeds: WORKING");
    }
    
    function _checkTokenBalances(address user) internal view {
        console.log("\\n=== Token Balance Check ===");
        
        uint256 daiBalance = mockDAI.balanceOf(user);
        uint256 wethBalance = mockWETH.balanceOf(user);
        uint256 wbtcBalance = mockWBTC.balanceOf(user);
        uint256 usdcBalance = mockUSDC.balanceOf(user);
        
        console.log("DAI balance:", daiBalance / 1e18);
        console.log("WETH balance:", wethBalance / 1e18);
        console.log("WBTC balance:", wbtcBalance / 1e8);
        console.log("USDC balance:", usdcBalance / 1e6);
        
        if (daiBalance == 0 && wethBalance == 0 && wbtcBalance == 0 && usdcBalance == 0) {
            console.log("WARNING: No token balances found. You may need to mint test tokens first.");
            console.log("Run: forge script script/deploy/00_DeployTestTokens.s.sol --broadcast");
        } else {
            console.log("Token balances: AVAILABLE");
        }
    }
    
    function _testRealAIDeposit(address user) internal {
        console.log("\\n=== Real AI-Powered Deposit Test ===");
        
        // Check if we have tokens to deposit
        uint256 daiBalance = mockDAI.balanceOf(user);
        uint256 wethBalance = mockWETH.balanceOf(user);
        
        if (daiBalance < 1000 * 1e18 || wethBalance < 1 * 1e18) {
            console.log("INSUFFICIENT token balance for deposit test");
            console.log("Need: 1000 DAI and 1 WETH minimum");
            return;
        }
        
        // Create a conservative portfolio: 70% DAI, 30% WETH
        address[] memory tokens = new address[](2);
        uint256[] memory amounts = new uint256[](2);
        
        tokens[0] = address(mockDAI);
        amounts[0] = 1000 * 1e18; // 1,000 DAI
        
        tokens[1] = address(mockWETH);
        amounts[1] = 0.5 * 1e18; // 0.5 WETH
        
        console.log("Portfolio to deposit:");
        console.log("- DAI:", amounts[0] / 1e18);
        console.log("- WETH:", amounts[1] / 1e18);
        
        // Approve tokens
        mockDAI.approve(address(vault), amounts[0]);
        mockWETH.approve(address(vault), amounts[1]);
        
        console.log("Tokens approved for vault spending");
        
        // Record balances before
        uint256 stablecoinsBefore = stablecoin.balanceOf(user);
        
        console.log("\\nInitiating AI-powered deposit...");
        console.log("This will trigger real Chainlink Functions execution!");
        
        // Make the deposit - this triggers the AI assessment!
        vault.depositBasket(tokens, amounts);
        
        // Get the request ID
        (, , , , , uint256 requestId, ) = vault.getPosition(user);
        
        console.log("\\nAI Request Submitted Successfully!");
        console.log("Request ID:", requestId);
        console.log("\\nWaiting for AI assessment...");
        console.log("Your JavaScript AI code is now running on Chainlink Functions!");
        console.log("\\nWhat's happening:");
        console.log("1. Your AI code analyzes the portfolio risk");
        console.log("2. Calculates optimal collateral ratio (125-200%)");
        console.log("3. Returns assessment to your contract");
        console.log("4. Contract mints stablecoins based on AI recommendation");
        
        console.log("\\nMonitor progress:");
        console.log("- Check Chainlink Functions subscription for activity");
        console.log("- Watch for callback transaction");
        console.log("- Stablecoins will be minted automatically upon AI completion");
        
        // Check if we already have a response (in case of very fast processing)
        uint256 stablescoinsAfter = stablecoin.balanceOf(user);
        if (stablescoinsAfter > stablecoinsBefore) {
            console.log("\\nAI Assessment Completed Instantly!");
            console.log("Stablecoins minted:", (stablescoinsAfter - stablecoinsBefore) / 1e18);
        } else {
            console.log("\\nAI processing in progress...");
            console.log("Check back in 1-2 minutes for results!");
        }
    }
}

// Usage:
// source .env && forge script script/test/TestCompleteAIFlow.s.sol:TestCompleteAIFlowScript --rpc-url $SEPOLIA_RPC_URL --broadcast -vvv 