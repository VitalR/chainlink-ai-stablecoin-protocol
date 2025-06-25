// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "forge-std/Script.sol";
import { IERC20 } from "@openzeppelin/token/ERC20/IERC20.sol";

import { AIStablecoin } from "src/AIStablecoin.sol";
import { CollateralVault } from "src/CollateralVault.sol";
import { RiskOracleController } from "src/RiskOracleController.sol";
import { SepoliaConfig } from "config/SepoliaConfig.sol";

/// @title ExecuteDeposit - Test deposit scenarios for AI Stablecoin with Enhanced Position Management
/// @notice Executes various deposit scenarios to test the system functionality with multiple positions
/// @dev For RWA/OUSG deposits, use ExecuteDepositWithRWA.s.sol instead
contract ExecuteDepositScript is Script {
    AIStablecoin aiusd;
    CollateralVault vault;
    RiskOracleController controller;

    IERC20 dai;
    IERC20 weth;
    IERC20 wbtc;
    IERC20 usdc;

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

        // Initialize standard crypto tokens
        dai = IERC20(SepoliaConfig.MOCK_DAI);
        weth = IERC20(SepoliaConfig.MOCK_WETH);
        wbtc = IERC20(SepoliaConfig.MOCK_WBTC);
        usdc = IERC20(SepoliaConfig.MOCK_USDC);
    }

    /// @notice Execute single token deposit (WETH)
    function runSingleTokenDeposit() public {
        vm.startBroadcast(userPrivateKey);

        console.log("=== Single Token Deposit (WETH) ===");

        // 1. Check balances and existing positions
        _checkUserStatus();

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

        // 6. Check updated position status
        _checkUserStatus();

        vm.stopBroadcast();
    }

    /// @notice Execute diversified basket deposit
    function runDiversifiedDeposit() public {
        vm.startBroadcast(userPrivateKey);

        console.log("=== Diversified Basket Deposit ===");

        // 1. Check balances and existing positions
        _checkUserStatus();

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

        // 5. Check updated position status
        _checkUserStatus();

        vm.stopBroadcast();
    }

    /// @notice Execute stable coin focused deposit
    function runStablecoinDeposit() public {
        vm.startBroadcast(userPrivateKey);

        console.log("=== Stablecoin-Focused Deposit ===");

        // Check existing positions
        _checkUserStatus();

        uint256 daiBalance = dai.balanceOf(user);
        uint256 usdcBalance = usdc.balanceOf(user);

        console.log("User stablecoin balances:");
        console.log("- DAI:", daiBalance);
        console.log("- USDC:", usdcBalance);

        // Stablecoin portfolio deposit
        address[] memory tokens = new address[](2);
        uint256[] memory amounts = new uint256[](2);

        tokens[0] = address(dai);
        amounts[0] = 2000 * 1e18; // 2000 DAI

        tokens[1] = address(usdc);
        amounts[1] = 1000 * 1e6; // 1000 USDC (6 decimals)

        require(daiBalance >= amounts[0], "Insufficient DAI");
        require(usdcBalance >= amounts[1], "Insufficient USDC");

        // Approve tokens
        dai.approve(address(vault), amounts[0]);
        usdc.approve(address(vault), amounts[1]);

        console.log("Approved stablecoins for deposit");

        uint256 aiFee = controller.estimateTotalFee();
        vault.depositBasket{ value: aiFee }(tokens, amounts);

        console.log("Stablecoin deposit executed successfully - expecting high confidence due to low volatility!");

        // Check updated status
        _checkUserStatus();

        vm.stopBroadcast();
    }

    /// @notice Execute small deposit test
    function runSmallDeposit() public {
        vm.startBroadcast(userPrivateKey);

        console.log("=== Small Deposit Test ===");

        // Check existing positions
        _checkUserStatus();

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

        // Check updated status
        _checkUserStatus();

        vm.stopBroadcast();
    }

    /// @notice Enhanced status check with multiple position support
    function _checkUserStatus() internal view {
        console.log("=== USER STATUS CHECK ===");
        console.log("User address:", user);
        console.log("User ETH balance:", user.balance);
        console.log("User AIUSD balance:", aiusd.balanceOf(user));

        // Get position summary
        (uint256 totalPositions, uint256 activePositions, uint256 totalValueUSD, uint256 totalAIUSDMinted) =
            vault.getPositionSummary(user);

        console.log("");
        console.log("=== POSITION SUMMARY ===");
        console.log("Total positions created:", totalPositions);
        console.log("Active positions:", activePositions);
        console.log("Total collateral value: $", totalValueUSD / 1e18);
        console.log("Total AIUSD minted:", totalAIUSDMinted);

        if (totalPositions > 0) {
            console.log("");
            console.log("=== INDIVIDUAL POSITIONS ===");

            // Show details of each position
            for (uint256 i = 0; i < totalPositions; i++) {
                try vault.getUserDepositInfo(user, i) returns (CollateralVault.Position memory position) {
                    if (position.timestamp > 0) {
                        // Position exists
                        console.log("Position", i, ":");
                        console.log("  - Value: $", position.totalValueUSD / 1e18);
                        console.log("  - AIUSD minted:", position.aiusdMinted);
                        console.log("  - Collateral ratio:", position.collateralRatio, "bps");
                        console.log("  - Pending request:", position.hasPendingRequest);
                        console.log("  - Request ID:", position.requestId);
                        console.log("  - Token count:", position.tokens.length);

                        if (position.hasPendingRequest) {
                            uint256 timeElapsed = block.timestamp - position.timestamp;
                            console.log("  - Time elapsed:", timeElapsed, "seconds");
                        }
                    }
                } catch {
                    console.log("Position", i, ": [EMPTY/DELETED]");
                }
            }
        }

        // Check emergency withdrawal status
        (bool canWithdraw, uint256 timeRemaining) = vault.canEmergencyWithdraw(user);
        if (canWithdraw || timeRemaining > 0) {
            console.log("");
            console.log("=== EMERGENCY STATUS ===");
            console.log("Can emergency withdraw:", canWithdraw);
            if (!canWithdraw && timeRemaining > 0) {
                console.log("Time until emergency withdrawal:", timeRemaining, "seconds");
                console.log("Time until emergency withdrawal:", timeRemaining / 3600, "hours");
            }
        }

        console.log("");
    }

    /// @notice Comprehensive system status check
    function checkSystemStatus() public view {
        console.log("=== SYSTEM STATUS ===");
        console.log("Stablecoin address:", address(aiusd));
        console.log("Vault address:", address(vault));
        console.log("Controller address:", address(controller));
        console.log("");

        // Check system operational status
        (bool paused, uint256 failures, uint256 lastFailure, bool circuitBreakerActive) = controller.getSystemStatus();
        console.log("AI processing paused:", paused);
        console.log("Circuit breaker active:", circuitBreakerActive);
        console.log("Failure count:", failures);
        console.log("System operational:", !paused && !circuitBreakerActive);
        console.log("");

        _checkUserStatus();
    }

    /// @notice Run all deposit scenarios
    function run() public {
        console.log("AI STABLECOIN CRYPTO DEPOSIT EXECUTION");
        console.log("=====================================");
        console.log("For RWA/OUSG deposits, use: ExecuteDepositWithRWA.s.sol");
        console.log("=====================================");

        // Check initial status
        checkSystemStatus();

        // Choose scenario based on environment variable
        string memory scenario = vm.envOr("DEPOSIT_SCENARIO", string("single"));

        if (keccak256(bytes(scenario)) == keccak256(bytes("single"))) {
            runSingleTokenDeposit();
        } else if (keccak256(bytes(scenario)) == keccak256(bytes("diversified"))) {
            runDiversifiedDeposit();
        } else if (keccak256(bytes(scenario)) == keccak256(bytes("stablecoin"))) {
            runStablecoinDeposit();
        } else if (keccak256(bytes(scenario)) == keccak256(bytes("small"))) {
            runSmallDeposit();
        } else {
            console.log("Unknown scenario. Available: single, diversified, stablecoin, small");
            console.log("For RWA deposits: Use ExecuteDepositWithRWA.s.sol");
            revert("Invalid scenario");
        }

        console.log("");
        console.log("=== EXECUTION COMPLETED ===");
        console.log("Position creation successful!");
        console.log("AI analysis will complete in 1-5 minutes.");
        console.log("Use 'checkSystemStatus()' to monitor progress.");
    }
}
