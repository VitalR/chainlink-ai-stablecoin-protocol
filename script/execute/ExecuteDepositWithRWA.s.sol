// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "forge-std/Script.sol";
import { IERC20 } from "@openzeppelin/token/ERC20/IERC20.sol";

import { AIStablecoin } from "src/AIStablecoin.sol";
import { CollateralVault } from "src/CollateralVault.sol";
import { RiskOracleController } from "src/RiskOracleController.sol";
import { MockOUSG } from "test/mocks/MockOUSG.sol";
import { MockRWAPriceFeed } from "test/mocks/MockRWAPriceFeed.sol";
import { SepoliaConfig } from "config/SepoliaConfig.sol";

/// @title ExecuteDepositWithRWA - Demonstrate OUSG RWA deposit scenarios
/// @notice Executes institutional Treasury collateral deposits with AI-enhanced ratios
contract ExecuteDepositWithRWAScript is Script {
    AIStablecoin aiusd;
    CollateralVault vault;
    RiskOracleController controller;

    MockOUSG ousg;
    MockRWAPriceFeed ousgPriceFeed;
    IERC20 weth;
    IERC20 dai;

    address user;
    uint256 userPrivateKey;

    function setUp() public {
        // Get target user credentials
        string memory targetUser = vm.envOr("DEPOSIT_TARGET_USER", string("DEPLOYER"));

        if (keccak256(abi.encodePacked(targetUser)) == keccak256(abi.encodePacked("USER"))) {
            user = vm.envAddress("USER_PUBLIC_KEY");
            userPrivateKey = vm.envUint("USER_PRIVATE_KEY");
            console.log("Using USER credentials for RWA deposit");
        } else {
            user = vm.envAddress("DEPLOYER_PUBLIC_KEY");
            userPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
            console.log("Using DEPLOYER credentials for RWA deposit");
        }

        // Initialize core contracts
        aiusd = AIStablecoin(SepoliaConfig.AI_STABLECOIN);
        vault = CollateralVault(payable(SepoliaConfig.COLLATERAL_VAULT));
        controller = RiskOracleController(SepoliaConfig.RISK_ORACLE_CONTROLLER);

        // Initialize RWA tokens
        ousg = MockOUSG(SepoliaConfig.MOCK_OUSG);
        ousgPriceFeed = MockRWAPriceFeed(SepoliaConfig.OUSG_USD_PRICE_FEED);

        // Initialize comparison tokens
        weth = IERC20(SepoliaConfig.MOCK_WETH);
        dai = IERC20(SepoliaConfig.MOCK_DAI);
    }

    /// @notice Execute institutional OUSG deposit
    function runInstitutionalOUSGDeposit() public {
        vm.startBroadcast(userPrivateKey);

        console.log("=== Institutional OUSG Treasury Deposit ===");

        // 1. Check OUSG balance and price
        uint256 ousgBalance = ousg.balanceOf(user);
        uint256 ousgPrice = ousg.pricePerToken();

        console.log("User OUSG balance:", ousgBalance / 1e18, "OUSG");
        console.log("Current OUSG price: $", ousgPrice / 1e18);
        console.log("OUSG type: Treasury-backed appreciating asset");

        require(ousgBalance >= 100e18, "Need at least 100 OUSG for institutional deposit");

        // 2. Prepare institutional deposit (100 OUSG = $10,000 minimum)
        uint256 depositAmount = 100e18; // 100 OUSG
        address[] memory tokens = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        tokens[0] = address(ousg);
        amounts[0] = depositAmount;

        uint256 depositValueUSD = depositAmount * ousgPrice / 1e18;
        console.log("Deposit value: $", depositValueUSD / 1e18);

        // 3. Approve OUSG
        ousg.approve(address(vault), depositAmount);
        console.log("Approved", depositAmount / 1e18, "OUSG for vault");

        // 4. Get AI fee and execute deposit
        uint256 aiFee = controller.estimateTotalFee();
        console.log("AI assessment fee:", aiFee, "wei");
        require(user.balance >= aiFee, "Insufficient ETH for AI fee");

        console.log("Executing OUSG deposit with AI risk assessment...");
        vault.depositBasket{ value: aiFee }(tokens, amounts);
        console.log("OUSG deposit executed successfully!");

        // 5. Check position
        (
            address[] memory depositedTokens,
            uint256[] memory depositedAmounts,
            uint256 totalValue,
            uint256 aiusdMinted,
            uint256 collateralRatio,
            uint256 requestId,
            bool hasPendingRequest
        ) = vault.getPosition(user);

        console.log("=== Position Created ===");
        console.log("Total collateral value: $", totalValue / 1e18);
        console.log("OUSG deposited:", depositedAmounts[0] / 1e18, "tokens");
        console.log("AI Request ID:", requestId);
        console.log("Pending AI assessment:", hasPendingRequest);

        // 6. Display expected AI benefits
        console.log("=== Expected AI Benefits ===");
        console.log("Standard crypto ratio: 150% (66.7% LTV)");
        console.log("Expected OUSG ratio: 100-120% (80-100% LTV)");
        console.log("Treasury backing bonus: Government guarantee");
        console.log("Volatility bonus: <1% vs 20%+ crypto");
        console.log("Institutional grade: AAA credit rating");

        vm.stopBroadcast();
    }

    /// @notice Execute large institutional OUSG deposit ($500k+)
    function runLargeInstitutionalDeposit() public {
        vm.startBroadcast(userPrivateKey);

        console.log("=== Large Institutional OUSG Deposit ($500k+) ===");

        uint256 ousgBalance = ousg.balanceOf(user);
        uint256 ousgPrice = ousg.pricePerToken();

        // Large institutional deposit: 5000 OUSG = $500k
        uint256 largeDepositAmount = 5000e18;
        require(ousgBalance >= largeDepositAmount, "Need at least 5000 OUSG for large institutional deposit");

        address[] memory tokens = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        tokens[0] = address(ousg);
        amounts[0] = largeDepositAmount;

        uint256 depositValueUSD = largeDepositAmount * ousgPrice / 1e18;
        console.log("Large institutional deposit: $", depositValueUSD / 1e18);
        console.log("Asset type: US Treasury bonds via OUSG");
        console.log("Use case: Leverage Treasury holdings without selling");

        ousg.approve(address(vault), largeDepositAmount);
        uint256 aiFee = controller.estimateTotalFee();

        vault.depositBasket{ value: aiFee }(tokens, amounts);
        console.log("Large institutional OUSG deposit completed!");

        // Check position
        (,, uint256 totalValue,,, uint256 requestId, bool hasPendingRequest) = vault.getPosition(user);

        console.log("=== Large Position Summary ===");
        console.log("Total value: $", totalValue / 1e18);
        console.log("Request ID:", requestId);
        console.log("Status: Pending AI assessment");
        console.log("Expected advantage: 25-50% better terms vs crypto");

        vm.stopBroadcast();
    }

    /// @notice Execute mixed portfolio deposit (OUSG + crypto)
    function runMixedPortfolioDeposit() public {
        vm.startBroadcast(userPrivateKey);

        console.log("=== Mixed Portfolio Deposit (OUSG + Crypto) ===");

        // Check balances
        uint256 ousgBalance = ousg.balanceOf(user);
        uint256 wethBalance = weth.balanceOf(user);
        uint256 ousgPrice = ousg.pricePerToken();

        console.log("Available balances:");
        console.log("- OUSG:", ousgBalance / 1e18, "tokens");
        console.log("- OUSG value: $", (ousgBalance * ousgPrice / 1e18) / 1e18);
        console.log("- WETH:", wethBalance / 1e18, "ETH");

        // Mixed portfolio: 50 OUSG + 1 ETH
        uint256 ousgAmount = 50e18; // $5,000 in OUSG
        uint256 wethAmount = 1e18; // 1 ETH (~$2,500)

        require(ousgBalance >= ousgAmount, "Insufficient OUSG");
        require(wethBalance >= wethAmount, "Insufficient WETH");

        address[] memory tokens = new address[](2);
        uint256[] memory amounts = new uint256[](2);
        tokens[0] = address(ousg); // Treasury asset first
        amounts[0] = ousgAmount;
        tokens[1] = address(weth); // Crypto asset second
        amounts[1] = wethAmount;

        // Approve both tokens
        ousg.approve(address(vault), ousgAmount);
        weth.approve(address(vault), wethAmount);

        console.log("Portfolio composition:");
        console.log("- Treasury (OUSG): $", (ousgAmount * ousgPrice / 1e18) / 1e18);
        console.log("- Crypto (WETH): ~$2,500");
        console.log("Expected AI benefit: Blended ratio improvement");

        uint256 aiFee = controller.estimateTotalFee();
        vault.depositBasket{ value: aiFee }(tokens, amounts);

        console.log("Mixed portfolio deposit executed!");

        vm.stopBroadcast();
    }

    /// @notice Demonstrate OUSG vs crypto comparison
    function demonstrateOUSGAdvantage() public view {
        console.log("=== OUSG vs Crypto Collateral Comparison ===");

        uint256 ousgPrice = ousg.pricePerToken();
        (, int256 priceFeedAnswer,,,) = ousgPriceFeed.latestRoundData();

        console.log("OUSG Token Analysis:");
        console.log("- Current price: $", ousgPrice / 1e18);
        console.log("- Price feed: $", uint256(priceFeedAnswer) / 1e8);
        console.log("- Backing: US Treasury bonds");
        console.log("- Yield: 5% annual appreciation");
        console.log("- Volatility: <1% (government bonds)");
        console.log("- Liquidity: Institutional grade");

        console.log("");
        console.log("Expected AI Assessment:");
        console.log("CRYPTO COLLATERAL:");
        console.log("- Standard ratio: 150%");
        console.log("- LTV: 66.7%");
        console.log("- Risk: High volatility (20%+)");

        console.log("");
        console.log("OUSG COLLATERAL (Treasury-backed):");
        console.log("- Expected ratio: 100-120%");
        console.log("- LTV: 80-100%");
        console.log("- Risk: Ultra-low (government guaranteed)");
        console.log("- Advantage: 25-50% better capital efficiency");

        console.log("");
        console.log("BUSINESS IMPACT:");
        console.log("- Treasury holders keep yield exposure");
        console.log("- Access DeFi liquidity without selling");
        console.log("- Superior borrowing terms vs crypto");
        console.log("- Institutional-grade TradFi <-> DeFi bridge");
    }

    /// @notice Check RWA system status
    function checkRWAStatus() public view {
        console.log("=== RWA System Status ===");
        console.log("OUSG Token:", address(ousg));
        console.log("OUSG Price Feed:", address(ousgPriceFeed));
        console.log("Current OUSG price: $", ousg.pricePerToken() / 1e18);

        (, int256 feedPrice,,,) = ousgPriceFeed.latestRoundData();
        console.log("Price feed value: $", uint256(feedPrice) / 1e8);

        // Check vault supports OUSG
        (uint256 priceUSD, uint8 decimals, bool supported) = vault.supportedTokens(address(ousg));
        console.log("Vault OUSG support:");
        console.log("- Supported:", supported);
        console.log("- Price: $", priceUSD / 1e18);
        console.log("- Decimals:", decimals);

        console.log("");
        console.log("User Status:");
        console.log("- Address:", user);
        console.log("- OUSG balance:", ousg.balanceOf(user) / 1e18);
        console.log("- ETH balance:", user.balance);
        console.log("- AIUSD balance:", aiusd.balanceOf(user) / 1e18);
    }

    /// @notice Main execution function
    function run() public {
        console.log("AI Stablecoin RWA Deposit Execution");
        console.log("=====================================");
        console.log("Demonstrating OUSG Treasury collateral deposits");
        console.log("with AI-enhanced capital efficiency");
        console.log("");

        // Check RWA system status
        checkRWAStatus();
        demonstrateOUSGAdvantage();

        // Choose scenario based on environment variable
        string memory scenario = vm.envOr("RWA_SCENARIO", string("institutional"));

        console.log("");
        console.log("Executing scenario:", scenario);
        console.log("=====================================");

        if (keccak256(bytes(scenario)) == keccak256(bytes("institutional"))) {
            runInstitutionalOUSGDeposit();
        } else if (keccak256(bytes(scenario)) == keccak256(bytes("large"))) {
            runLargeInstitutionalDeposit();
        } else if (keccak256(bytes(scenario)) == keccak256(bytes("mixed"))) {
            runMixedPortfolioDeposit();
        } else {
            console.log("Available scenarios: institutional, large, mixed");
            console.log("Using default: institutional");
            runInstitutionalOUSGDeposit();
        }

        console.log("");
        console.log("=== RWA Deposit Execution Completed ===");
        console.log("Treasury holders can now leverage OUSG positions");
        console.log("with superior AI-enhanced borrowing terms!");
    }
}

// Check RWA System Status:
// source .env && forge script script/execute/ExecuteDepositWithRWA.s.sol:ExecuteDepositWithRWAScript --sig
// "checkRWAStatus()" --rpc-url $SEPOLIA_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY -vvvv

// Execute Institutional OUSG Deposit (100 OUSG):
// source .env && RWA_SCENARIO=institutional forge script
// script/execute/ExecuteDepositWithRWA.s.sol:ExecuteDepositWithRWAScript --rpc-url $SEPOLIA_RPC_URL --broadcast
// --private-key $DEPLOYER_PRIVATE_KEY -vvvv

// Execute Large Institutional Deposit (5000 OUSG):
// source .env && RWA_SCENARIO=large forge script script/execute/ExecuteDepositWithRWA.s.sol:ExecuteDepositWithRWAScript
// --rpc-url $SEPOLIA_RPC_URL --broadcast --private-key $DEPLOYER_PRIVATE_KEY -vvvv

// Execute Mixed Portfolio (OUSG + WETH):
// source .env && RWA_SCENARIO=mixed forge script script/execute/ExecuteDepositWithRWA.s.sol:ExecuteDepositWithRWAScript
// --rpc-url $SEPOLIA_RPC_URL --broadcast --private-key $DEPLOYER_PRIVATE_KEY -vvvv
