// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "forge-std/Script.sol";
import { AIStablecoin } from "src/AIStablecoin.sol";
import { AISimplePromptController } from "src/AISimplePromptController.sol";
import { AICollateralVaultSimple } from "src/AICollateralVaultSimple.sol";
import { AIEventProcessor } from "src/AIEventProcessor.sol";
import { IERC20 } from "@openzeppelin/token/ERC20/IERC20.sol";
import { SepoliaConfig } from "config/SepoliaConfig.sol";

/// @title TestSimplePromptFlow - Test the complete SimplePrompt flow
/// @notice Demonstrates deposit, AI processing, and minting with the new system
contract TestSimplePromptFlowScript is Script {
    // Contract instances
    AIStablecoin aiusd;
    AISimplePromptController controller;
    AICollateralVaultSimple vault;
    AIEventProcessor processor;

    // Test tokens
    IERC20 weth;
    IERC20 dai;
    IERC20 wbtc;

    // User credentials
    address user;
    uint256 userPrivateKey;

    // Test data storage
    uint256 testRequestId;
    bytes testAIOutput = "RATIO:145 CONFIDENCE:85"; // Mock AI response

    function setUp() public {
        // Get user credentials
        user = vm.envAddress("USER_PUBLIC_KEY");
        userPrivateKey = vm.envUint("USER_PRIVATE_KEY");

        // Initialize contracts (assuming they're deployed)
        // You'll need to update these addresses after deployment
        aiusd = AIStablecoin(0x1234567890123456789012345678901234567890); // Update with actual address
        controller = AISimplePromptController(0x1234567890123456789012345678901234567891); // Update
        vault = AICollateralVaultSimple(payable(0x1234567890123456789012345678901234567892)); // Update
        processor = AIEventProcessor(0x1234567890123456789012345678901234567893); // Update

        // Initialize test tokens
        weth = IERC20(SepoliaConfig.MOCK_WETH);
        dai = IERC20(SepoliaConfig.MOCK_DAI);
        wbtc = IERC20(SepoliaConfig.MOCK_WBTC);
    }

    /// @notice Run the complete test flow
    function run() public {
        console.log("=== Testing SimplePrompt AI Stablecoin Flow ===");
        console.log("User:", user);

        // Step 1: Check initial state
        checkInitialState();

        // Step 2: Deposit collateral (triggers AI request)
        depositCollateral();

        // Step 3: Simulate AI processing (manual for testing)
        simulateAIProcessing();

        // Step 4: Process AI result
        processAIResult();

        // Step 5: Check final state
        checkFinalState();

        console.log("\n=== Test Complete ===");
    }

    /// @notice Step 1: Check initial balances and state
    function checkInitialState() public view {
        console.log("\n=== Step 1: Initial State ===");
        console.log("User ETH balance:", user.balance);
        console.log("User WETH balance:", weth.balanceOf(user));
        console.log("User DAI balance:", dai.balanceOf(user));
        console.log("User AIUSD balance:", aiusd.balanceOf(user));

        // Check if user has a position
        (,,,,,, bool hasPendingRequest) = vault.getPosition(user);
        console.log("Has pending request:", hasPendingRequest);
    }

    /// @notice Step 2: Deposit collateral and trigger AI request
    function depositCollateral() public {
        vm.startBroadcast(userPrivateKey);

        console.log("\n=== Step 2: Deposit Collateral ===");

        // Prepare deposit: 1 WETH + 500 DAI
        address[] memory tokens = new address[](2);
        uint256[] memory amounts = new uint256[](2);

        tokens[0] = address(weth);
        amounts[0] = 1 ether; // 1 WETH

        tokens[1] = address(dai);
        amounts[1] = 500 * 1e18; // 500 DAI

        // Check balances
        require(weth.balanceOf(user) >= amounts[0], "Insufficient WETH");
        require(dai.balanceOf(user) >= amounts[1], "Insufficient DAI");

        // Approve tokens
        weth.approve(address(vault), amounts[0]);
        dai.approve(address(vault), amounts[1]);
        console.log("Approved tokens for deposit");

        // Get AI fee
        uint256 aiFee = controller.estimateTotalFee();
        console.log("AI fee required:", aiFee);
        require(user.balance >= aiFee, "Insufficient ETH for AI fee");

        // Execute deposit (this will emit events)
        vault.depositBasket{ value: aiFee }(tokens, amounts);
        console.log("Deposit executed - AI request submitted");

        // Get the request ID from the position
        (,,,,, uint256 requestId,) = vault.getPosition(user);
        testRequestId = requestId;
        console.log("Request ID:", testRequestId);

        vm.stopBroadcast();
    }

    /// @notice Step 3: Simulate AI processing (in real scenario, this would be automatic)
    function simulateAIProcessing() public view {
        console.log("\n=== Step 3: Simulate AI Processing ===");
        console.log("In production, ORA would process the AI request automatically");
        console.log("The controller would emit an AIResult event with:");
        console.log("- Request ID:", testRequestId);
        console.log("- AI Output:", string(testAIOutput));
        console.log("- Callback Data: (vault, user, basketData, collateralValue)");
        console.log("");
        console.log("For testing, we'll manually call the processor with this data");
    }

    /// @notice Step 4: Process the AI result using the event processor
    function processAIResult() public {
        vm.startBroadcast(userPrivateKey);

        console.log("\n=== Step 4: Process AI Result ===");

        // In a real scenario, someone would listen to the AIResult event and call this
        // For testing, we'll call it directly with the mock data

        // First, process the AI result to create a pending mint
        try vault.processAIResult(user, testRequestId, testAIOutput) {
            console.log("AI result processed successfully");
        } catch Error(string memory reason) {
            console.log("Failed to process AI result:", reason);
            vm.stopBroadcast();
            return;
        }

        // Check the pending mint
        AICollateralVaultSimple.PendingMint memory pendingMint = vault.getPendingMint(testRequestId);
        console.log("Pending mint created:");
        console.log("- Mint amount:", pendingMint.mintAmount);
        console.log("- Ratio:", pendingMint.ratio);
        console.log("- Confidence:", pendingMint.confidence);

        // Finalize the mint
        try vault.finalizeMint(testRequestId) {
            console.log("Mint finalized successfully");
        } catch Error(string memory reason) {
            console.log("Failed to finalize mint:", reason);
        }

        vm.stopBroadcast();
    }

    /// @notice Step 5: Check final state after processing
    function checkFinalState() public view {
        console.log("\n=== Step 5: Final State ===");

        // Check user balances
        console.log("User AIUSD balance:", aiusd.balanceOf(user));

        // Check position
        (
            address[] memory tokens,
            uint256[] memory amounts,
            uint256 totalValueUSD,
            uint256 aiusdMinted,
            uint256 collateralRatio,
            uint256 requestId,
            bool hasPendingRequest
        ) = vault.getPosition(user);

        console.log("Position details:");
        console.log("- Total collateral value:", totalValueUSD);
        console.log("- AIUSD minted:", aiusdMinted);
        console.log("- Collateral ratio:", collateralRatio);
        console.log("- Has pending request:", hasPendingRequest);

        // Check if the pending mint was processed
        AICollateralVaultSimple.PendingMint memory pendingMint = vault.getPendingMint(testRequestId);
        console.log("- Pending mint processed:", pendingMint.processed);
    }

    /// @notice Alternative flow using the event processor contract
    function testWithEventProcessor() public {
        vm.startBroadcast(userPrivateKey);

        console.log("\n=== Alternative: Using Event Processor ===");

        // Simulate the event data that would be emitted
        uint256 oracleRequestId = 12_345; // Mock oracle request ID
        bytes memory callbackData = abi.encode(
            address(vault), // vault address
            user, // user address
            bytes("WETH:1000000000000000000,DAI:500000000000000000000"), // basket data
            3000 * 1e18, // collateral value (1 ETH * $2500 + 500 DAI)
            testRequestId // internal request ID
        );

        // Process using the event processor
        try processor.processAndFinalize(oracleRequestId, testRequestId, testAIOutput, callbackData) {
            console.log("Event processor completed successfully");
        } catch Error(string memory reason) {
            console.log("Event processor failed:", reason);
        }

        vm.stopBroadcast();
    }

    /// @notice Utility function to demonstrate batch processing
    function testBatchProcessing() public {
        console.log("\n=== Testing Batch Processing ===");
        console.log("The event processor supports batch processing multiple requests");
        console.log("This is useful for gas efficiency when processing many pending requests");

        // Example of how batch processing would work:
        AIEventProcessor.BatchRequest[] memory requests = new AIEventProcessor.BatchRequest[](1);
        requests[0] = AIEventProcessor.BatchRequest({
            oracleRequestId: 12_345,
            internalRequestId: testRequestId,
            output: testAIOutput,
            callbackData: abi.encode(address(vault), user, bytes("test"), 1000 * 1e18, testRequestId)
        });

        // In practice, you would call:
        // processor.batchProcessAndFinalize(requests);
        console.log("Batch processing setup complete (not executed in test)");
    }

    /// @notice Show gas comparison with callback system
    function showGasComparison() public view {
        console.log("\n=== Gas Comparison ===");
        console.log("SimplePrompt Pattern:");
        console.log("- Controller callback: ~200k gas (vs 500k for full callbacks)");
        console.log("- Event emission: ~5k gas");
        console.log("- Processing: Separate transaction (can be batched)");
        console.log("- Total: More flexible, potentially lower cost");
        console.log("");
        console.log("Benefits:");
        console.log("- Decoupled processing allows for optimization");
        console.log("- Batch processing reduces per-request costs");
        console.log("- Permissionless operation increases reliability");
        console.log("- Event-based architecture is more scalable");
    }
}

// Usage:
// 1. Deploy the SimplePrompt system first
// 2. Update contract addresses in setUp()
// 3. Run: source .env && forge script script/TestSimplePromptFlow.s.sol:TestSimplePromptFlowScript --fork-url
// $SEPOLIA_RPC_URL --broadcast -vv
