// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "forge-std/Script.sol";
import { IERC20 } from "@openzeppelin/token/ERC20/IERC20.sol";

import { AIStablecoin } from "src/AIStablecoin.sol";
import { CollateralVault } from "src/CollateralVault.sol";
import { RiskOracleController } from "src/RiskOracleController.sol";
import { IRiskOracleController } from "src/interfaces/IRiskOracleController.sol";
import { SepoliaConfig } from "config/SepoliaConfig.sol";

/// @title ExecuteDepositWithBedrock - Test AWS Bedrock AI Engine Integration
/// @notice Demonstrates off-chain AI processing via Amazon Bedrock engine
contract ExecuteDepositWithBedrockScript is Script {
    AIStablecoin aiusd;
    CollateralVault vault;
    RiskOracleController controller;

    IERC20 weth;
    IERC20 wbtc;
    IERC20 dai;
    IERC20 usdc;
    IERC20 link;

    address user;
    uint256 userPrivateKey;

    function setUp() public {
        // Get target user (default to DEPLOYER, or USER if specified)
        string memory targetUser = vm.envOr("DEPOSIT_TARGET_USER", string("DEPLOYER"));

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
        weth = IERC20(SepoliaConfig.MOCK_WETH);
        wbtc = IERC20(SepoliaConfig.MOCK_WBTC);
        dai = IERC20(SepoliaConfig.MOCK_DAI);
        usdc = IERC20(SepoliaConfig.MOCK_USDC);
        link = IERC20(SepoliaConfig.LINK_TOKEN);
    }

    /// @notice Check system status before Bedrock deposit
    function checkBedrockSystemStatus() public view {
        console.log("=== BEDROCK AI SYSTEM STATUS ===");
        console.log("Stablecoin address:", address(aiusd));
        console.log("Vault address:", address(vault));
        console.log("Controller address:", address(controller));
        console.log("");

        (bool aiPaused, uint256 failures, uint256 lastFailure, bool operational) = controller.getSystemStatus();
        console.log("AI processing paused:", aiPaused);
        console.log("Circuit breaker active:", !operational);
        console.log("Failure count:", failures);
        console.log("System operational:", operational);
        console.log("");

        console.log("=== USER STATUS ===");
        console.log("User address:", user);
        console.log("User ETH balance:", user.balance);
        console.log("User AIUSD balance:", aiusd.balanceOf(user));

        // Check position summary
        (uint256 totalPositions, uint256 activePositions, uint256 totalValue, uint256 totalMinted) =
            vault.getPositionSummary(user);

        console.log("");
        console.log("=== POSITION SUMMARY ===");
        console.log("Total positions created:", totalPositions);
        console.log("Active positions:", activePositions);
        console.log("Total collateral value: $", totalValue / 1e18);
        console.log("Total AIUSD minted:", totalMinted / 1e18);
        console.log("");
    }

    /// @notice Execute single token Bedrock deposit (DAI)
    function runSingleTokenBedrockDeposit() public {
        vm.startBroadcast(userPrivateKey);

        console.log("=== SINGLE TOKEN BEDROCK DEPOSIT ===");
        console.log("Engine: BEDROCK (Off-chain AWS AI processing)");
        console.log("");

        // Check DAI balance
        uint256 daiBalance = dai.balanceOf(user);
        console.log("User DAI balance:", daiBalance / 1e18, "DAI");

        require(daiBalance >= 100e18, "Need at least 100 DAI for deposit");

        // Prepare single token deposit
        uint256 depositAmount = 100e18; // 100 DAI
        address[] memory tokens = new address[](1);
        uint256[] memory amounts = new uint256[](1);

        tokens[0] = address(dai);
        amounts[0] = depositAmount;

        // Approve DAI
        dai.approve(address(vault), depositAmount);
        console.log("Approved", depositAmount / 1e18, "DAI for vault");

        // Execute Bedrock deposit (no ETH fee needed for off-chain processing)
        console.log("Executing Bedrock deposit with off-chain AI analysis...");
        vault.depositBasket(tokens, amounts, IRiskOracleController.Engine.BEDROCK);

        console.log("SUCCESS: Bedrock deposit executed!");
        console.log("INFO: Note: Request stored for off-chain processing");
        console.log("INFO: Next: Run AWS Bedrock AI analysis");
        console.log("INFO: Then: Process with manual AI result");

        vm.stopBroadcast();
    }

    /// @notice Execute diversified basket Bedrock deposit with LINK
    function runDiversifiedBedrockDeposit() public {
        vm.startBroadcast(userPrivateKey);

        console.log("=== DIVERSIFIED BEDROCK DEPOSIT ===");
        console.log("Engine: BEDROCK (Advanced portfolio analysis)");
        console.log("Portfolio: WETH + WBTC + DAI + LINK");
        console.log("");

        // Check balances
        uint256 wethBalance = weth.balanceOf(user);
        uint256 wbtcBalance = wbtc.balanceOf(user);
        uint256 daiBalance = dai.balanceOf(user);
        uint256 linkBalance = link.balanceOf(user);

        console.log("User balances:");
        console.log("- WETH:", wethBalance / 1e18, "ETH");
        console.log("- WBTC:", wbtcBalance / 1e8, "BTC");
        console.log("- DAI:", daiBalance / 1e18, "DAI");
        console.log("- LINK:", linkBalance / 1e18, "LINK");

        // Diversified portfolio amounts including LINK
        uint256 wethAmount = 0.5e18; // 0.5 ETH (~$1,250)
        uint256 wbtcAmount = 0.001e8; // 0.001 BTC (~$100)
        uint256 daiAmount = 800e18; // 800 DAI (reduced to make room for LINK)
        uint256 linkAmount = 10e18; // 10 LINK (~$200)

        require(wethBalance >= wethAmount, "Insufficient WETH");
        require(wbtcBalance >= wbtcAmount, "Insufficient WBTC");
        require(daiBalance >= daiAmount, "Insufficient DAI");
        require(linkBalance >= linkAmount, "Insufficient LINK");

        // Prepare basket
        address[] memory tokens = new address[](4);
        uint256[] memory amounts = new uint256[](4);

        tokens[0] = address(weth);
        amounts[0] = wethAmount;
        tokens[1] = address(wbtc);
        amounts[1] = wbtcAmount;
        tokens[2] = address(dai);
        amounts[2] = daiAmount;
        tokens[3] = address(link);
        amounts[3] = linkAmount;

        // Approve all tokens
        weth.approve(address(vault), wethAmount);
        wbtc.approve(address(vault), wbtcAmount);
        dai.approve(address(vault), daiAmount);
        link.approve(address(vault), linkAmount);
        console.log("Approved all tokens for diversified basket with LINK");

        console.log("");
        console.log("Portfolio composition:");
        console.log("- WETH: 0.5 ETH (~$1,250)");
        console.log("- WBTC: 0.001 BTC (~$100)");
        console.log("- DAI: 800 DAI");
        console.log("- LINK: 10 LINK (~$200)");
        console.log("Expected total: ~$2,350");

        // Execute Bedrock deposit
        console.log("");
        console.log("Executing diversified Bedrock deposit with LINK...");
        vault.depositBasket(tokens, amounts, IRiskOracleController.Engine.BEDROCK);

        console.log("SUCCESS: Diversified Bedrock deposit executed!");
        console.log("INFO: Advanced portfolio analysis queued");
        console.log("INFO: AWS Bedrock will analyze:");
        console.log("   - Diversification risk (HHI calculation)");
        console.log("   - Volatility assessment");
        console.log("   - Liquidity evaluation");
        console.log("   - Market conditions");
        console.log("   - LINK ecosystem exposure");

        vm.stopBroadcast();
    }

    /// @notice Execute LINK-focused Bedrock deposit
    function runLinkBedrockDeposit() public {
        vm.startBroadcast(userPrivateKey);

        console.log("=== LINK-FOCUSED BEDROCK DEPOSIT ===");
        console.log("Engine: BEDROCK (Chainlink ecosystem analysis)");
        console.log("Portfolio: LINK + DAI");
        console.log("");

        // Check balances
        uint256 linkBalance = link.balanceOf(user);
        uint256 daiBalance = dai.balanceOf(user);

        console.log("User balances:");
        console.log("- LINK:", linkBalance / 1e18, "LINK");
        console.log("- DAI:", daiBalance / 1e18, "DAI");

        // LINK-focused portfolio
        uint256 linkAmount = 50e18; // 50 LINK (~$1,000)
        uint256 daiAmount = 500e18; // 500 DAI for stability

        require(linkBalance >= linkAmount, "Insufficient LINK");
        require(daiBalance >= daiAmount, "Insufficient DAI");

        address[] memory tokens = new address[](2);
        uint256[] memory amounts = new uint256[](2);

        tokens[0] = address(link);
        amounts[0] = linkAmount;
        tokens[1] = address(dai);
        amounts[1] = daiAmount;

        // Approve tokens
        link.approve(address(vault), linkAmount);
        dai.approve(address(vault), daiAmount);

        console.log("LINK-focused portfolio:");
        console.log("- LINK: 50 LINK (~$1,000)");
        console.log("- DAI: 500 DAI");
        console.log("Expected total: ~$1,500");
        console.log("");

        console.log("Executing LINK-focused Bedrock deposit...");
        vault.depositBasket(tokens, amounts, IRiskOracleController.Engine.BEDROCK);

        console.log("SUCCESS: LINK-focused Bedrock deposit executed!");
        console.log("INFO: Chainlink ecosystem analysis queued");
        console.log("INFO: Expected Bedrock advantages:");
        console.log("   - Deep LINK tokenomics analysis");
        console.log("   - Chainlink ecosystem correlation assessment");
        console.log("   - Oracle network utilization patterns");

        vm.stopBroadcast();
    }

    /// @notice Execute high-value Bedrock deposit for institutional testing
    function runInstitutionalBedrockDeposit() public {
        vm.startBroadcast(userPrivateKey);

        console.log("=== INSTITUTIONAL BEDROCK DEPOSIT ===");
        console.log("Engine: BEDROCK (Enterprise-grade analysis)");
        console.log("Use case: Large institutional position");
        console.log("");

        // Large amounts for institutional testing
        uint256 wethAmount = 2e18; // 2 ETH (~$5,000)
        uint256 daiAmount = 5000e18; // 5000 DAI

        require(weth.balanceOf(user) >= wethAmount, "Insufficient WETH for institutional deposit");
        require(dai.balanceOf(user) >= daiAmount, "Insufficient DAI for institutional deposit");

        address[] memory tokens = new address[](2);
        uint256[] memory amounts = new uint256[](2);

        tokens[0] = address(weth);
        amounts[0] = wethAmount;
        tokens[1] = address(dai);
        amounts[1] = daiAmount;

        // Approve tokens
        weth.approve(address(vault), wethAmount);
        dai.approve(address(vault), daiAmount);

        console.log("Institutional portfolio:");
        console.log("- WETH: 2 ETH (~$5,000)");
        console.log("- DAI: 5000 DAI");
        console.log("Expected total: ~$10,000");
        console.log("");

        console.log("Executing institutional Bedrock deposit...");
        vault.depositBasket(tokens, amounts, IRiskOracleController.Engine.BEDROCK);

        console.log("SUCCESS: Institutional Bedrock deposit executed!");
        console.log("INFO: Enterprise-grade risk assessment queued");
        console.log("INFO: Expected Bedrock advantages:");
        console.log("   - Sophisticated AI analysis");
        console.log("   - Better capital efficiency");
        console.log("   - Risk-adjusted positioning");

        vm.stopBroadcast();
    }

    /// @notice Display Bedrock vs other engines comparison
    function demonstrateBedrockAdvantages() public view {
        console.log("=== BEDROCK vs OTHER ENGINES ===");
        console.log("");

        console.log("ALGO Engine (Chainlink Functions):");
        console.log("- Success Rate: 99.9%+");
        console.log("- Processing Time: 30s - 2 minutes");
        console.log("- Capital Efficiency: 65-75%");
        console.log("- Use Case: Reliable fallback");
        console.log("");

        console.log("BEDROCK Engine (AWS AI):");
        console.log("- Success Rate: 100% (manual processing)");
        console.log("- Processing Time: 2-10 minutes");
        console.log("- Capital Efficiency: 70-90%");
        console.log("- Use Case: Primary AI analysis");
        console.log("- Features: Advanced portfolio analysis");
        console.log("");

        console.log("TEST_TIMEOUT Engine:");
        console.log("- Use Case: Testing emergency mechanisms");
        console.log("- Simulates stuck requests");
        console.log("");

        console.log("TIP: Why use BEDROCK:");
        console.log("1. Enterprise-grade Amazon Bedrock AI");
        console.log("2. Claude 3 Sonnet model reasoning");
        console.log("3. Advanced portfolio diversification analysis");
        console.log("4. Guaranteed processing (manual fallback)");
        console.log("5. Superior capital efficiency");
        console.log("6. Deep LINK/Chainlink ecosystem analysis");

        console.log("RESULT: BEDROCK Engine provides the most sophisticated");
        console.log("   AI analysis with guaranteed completion!");
    }

    /// @notice Main execution function
    function run() public {
        console.log("AI STABLECOIN BEDROCK ENGINE TESTING");
        console.log("====================================");
        console.log("Testing AWS Bedrock off-chain AI processing");
        console.log("");

        // Check system status
        checkBedrockSystemStatus();
        demonstrateBedrockAdvantages();

        // Choose scenario based on environment variable
        string memory scenario = vm.envOr("BEDROCK_SCENARIO", string("single"));

        console.log("");
        console.log("Executing Bedrock scenario:", scenario);
        console.log("====================================");

        if (keccak256(bytes(scenario)) == keccak256(bytes("single"))) {
            runSingleTokenBedrockDeposit();
        } else if (keccak256(bytes(scenario)) == keccak256(bytes("diversified"))) {
            runDiversifiedBedrockDeposit();
        } else if (keccak256(bytes(scenario)) == keccak256(bytes("institutional"))) {
            runInstitutionalBedrockDeposit();
        } else if (keccak256(bytes(scenario)) == keccak256(bytes("link"))) {
            runLinkBedrockDeposit();
        } else {
            console.log("Available scenarios: single, diversified, institutional, link");
            console.log("Using default: single");
            runSingleTokenBedrockDeposit();
        }

        console.log("");
        console.log("=== NEXT STEPS ===");
        console.log("1. Run AWS Bedrock AI analysis:");
        console.log("   cd test/standalone && node TestBedrockDirect.js");
        console.log("");
        console.log("2. Process with AI result:");
        console.log("   forge script script/execute/ProcessManualRequest.s.sol \\");
        console.log("   --sig \"processWithAIResponse(uint256,string)\" \\");
        console.log("   $REQUEST_ID \"RATIO:150 CONFIDENCE:75 SOURCE:BEDROCK_AI\"");
        console.log("");
        console.log("SCENARIOS: single, diversified, institutional, link");
        console.log("RESULT: BEDROCK Engine provides the most sophisticated");
        console.log("   AI analysis with guaranteed completion!");
    }
}

// =============================================================
//                       USAGE COMMANDS
// =============================================================

// Check Bedrock System Status:
// source .env && forge script script/execute/ExecuteDepositWithBedrock.s.sol:ExecuteDepositWithBedrockScript --sig
// "checkBedrockSystemStatus()" --rpc-url $SEPOLIA_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY -vv

// Single Token Bedrock Deposit (100 DAI):
// source .env && forge script script/execute/ExecuteDepositWithBedrock.s.sol:ExecuteDepositWithBedrockScript --rpc-url
// $SEPOLIA_RPC_URL --broadcast --private-key $DEPLOYER_PRIVATE_KEY -vv

// Diversified Bedrock Deposit (WETH + WBTC + DAI + LINK):
// source .env && BEDROCK_SCENARIO=diversified forge script
// script/bedrock/ExecuteDepositWithBedrock.s.sol:ExecuteDepositWithBedrockScript --rpc-url $SEPOLIA_RPC_URL --broadcast
// --private-key $DEPLOYER_PRIVATE_KEY -vv

// Institutional Bedrock Deposit (Large amounts):
// source .env && BEDROCK_SCENARIO=institutional forge script
// script/bedrock/ExecuteDepositWithBedrock.s.sol:ExecuteDepositWithBedrockScript --rpc-url $SEPOLIA_RPC_URL --broadcast
// --private-key $DEPLOYER_PRIVATE_KEY -vv

// LINK-Focused Bedrock Deposit (LINK + DAI):
// source .env && BEDROCK_SCENARIO=link forge script
// script/bedrock/ExecuteDepositWithBedrock.s.sol:ExecuteDepositWithBedrockScript --rpc-url $SEPOLIA_RPC_URL --broadcast
// --private-key $DEPLOYER_PRIVATE_KEY -vv

// Demonstrate Bedrock Advantages:
// source .env && forge script script/execute/ExecuteDepositWithBedrock.s.sol:ExecuteDepositWithBedrockScript --sig
// "demonstrateBedrockAdvantages()" --rpc-url $SEPOLIA_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY -vv
