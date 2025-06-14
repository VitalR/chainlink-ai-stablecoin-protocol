// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "forge-std/Script.sol";
import { AIStablecoin } from "src/AIStablecoin.sol";
import { AICollateralVaultCallback } from "src/AICollateralVaultCallback.sol";
import { AIControllerCallback } from "src/AIControllerCallback.sol";
import { IERC20 } from "@openzeppelin/token/ERC20/IERC20.sol";
import { SepoliaConfig } from "config/SepoliaConfig.sol";

/// @title ExecuteDeposit - Test deposit scenarios for AI Stablecoin
/// @notice Executes various deposit scenarios to test the system functionality
contract ExecuteDepositScript is Script {
    AIStablecoin aiusd;
    AICollateralVaultCallback vault;
    AIControllerCallback controller;

    IERC20 dai;
    IERC20 weth;
    IERC20 wbtc;

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

        // Initialize tokens
        dai = IERC20(SepoliaConfig.MOCK_DAI);
        weth = IERC20(SepoliaConfig.MOCK_WETH);
        wbtc = IERC20(SepoliaConfig.MOCK_WBTC);
    }

    /// @notice Execute single token deposit (WETH)
    function runSingleTokenDeposit() public {
        vm.startBroadcast(userPrivateKey);

        console.log("=== Single Token Deposit (WETH) ===");

        // 1. Check balances
        uint256 wethBalance = weth.balanceOf(user);
        console.log("User WETH balance:", wethBalance);
        require(wethBalance >= 1 ether, "Insufficient WETH balance");

        // 2. Prepare deposit
        address[] memory tokens = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        tokens[0] = address(weth);
        amounts[0] = 1 ether; // 1 ETH

        // 3. Approve tokens
        weth.approve(address(vault), amounts[0]);
        console.log("Approved WETH:", amounts[0]);

        // 4. Get AI fee
        uint256 aiFee = controller.estimateTotalFee();
        console.log("AI fee required:", aiFee);
        require(user.balance >= aiFee, "Insufficient ETH for AI fee");

        // 5. Execute deposit
        vault.depositBasket{ value: aiFee }(tokens, amounts);
        console.log("Deposit executed successfully");

        // 6. Check position
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

        vm.stopBroadcast();
    }

    /// @notice Execute diversified basket deposit
    function runDiversifiedDeposit() public {
        vm.startBroadcast(userPrivateKey);

        console.log("=== Diversified Basket Deposit ===");

        // 1. Check balances
        uint256 wethBalance = weth.balanceOf(user);
        uint256 wbtcBalance = wbtc.balanceOf(user);
        uint256 daiBalance = dai.balanceOf(user);

        console.log("User balances:");
        console.log("- WETH:", wethBalance);
        console.log("- WBTC:", wbtcBalance);
        console.log("- DAI:", daiBalance);

        // 2. Prepare diversified basket
        address[] memory tokens = new address[](3);
        uint256[] memory amounts = new uint256[](3);

        tokens[0] = address(weth);
        amounts[0] = 0.5 ether; // 0.5 ETH

        tokens[1] = address(wbtc);
        amounts[1] = 0.01 * 1e8; // 0.01 BTC (8 decimals)

        tokens[2] = address(dai);
        amounts[2] = 1000 * 1e18; // 1000 DAI

        require(wethBalance >= amounts[0], "Insufficient WETH");
        require(wbtcBalance >= amounts[1], "Insufficient WBTC");
        require(daiBalance >= amounts[2], "Insufficient DAI");

        // 3. Approve all tokens
        weth.approve(address(vault), amounts[0]);
        wbtc.approve(address(vault), amounts[1]);
        dai.approve(address(vault), amounts[2]);

        console.log("Approved tokens for deposit");

        // 4. Get AI fee and execute
        uint256 aiFee = controller.estimateTotalFee();
        console.log("AI fee required:", aiFee);

        vault.depositBasket{ value: aiFee }(tokens, amounts);
        console.log("Diversified deposit executed successfully");

        // 5. Check position
        (,, uint256 totalValue,,, uint256 requestId, bool hasPendingRequest) = vault.getPosition(user);

        console.log("Diversified position created:");
        console.log("- Total value:", totalValue);
        console.log("- Request ID:", requestId);
        console.log("- Pending request:", hasPendingRequest);

        vm.stopBroadcast();
    }

    /// @notice Execute small deposit test
    function runSmallDeposit() public {
        vm.startBroadcast(userPrivateKey);

        console.log("=== Small Deposit Test ===");

        // Small DAI deposit
        address[] memory tokens = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        tokens[0] = address(dai);
        amounts[0] = 100 * 1e18; // 100 DAI

        uint256 daiBalance = dai.balanceOf(user);
        require(daiBalance >= amounts[0], "Insufficient DAI balance");

        dai.approve(address(vault), amounts[0]);

        uint256 aiFee = controller.estimateTotalFee();
        vault.depositBasket{ value: aiFee }(tokens, amounts);

        console.log("Small deposit (100 DAI) executed successfully");

        vm.stopBroadcast();
    }

    /// @notice Check system status and user positions
    function checkStatus() public view {
        console.log("=== System Status ===");
        console.log("Stablecoin address:", address(aiusd));
        console.log("Vault address:", address(vault));
        console.log("Controller address:", address(controller));

        console.log("\n=== User Status ===");
        console.log("User address:", user);
        console.log("User ETH balance:", user.balance);
        console.log("User AIUSD balance:", aiusd.balanceOf(user));

        // Check position
        (
            address[] memory tokens,
            uint256[] memory amounts,
            uint256 totalValue,
            uint256 aiusdMinted,
            uint256 collateralRatio,
            uint256 requestId,
            bool hasPendingRequest
        ) = vault.getPosition(user);

        console.log("\n=== User Position ===");
        console.log("Total collateral value:", totalValue);
        console.log("AIUSD minted:", aiusdMinted);
        console.log("Collateral ratio:", collateralRatio);
        console.log("Request ID:", requestId);
        console.log("Has pending request:", hasPendingRequest);

        if (tokens.length > 0) {
            console.log("\n=== Deposited Tokens ===");
            for (uint256 i = 0; i < tokens.length; i++) {
                console.log("Token:", tokens[i]);
                console.log("Amount:", amounts[i]);
            }
        }
    }

    /// @notice Run all deposit scenarios
    function run() public {
        console.log(" AI Stablecoin Deposit Execution Tests");
        console.log("=========================================");

        // Check initial status
        checkStatus();

        // Choose scenario based on environment variable
        string memory scenario = vm.envOr("DEPOSIT_SCENARIO", string("single"));

        if (keccak256(bytes(scenario)) == keccak256(bytes("single"))) {
            runSingleTokenDeposit();
        } else if (keccak256(bytes(scenario)) == keccak256(bytes("diversified"))) {
            runDiversifiedDeposit();
        } else if (keccak256(bytes(scenario)) == keccak256(bytes("small"))) {
            runSmallDeposit();
        } else {
            console.log("Unknown scenario. Available: single, diversified, small");
            revert("Invalid scenario");
        }

        console.log("\n Deposit execution completed");
    }
}
