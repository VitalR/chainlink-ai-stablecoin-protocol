// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "forge-std/Script.sol";
import { AIStablecoin } from "src/AIStablecoin.sol";
import { CollateralVault } from "src/CollateralVault.sol";
import { RiskOracleController } from "src/RiskOracleController.sol";
import { SepoliaConfig } from "config/SepoliaConfig.sol";

/// @title GetDepositData - Retrieve deposit information after Bedrock execution
/// @notice Gets request ID and deposit details for processing with TestBedrockDirect.js
contract GetDepositDataScript is Script {
    AIStablecoin aiusd;
    CollateralVault vault;
    RiskOracleController controller;

    address user;

    function setUp() public {
        // Get target user (default to DEPLOYER, or USER if specified)
        string memory targetUser = vm.envOr("DEPOSIT_TARGET_USER", string("DEPLOYER"));

        if (keccak256(abi.encodePacked(targetUser)) == keccak256(abi.encodePacked("USER"))) {
            user = vm.envAddress("USER_PUBLIC_KEY");
        } else {
            user = vm.envAddress("DEPLOYER_PUBLIC_KEY");
        }

        // Initialize contracts
        aiusd = AIStablecoin(SepoliaConfig.AI_STABLECOIN);
        vault = CollateralVault(payable(SepoliaConfig.COLLATERAL_VAULT));
        controller = RiskOracleController(SepoliaConfig.RISK_ORACLE_CONTROLLER);
    }

    /// @notice Get latest deposit data for user
    function getLatestDepositData() public view {
        console.log("=== LATEST DEPOSIT DATA ===");
        console.log("User address:", user);
        console.log("");

        // Get user's position summary to check if they have any positions
        (uint256 totalPositions, uint256 activePositions, uint256 totalValueUSD, uint256 totalAIUSDMinted) =
            vault.getPositionSummary(user);

        console.log("Total positions created:", totalPositions);

        if (totalPositions == 0) {
            console.log("ERROR: No positions found for user");
            return;
        }

        // Get latest position (most recent deposit) - getPosition returns the latest position
        (
            address[] memory tokens,
            uint256[] memory amounts,
            uint256 totalValueUSD_latest,
            uint256 aiusdMinted,
            uint256 collateralRatio,
            uint256 requestId,
            bool hasPendingRequest
        ) = vault.getPosition(user);

        console.log("=== LATEST POSITION DATA ===");
        console.log("Position index:", totalPositions - 1);
        console.log("(latest position)");
        console.log("Request ID:", requestId);
        console.log("Has pending request:", hasPendingRequest);
        console.log("Total collateral value: $", totalValueUSD_latest / 1e18);
        console.log("AIUSD minted:", aiusdMinted / 1e18);

        if (collateralRatio > 0) {
            console.log("Collateral ratio:", collateralRatio / 100, "%");
        } else {
            console.log("Collateral ratio: Not set (pending)");
        }

        console.log("");
        console.log("=== COLLATERAL COMPOSITION ===");
        for (uint256 i = 0; i < tokens.length; i++) {
            console.log("Token:", tokens[i]);
            console.log("Amount:", amounts[i]);

            // Get token symbol if possible
            if (tokens[i] == SepoliaConfig.MOCK_WETH) {
                console.log("Symbol: WETH");
                console.log("Human readable:", amounts[i] / 1e18);
                console.log("Unit: ETH");
            } else if (tokens[i] == SepoliaConfig.MOCK_WBTC) {
                console.log("Symbol: WBTC");
                console.log("Human readable:", amounts[i] / 1e8);
                console.log("Unit: BTC");
            } else if (tokens[i] == SepoliaConfig.MOCK_DAI) {
                console.log("Symbol: DAI");
                console.log("Human readable:", amounts[i] / 1e18);
                console.log("Unit: DAI");
            } else if (tokens[i] == SepoliaConfig.MOCK_USDC) {
                console.log("Symbol: USDC");
                console.log("Human readable:", amounts[i] / 1e6);
                console.log("Unit: USDC");
            } else if (tokens[i] == SepoliaConfig.LINK_TOKEN) {
                console.log("Symbol: LINK");
                console.log("Human readable:", amounts[i] / 1e18);
                console.log("Unit: LINK");
            }
            console.log("---");
        }

        // Get request details if pending
        if (hasPendingRequest) {
            console.log("=== REQUEST DETAILS ===");
            RiskOracleController.RequestInfo memory requestInfo = controller.getRequestInfo(requestId);

            console.log("Request user:", requestInfo.user);
            console.log("Request vault:", requestInfo.vault);
            console.log("Collateral value: $", requestInfo.collateralValue / 1e18);
            console.log("Timestamp:", requestInfo.timestamp);
            console.log("Processed:", requestInfo.processed);
            console.log("Engine:", uint256(requestInfo.engine)); // 0=ALGO, 1=BEDROCK, 2=TEST_TIMEOUT

            string memory engineName = "UNKNOWN";
            if (requestInfo.engine == RiskOracleController.Engine.ALGO) {
                engineName = "ALGO";
            } else if (requestInfo.engine == RiskOracleController.Engine.BEDROCK) {
                engineName = "BEDROCK";
            } else if (requestInfo.engine == RiskOracleController.Engine.TEST_TIMEOUT) {
                engineName = "TEST_TIMEOUT";
            }
            console.log("Engine name:", engineName);

            if (requestInfo.manualProcessingRequested) {
                console.log("Manual processing requested at:", requestInfo.manualRequestTime);
            }
        }

        console.log("");
        console.log("=== NEXT STEPS ===");
        if (hasPendingRequest) {
            console.log("STATUS: REQUEST", requestId);
            console.log("Status: IS PENDING");
            console.log("");
            console.log("For BEDROCK engine processing:");
            console.log("1. Export request data:");
            console.log("   export REQUEST_ID=", requestId);
            console.log("   export COLLATERAL_VALUE=", totalValueUSD_latest);
            console.log("");
            console.log("2. Modify TestBedrockDirect.js with this portfolio:");
            console.log("   tokens: [");
            console.log(_formatTokensForJS(tokens));
            console.log("]");
            console.log("   amounts: [");
            console.log(_formatAmountsForJS(tokens, amounts));
            console.log("]");
            console.log("   totalValue:", totalValueUSD_latest / 1e18);
            console.log("");
            console.log("3. Run Bedrock AI analysis:");
            console.log("   cd test/standalone && node TestBedrockDirect.js");
            console.log("");
            console.log("4. Process with AI result:");
            console.log("   forge script script/execute/ProcessManualRequest.s.sol \\");
            console.log("   --sig \"processWithAIResponse(uint256,string)\" \\");
            console.log("   RequestID:", requestId);
            console.log("   Response: \"RATIO:150 CONFIDENCE:75 SOURCE:BEDROCK_AI\"");
        } else {
            console.log("SUCCESS: REQUEST", requestId);
            console.log("Status: ALREADY PROCESSED");
            console.log("User has", aiusdMinted / 1e18);
            console.log("Token: AIUSD");
            console.log("Collateral ratio:", collateralRatio / 100);
            console.log("Unit: %");
        }
    }

    /// @notice Get specific position data by index
    function getPositionData(uint256 positionIndex) public view {
        console.log("=== POSITION", positionIndex, "DATA ===");

        // Get total positions first to validate index
        (uint256 totalPositions,,,) = vault.getPositionSummary(user);

        if (positionIndex >= totalPositions) {
            console.log("ERROR: Position index out of range");
            return;
        }

        // Get specific position by index
        CollateralVault.Position memory position = vault.getUserDepositInfo(user, positionIndex);

        console.log("Request ID:", position.requestId);
        console.log("Status:", position.hasPendingRequest ? "PENDING" : "PROCESSED");
        console.log("Value: $", position.totalValueUSD / 1e18);
        console.log("Minted:", position.aiusdMinted / 1e18);
        console.log("Token: AIUSD");

        if (position.collateralRatio > 0) {
            console.log("Ratio:", position.collateralRatio / 100);
            console.log("Unit: %");
        }
    }

    /// @notice Helper to format tokens for JavaScript
    function _formatTokensForJS(address[] memory tokens) internal pure returns (string memory) {
        if (tokens.length == 0) return "";

        string memory result;
        for (uint256 i = 0; i < tokens.length; i++) {
            if (tokens[i] == SepoliaConfig.MOCK_WETH) {
                result = string(abi.encodePacked(result, "'WETH'"));
            } else if (tokens[i] == SepoliaConfig.MOCK_WBTC) {
                result = string(abi.encodePacked(result, "'WBTC'"));
            } else if (tokens[i] == SepoliaConfig.MOCK_DAI) {
                result = string(abi.encodePacked(result, "'DAI'"));
            } else if (tokens[i] == SepoliaConfig.MOCK_USDC) {
                result = string(abi.encodePacked(result, "'USDC'"));
            } else if (tokens[i] == SepoliaConfig.LINK_TOKEN) {
                result = string(abi.encodePacked(result, "'LINK'"));
            } else {
                result = string(abi.encodePacked(result, "'UNKNOWN'"));
            }

            if (i < tokens.length - 1) {
                result = string(abi.encodePacked(result, ", "));
            }
        }
        return result;
    }

    /// @notice Helper to format amounts for JavaScript
    function _formatAmountsForJS(address[] memory tokens, uint256[] memory amounts)
        internal
        pure
        returns (string memory)
    {
        if (amounts.length == 0) return "";

        string memory result;
        for (uint256 i = 0; i < amounts.length; i++) {
            uint256 humanAmount;

            if (tokens[i] == SepoliaConfig.MOCK_WETH) {
                humanAmount = amounts[i] / 1e18;
            } else if (tokens[i] == SepoliaConfig.MOCK_WBTC) {
                humanAmount = amounts[i] / 1e8;
            } else if (tokens[i] == SepoliaConfig.MOCK_DAI) {
                humanAmount = amounts[i] / 1e18;
            } else if (tokens[i] == SepoliaConfig.MOCK_USDC) {
                humanAmount = amounts[i] / 1e6;
            } else if (tokens[i] == SepoliaConfig.LINK_TOKEN) {
                humanAmount = amounts[i] / 1e18;
            } else {
                humanAmount = amounts[i];
            }

            result = string(abi.encodePacked(result, vm.toString(humanAmount)));

            if (i < amounts.length - 1) {
                result = string(abi.encodePacked(result, ", "));
            }
        }
        return result;
    }

    /// @notice Output data in format for ProcessBedrockDeposit.js integration
    function getBedrockProcessingCommand() public view {
        console.log("=== BEDROCK PROCESSING INTEGRATION ===");

        (uint256 totalPositions,,,) = vault.getPositionSummary(user);
        if (totalPositions == 0) {
            console.log("ERROR: No positions found for user");
            return;
        }

        // Get latest position
        (
            address[] memory tokens,
            uint256[] memory amounts,
            uint256 totalValueUSD,
            uint256 aiusdMinted,
            uint256 collateralRatio,
            uint256 requestId,
            bool hasPendingRequest
        ) = vault.getPosition(user);

        if (!hasPendingRequest) {
            console.log("SUCCESS: Position already processed.");
            console.log("Request ID:", requestId);
            return;
        }

        // Format tokens for command line
        string memory tokensFormatted = _formatTokensForJS(tokens);
        string memory amountsFormatted = _formatAmountsForJS(tokens, amounts);

        console.log("INTEGRATED BEDROCK PROCESSING");
        console.log("Request ID:", requestId);
        console.log("Total Value: $", totalValueUSD);
        console.log("");

        console.log("READY-TO-USE COMMANDS:");
        console.log("");

        console.log("1. Process with integrated Bedrock script:");
        string memory command1 = string(
            abi.encodePacked(
                "cd test/standalone && node ProcessBedrockDeposit.js --requestId ",
                vm.toString(requestId),
                " --tokens \"",
                tokensFormatted,
                "\" --amounts \"",
                amountsFormatted,
                "\" --totalValue ",
                vm.toString(totalValueUSD)
            )
        );
        console.log(command1);
        console.log("");

        console.log("2. Or using environment variables:");
        console.log("export REQUEST_ID=", requestId);
        console.log("export TOKENS=\"", tokensFormatted, "\"");
        console.log("export AMOUNTS=\"", amountsFormatted, "\"");
        console.log("export TOTAL_VALUE=", totalValueUSD);
        console.log("cd test/standalone && node ProcessBedrockDeposit.js");
        console.log("");

        console.log("BENEFITS: This replaces the manual steps of:");
        console.log("   - Running TestBedrockDirect.js (template only)");
        console.log("   - Manually copying portfolio data");
        console.log("   - Guessing the AI response format");
        console.log("   - One command processes your actual deposit!");
    }

    /// @notice Main execution
    function run() public {
        console.log("AI STABLECOIN DEPOSIT DATA RETRIEVAL");
        console.log("====================================");

        getLatestDepositData();
    }
}

// =============================================================
//                       USAGE COMMANDS
// =============================================================

// Get latest deposit data:
// source .env && forge script script/bedrock/GetDepositData.s.sol:GetDepositDataScript --rpc-url $SEPOLIA_RPC_URL
// --private-key $DEPLOYER_PRIVATE_KEY -vv

// Get latest with different user:
// source .env && DEPOSIT_TARGET_USER=USER forge script script/bedrock/GetDepositData.s.sol:GetDepositDataScript
// --rpc-url $SEPOLIA_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY -vv

// Get specific position (index 0):
// source .env && forge script script/bedrock/GetDepositData.s.sol:GetDepositDataScript --sig "getPositionData(uint256)"
// 0 --rpc-url $SEPOLIA_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY -vv

// Get Bedrock processing command (RECOMMENDED):
// source .env && forge script script/bedrock/GetDepositData.s.sol:GetDepositDataScript --sig
// "getBedrockProcessingCommand()" --rpc-url $SEPOLIA_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY -vv
