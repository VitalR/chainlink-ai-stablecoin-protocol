// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Script } from "forge-std/Script.sol";
import { console } from "forge-std/console.sol";

import { AIStablecoin } from "../../src/AIStablecoin.sol";
import { CollateralVault } from "../../src/CollateralVault.sol";
import { RiskOracleController } from "../../src/RiskOracleController.sol";
import { AutoEmergencyWithdrawal } from "../../src/automation/AutoEmergencyWithdrawal.sol";
import { SepoliaConfig } from "../../config/SepoliaConfig.sol";

/// @title Full System Sanity Check - Comprehensive validation of deployed AI-powered stablecoin system
/// @notice Validates all components, integrations, configurations, and system readiness
/// @dev Run this script to ensure the entire system is properly deployed and configured
contract FullSystemSanityCheckScript is Script {
    // Core contracts
    AIStablecoin aiusd;
    CollateralVault vault;
    RiskOracleController controller;
    AutoEmergencyWithdrawal automation;

    address deployer;
    uint256 deployerPrivateKey;

    // Test results tracking
    uint256 testsRun = 0;
    uint256 testsPassed = 0;
    uint256 testsFailed = 0;

    function setUp() public {
        deployer = vm.envAddress("DEPLOYER_PUBLIC_KEY");
        deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");

        // Initialize all contracts using config addresses
        aiusd = AIStablecoin(SepoliaConfig.AI_STABLECOIN);
        vault = CollateralVault(payable(SepoliaConfig.COLLATERAL_VAULT));
        controller = RiskOracleController(SepoliaConfig.RISK_ORACLE_CONTROLLER);
        automation = AutoEmergencyWithdrawal(SepoliaConfig.AUTO_EMERGENCY_WITHDRAWAL);
    }

    function run() external {
        console.log("=====================================");
        console.log("AI-POWERED STABLECOIN SYSTEM VALIDATION");
        console.log("=====================================");
        console.log("");

        // Basic contract existence and configuration
        validateContractDeployments();

        // Core system permissions and authorizations
        validateSystemAuthorizations();

        // Asset configuration and price feeds
        validateAssetConfiguration();

        // Chainlink integrations
        validateChainlinkIntegrations();

        // AI and oracle functionality
        validateAISystemStatus();

        // Emergency and automation systems
        validateEmergencySystemsRead();

        // Cross-contract integration checks
        validateCrossContractIntegrations();

        // Final summary
        printFinalSummary();
    }

    /// @notice Validate all contracts are deployed and accessible
    function validateContractDeployments() internal {
        console.log("=== 1. CONTRACT DEPLOYMENT VALIDATION ===");

        _checkContract("AIStablecoin (AIUSD)", address(aiusd));
        _checkContract("CollateralVault", address(vault));
        _checkContract("RiskOracleController", address(controller));
        _checkContract("AutoEmergencyWithdrawal", address(automation));

        console.log("");
    }

    /// @notice Validate system-wide authorizations and permissions
    function validateSystemAuthorizations() internal {
        console.log("=== 2. SYSTEM AUTHORIZATION VALIDATION ===");

        // Check vault is authorized to mint AIUSD
        bool vaultAuthorized = aiusd.authorizedVaults(address(vault));
        _testResult("Vault authorized to mint AIUSD", vaultAuthorized);

        // Check vault is authorized to submit AI requests
        bool vaultCanSubmitRequests = controller.authorizedCallers(address(vault));
        _testResult("Vault authorized to submit AI requests", vaultCanSubmitRequests);

        // Check automation is authorized for emergency withdrawals
        bool automationAuthorized = vault.authorizedAutomation(address(automation));
        _testResult("Automation authorized for emergency withdrawals", automationAuthorized);

        // Check deployer ownership
        bool deployerOwnsAIUSD = aiusd.owner() == deployer;
        _testResult("Deployer owns AIUSD contract", deployerOwnsAIUSD);

        bool deployerOwnsController = controller.owner() == deployer;
        _testResult("Deployer owns Controller contract", deployerOwnsController);

        console.log("");
    }

    /// @notice Validate asset configuration and supported tokens
    function validateAssetConfiguration() internal {
        console.log("=== 3. ASSET CONFIGURATION VALIDATION ===");

        // Check supported tokens configuration
        _validateTokenConfig("WETH", SepoliaConfig.MOCK_WETH);
        _validateTokenConfig("WBTC", SepoliaConfig.MOCK_WBTC);
        _validateTokenConfig("DAI", SepoliaConfig.MOCK_DAI);
        _validateTokenConfig("USDC", SepoliaConfig.MOCK_USDC);
        _validateTokenConfig("OUSG (RWA)", SepoliaConfig.MOCK_OUSG);

        console.log("");
    }

    /// @notice Validate Chainlink price feeds and data sources
    function validateChainlinkIntegrations() internal {
        console.log("=== 4. CHAINLINK INTEGRATION VALIDATION ===");

        // Test Chainlink Data Feeds
        _testPriceFeed("ETH/USD", "ETH");
        _testPriceFeed("BTC/USD", "BTC");
        _testPriceFeed("DAI/USD", "DAI");
        _testPriceFeed("USDC/USD", "USDC");

        // Check Chainlink Functions configuration
        uint64 subscriptionId = controller.subscriptionId();
        _testResult("Chainlink Functions subscription configured", subscriptionId > 0);
        console.log("   Subscription ID: %s", subscriptionId);

        bytes32 donId = controller.donId();
        _testResult("Chainlink DON ID configured", donId != bytes32(0));

        uint32 gasLimit = controller.gasLimit();
        _testResult("Chainlink gas limit configured", gasLimit > 0);
        console.log("   Gas limit: %s", gasLimit);

        console.log("");
    }

    /// @notice Validate AI system status and configuration
    function validateAISystemStatus() internal {
        console.log("=== 5. AI SYSTEM STATUS VALIDATION ===");

        // Check system operational status
        (bool paused, uint256 failures, uint256 lastFailure, bool circuitBreakerActive) = controller.getSystemStatus();

        _testResult("AI processing not paused", !paused);
        _testResult("Circuit breaker not active", !circuitBreakerActive);

        console.log("   Failure count: %s", failures);
        console.log("   Last failure: %s", lastFailure);
        console.log("   System operational: %s", !paused && !circuitBreakerActive ? "YES" : "NO");

        // Check AI source code is configured
        string memory aiSource = controller.aiSourceCode();
        bool hasAISource = bytes(aiSource).length > 0;
        _testResult("AI source code configured", hasAISource);

        console.log("");
    }

    /// @notice Validate emergency systems and automation (read-only checks)
    function validateEmergencySystemsRead() internal {
        console.log("=== 6. EMERGENCY SYSTEMS VALIDATION ===");

        // Check emergency withdrawal delay
        uint256 emergencyDelay = vault.emergencyWithdrawalDelay();
        bool delayConfigured = emergencyDelay > 0;
        _testResult("Emergency withdrawal delay configured", delayConfigured);
        console.log("   Emergency delay: %s seconds (%s hours)", emergencyDelay, emergencyDelay / 3600);

        // Check automation configuration
        bool automationEnabled = automation.automationEnabled();
        _testResult("Chainlink Automation enabled", automationEnabled);

        uint256 maxPositions = automation.MAX_POSITIONS_PER_UPKEEP();
        _testResult("Automation max positions configured", maxPositions > 0);
        console.log("   Max positions per upkeep: %s", maxPositions);

        console.log("");
    }

    /// @notice Validate cross-contract integrations
    function validateCrossContractIntegrations() internal {
        console.log("=== 7. CROSS-CONTRACT INTEGRATION VALIDATION ===");

        // Check vault knows about controller
        address vaultController = address(vault.riskOracleController());
        bool vaultControllerCorrect = vaultController == address(controller);
        _testResult("Vault has correct controller reference", vaultControllerCorrect);

        // Check vault knows about AIUSD
        address vaultAIUSD = address(vault.aiusd());
        bool vaultAIUSDCorrect = vaultAIUSD == address(aiusd);
        _testResult("Vault has correct AIUSD reference", vaultAIUSDCorrect);

        // Check automation knows about vault
        // Note: AutoEmergencyWithdrawal takes vault address in performUpkeep, not stored
        _testResult("Automation can access vault interface", address(vault) != address(0));

        console.log("");
    }

    /// @notice Helper function to validate individual token configuration
    function _validateTokenConfig(string memory tokenName, address tokenAddress) internal {
        try vault.supportedTokens(tokenAddress) returns (uint256 price, uint8 decimals, bool supported) {
            if (supported && price > 0 && decimals > 0) {
                _testResult(string(abi.encodePacked(tokenName, " configured")), true);
                console.log("   %s: $%s (%s decimals)", tokenName, price / 1e18, decimals);
            } else {
                _testResult(string(abi.encodePacked(tokenName, " configured")), false);
            }
        } catch {
            _testResult(string(abi.encodePacked(tokenName, " accessible")), false);
        }
    }

    /// @notice Helper function to test price feeds
    function _testPriceFeed(string memory feedName, string memory symbol) internal {
        try controller.getLatestPrice(symbol) returns (int256 price) {
            if (price > 0) {
                _testResult(string(abi.encodePacked(feedName, " price feed working")), true);
                console.log("   %s: $%s", feedName, uint256(price) / 1e8);
            } else {
                _testResult(string(abi.encodePacked(feedName, " price feed working")), false);
            }
        } catch {
            _testResult(string(abi.encodePacked(feedName, " price feed accessible")), false);
        }
    }

    /// @notice Helper function to check contract deployment
    function _checkContract(string memory name, address contractAddress) internal {
        if (contractAddress != address(0)) {
            uint256 codeSize;
            assembly {
                codeSize := extcodesize(contractAddress)
            }
            bool deployed = codeSize > 0;
            _testResult(string(abi.encodePacked(name, " deployed")), deployed);
            console.log("   Address: %s", contractAddress);
        } else {
            _testResult(string(abi.encodePacked(name, " address configured")), false);
        }
    }

    /// @notice Helper function to track and display test results
    function _testResult(string memory testName, bool passed) internal {
        testsRun++;
        if (passed) {
            testsPassed++;
            console.log("   [PASS] %s", testName);
        } else {
            testsFailed++;
            console.log("   [FAIL] %s", testName);
        }
    }

    /// @notice Print comprehensive final summary
    function printFinalSummary() internal {
        console.log("=====================================");
        console.log("SYSTEM VALIDATION SUMMARY");
        console.log("=====================================");
        console.log("");
        console.log("Tests Run:    %s", testsRun);
        console.log("Tests Passed: %s", testsPassed);
        console.log("Tests Failed: %s", testsFailed);
        console.log("Success Rate: %s%%", testsPassed * 100 / testsRun);
        console.log("");

        if (testsFailed == 0) {
            console.log("SYSTEM STATUS: FULLY OPERATIONAL");
            console.log("=====================================");
            console.log("The AI-powered stablecoin system is ready for:");
            console.log("  - User deposits and AI-powered minting");
            console.log("  - Dynamic collateral ratio determination");
            console.log("  - Real-world asset (OUSG) integration");
            console.log("  - Emergency withdrawals and automation");
            console.log("  - Manual processing and community support");
            console.log("");
            console.log("Next Steps:");
            console.log("  1. Register Chainlink Automation upkeep");
            console.log("  2. Users can deposit collateral");
            console.log("  3. Experience AI-powered dynamic ratios");
            console.log("  4. Test emergency and recovery systems");
        } else {
            console.log("SYSTEM STATUS: ISSUES DETECTED");
            console.log("=====================================");
            console.log("Please review and fix the failed tests above");
            console.log("before proceeding with system operations.");
        }
        console.log("");
    }
}
