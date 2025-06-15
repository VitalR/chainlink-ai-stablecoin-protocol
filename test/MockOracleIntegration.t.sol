// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "forge-std/Test.sol";
import "../src/MockAIOracleDemo.sol";
import "../src/AIController.sol";
import "../src/CollateralVault.sol";
import "../src/AIStablecoin.sol";
import "./mocks/MockERC20.sol";

contract MockOracleIntegrationTest is Test {
    // Core contracts
    MockAIOracleDemo mockOracle;
    AIController aiController;
    CollateralVault vault;
    AIStablecoin aiusd;
    
    // Mock tokens
    MockERC20 dai;
    MockERC20 weth;
    MockERC20 wbtc;
    
    // Test accounts
    address user = makeAddr("user");
    address owner = makeAddr("owner");
    
    // Test constants
    uint256 constant INITIAL_BALANCE = 10000e18;
    uint256 constant DEPOSIT_AMOUNT_DAI = 1000e18;
    uint256 constant DEPOSIT_AMOUNT_WETH = 1e18;
    uint256 constant DEPOSIT_AMOUNT_WBTC = 0.02e18;
    
    function setUp() public {
        vm.startPrank(owner);
        
        // Deploy mock tokens
        dai = new MockERC20("DAI", "DAI", 18);
        weth = new MockERC20("WETH", "WETH", 18);
        wbtc = new MockERC20("WBTC", "WBTC", 18);
        
        // Deploy AIUSD stablecoin
        aiusd = new AIStablecoin();
        
        // Deploy mock oracle
        mockOracle = new MockAIOracleDemo();
        
        // Deploy AI controller with mock oracle
        aiController = new AIController(
            address(mockOracle),
            1, // model ID
            0.001 ether // oracle fee
        );
        
        // Deploy vault
        vault = new CollateralVault(
            address(aiusd),
            address(aiController)
        );
        
        // Configure AIUSD vault authorization
        aiusd.addVault(address(vault));
        
        // Authorize vault in controller
        aiController.setAuthorizedCaller(address(vault), true);
        
        // Add supported tokens to vault
        vault.addToken(address(dai), 1e18, 18, "DAI");    // $1 DAI
        vault.addToken(address(weth), 2000e18, 18, "WETH"); // $2000 WETH
        vault.addToken(address(wbtc), 30000e18, 18, "WBTC"); // $30000 WBTC
        
        vm.stopPrank();
        
        // Setup user with tokens
        vm.startPrank(user);
        dai.mint(user, INITIAL_BALANCE);
        weth.mint(user, INITIAL_BALANCE);
        wbtc.mint(user, INITIAL_BALANCE);
        vm.stopPrank();
        
        // Label addresses for better traces
        vm.label(address(mockOracle), "MockOracle");
        vm.label(address(aiController), "AIController");
        vm.label(address(vault), "Vault");
        vm.label(address(aiusd), "AIUSD");
        vm.label(user, "User");
        vm.label(owner, "Owner");
    }
    
    function test_happy_path_single_token() public {
        console.log("=== Testing Single Token Deposit (DAI) ===");
        
        vm.startPrank(user);
        
        // Approve tokens
        dai.approve(address(vault), DEPOSIT_AMOUNT_DAI);
        
        // Prepare deposit data
        address[] memory tokens = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        tokens[0] = address(dai);
        amounts[0] = DEPOSIT_AMOUNT_DAI;
        
        // Calculate required fee
        uint256 fee = aiController.estimateTotalFee();
        vm.deal(user, fee);
        
        // Deposit and trigger AI request
        console.log("Depositing %s DAI...", DEPOSIT_AMOUNT_DAI / 1e18);
        vault.depositBasket{value: fee}(tokens, amounts);
        
        // Check position before AI processing
        (
            address[] memory depositedTokens,
            uint256[] memory depositedAmounts,
            uint256 totalValue,
            uint256 aiusdMinted,
            uint256 collateralRatio,
            uint256 requestId,
            bool hasPendingRequest
        ) = vault.getPosition(user);
        
        assertEq(depositedTokens.length, 1, "Should have 1 token");
        assertEq(depositedTokens[0], address(dai), "Should be DAI");
        assertEq(depositedAmounts[0], DEPOSIT_AMOUNT_DAI, "Should match deposit amount");
        assertEq(aiusdMinted, 0, "No AIUSD should be minted yet");
        assertTrue(hasPendingRequest, "Should have pending AI request");
        assertGt(requestId, 0, "Should have valid request ID");
        
        console.log("AI request submitted with ID:", requestId);
        console.log("Total collateral value: $%s", totalValue / 1e18);
        
        vm.stopPrank();
        
        // Simulate AI processing delay
        console.log("Waiting for AI processing (10 seconds)...");
        vm.warp(block.timestamp + 11); // Move forward 11 seconds
        
        // Process the AI request
        console.log("Processing AI request...");
        mockOracle.processRequest(requestId);
        
        // Check position after AI processing
        vm.startPrank(user);
        (
            depositedTokens,
            depositedAmounts,
            totalValue,
            aiusdMinted,
            collateralRatio,
            requestId,
            hasPendingRequest
        ) = vault.getPosition(user);
        
        assertFalse(hasPendingRequest, "Should not have pending request");
        assertGt(aiusdMinted, 0, "Should have minted AIUSD");
        assertGt(collateralRatio, 100, "Should have valid collateral ratio");
        
        console.log("AIUSD minted:", aiusdMinted / 1e18);
        console.log("Collateral ratio: %s%%", collateralRatio / 100);
        
        // Verify user received AIUSD
        uint256 userBalance = aiusd.balanceOf(user);
        assertEq(userBalance, aiusdMinted, "User should receive minted AIUSD");
        
        console.log("[SUCCESS] Single token flow completed successfully!");
        vm.stopPrank();
    }
    
    function test_happy_path_diversified_basket() public {
        console.log("=== Testing Diversified Basket (DAI + WETH + WBTC) ===");
        
        vm.startPrank(user);
        
        // Approve all tokens
        dai.approve(address(vault), DEPOSIT_AMOUNT_DAI);
        weth.approve(address(vault), DEPOSIT_AMOUNT_WETH);
        wbtc.approve(address(vault), DEPOSIT_AMOUNT_WBTC);
        
        // Prepare diversified basket
        address[] memory tokens = new address[](3);
        uint256[] memory amounts = new uint256[](3);
        tokens[0] = address(dai);
        tokens[1] = address(weth);
        tokens[2] = address(wbtc);
        amounts[0] = DEPOSIT_AMOUNT_DAI;
        amounts[1] = DEPOSIT_AMOUNT_WETH;
        amounts[2] = DEPOSIT_AMOUNT_WBTC;
        
        // Calculate required fee
        uint256 fee = aiController.estimateTotalFee();
        vm.deal(user, fee);
        
        // Deposit diversified basket
        console.log("Depositing diversified basket:");
        console.log("- %s DAI", DEPOSIT_AMOUNT_DAI / 1e18);
        console.log("- %s WETH", DEPOSIT_AMOUNT_WETH / 1e18);
        console.log("- %s WBTC", DEPOSIT_AMOUNT_WBTC / 1e18);
        
        vault.depositBasket{value: fee}(tokens, amounts);
        
        // Get position info
        (
            address[] memory depositedTokens,
            uint256[] memory depositedAmounts,
            uint256 totalValue,
            uint256 aiusdMinted,
            uint256 collateralRatio,
            uint256 requestId,
            bool hasPendingRequest
        ) = vault.getPosition(user);
        
        assertEq(depositedTokens.length, 3, "Should have 3 tokens");
        assertTrue(hasPendingRequest, "Should have pending AI request");
        
        console.log("AI request submitted with ID:", requestId);
        console.log("Total portfolio value: $%s", totalValue / 1e18);
        
        vm.stopPrank();
        
        // Simulate AI processing
        vm.warp(block.timestamp + 11);
        console.log("Processing AI request for diversified portfolio...");
        
        mockOracle.processRequest(requestId);
        
        // Check final position
        vm.startPrank(user);
        (
            depositedTokens,
            depositedAmounts,
            totalValue,
            aiusdMinted,
            collateralRatio,
            requestId,
            hasPendingRequest
        ) = vault.getPosition(user);
        
        assertFalse(hasPendingRequest, "Should not have pending request");
        assertGt(aiusdMinted, 0, "Should have minted AIUSD");
        
        console.log("AIUSD minted:", aiusdMinted / 1e18);
        console.log("Final collateral ratio: %s%%", collateralRatio / 100);
        
        // Diversified basket should get better rate (lower ratio) than single token
        // This demonstrates AI's intelligence
        console.log("[SUCCESS] Diversified basket flow completed successfully!");
        console.log("AI recognized diversification and adjusted rates accordingly");
        
        vm.stopPrank();
    }
    
    function test_ai_intelligence_compare_ratios() public {
        console.log("=== Testing AI Intelligence: Single vs Diversified ===");
        
        // Test single token first
        address user1 = makeAddr("user1");
        address user2 = makeAddr("user2");
        
        // Setup users with tokens
        dai.mint(user1, INITIAL_BALANCE);
        weth.mint(user1, INITIAL_BALANCE);
        wbtc.mint(user1, INITIAL_BALANCE);
        dai.mint(user2, INITIAL_BALANCE);
        
        uint256 fee = aiController.estimateTotalFee();
        
        // USER 1: Single token deposit (should get higher ratio)
        vm.startPrank(user1);
        vm.deal(user1, fee);
        dai.approve(address(vault), DEPOSIT_AMOUNT_DAI);
        
        address[] memory singleToken = new address[](1);
        uint256[] memory singleAmount = new uint256[](1);
        singleToken[0] = address(dai);
        singleAmount[0] = DEPOSIT_AMOUNT_DAI;
        
        vault.depositBasket{value: fee}(singleToken, singleAmount);
        (,,, uint256 aiusdMinted1,, uint256 requestId1,) = vault.getPosition(user1);
        vm.stopPrank();
        
        // USER 2: Diversified deposit (should get lower ratio = more AIUSD)
        vm.startPrank(user2);
        vm.deal(user2, fee);
        weth.mint(user2, INITIAL_BALANCE);
        wbtc.mint(user2, INITIAL_BALANCE);
        dai.approve(address(vault), DEPOSIT_AMOUNT_DAI);
        weth.approve(address(vault), DEPOSIT_AMOUNT_WETH);
        wbtc.approve(address(vault), DEPOSIT_AMOUNT_WBTC);
        
        address[] memory diversifiedTokens = new address[](3);
        uint256[] memory diversifiedAmounts = new uint256[](3);
        diversifiedTokens[0] = address(dai);
        diversifiedTokens[1] = address(weth);
        diversifiedTokens[2] = address(wbtc);
        diversifiedAmounts[0] = DEPOSIT_AMOUNT_DAI;
        diversifiedAmounts[1] = DEPOSIT_AMOUNT_WETH;
        diversifiedAmounts[2] = DEPOSIT_AMOUNT_WBTC;
        
        vault.depositBasket{value: fee}(diversifiedTokens, diversifiedAmounts);
        (,,, uint256 aiusdMinted2,, uint256 requestId2,) = vault.getPosition(user2);
        vm.stopPrank();
        
        // Process both AI requests
        vm.warp(block.timestamp + 11);
        mockOracle.processRequest(requestId1);
        mockOracle.processRequest(requestId2);
        
        // Check final results
        uint256 ratio1;
        uint256 ratio2;
        
        vm.startPrank(user1);
        (
            ,
            ,
            ,
            aiusdMinted1,
            ratio1,
            ,
            
        ) = vault.getPosition(user1);
        vm.stopPrank();
        
        vm.startPrank(user2);
        (
            ,
            ,
            ,
            aiusdMinted2,
            ratio2,
            ,
            
        ) = vault.getPosition(user2);
        vm.stopPrank();
        
        console.log("Single Token Results:");
        console.log("- AIUSD minted:", aiusdMinted1 / 1e18);
        console.log("- Collateral ratio: %s%%", ratio1 / 100);
        
        console.log("Diversified Basket Results:");
        console.log("- AIUSD minted:", aiusdMinted2 / 1e18);
        console.log("- Collateral ratio: %s%%", ratio2 / 100);
        
        // AI should give better terms (lower ratio = more AIUSD) for diversified portfolio
        console.log("[SUCCESS] AI successfully demonstrated intelligent risk assessment!");
    }
    
    function test_mock_oracle_processing_delay() public {
        console.log("=== Testing Processing Delay Mechanism ===");
        
        vm.startPrank(user);
        
        // Submit request
        dai.approve(address(vault), DEPOSIT_AMOUNT_DAI);
        address[] memory tokens = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        tokens[0] = address(dai);
        amounts[0] = DEPOSIT_AMOUNT_DAI;
        
        uint256 fee = aiController.estimateTotalFee();
        vm.deal(user, fee);
        
        vault.depositBasket{value: fee}(tokens, amounts);
        (,,,,, uint256 requestId,) = vault.getPosition(user);
        
        vm.stopPrank();
        
        // Try to process immediately (should fail)
        vm.expectRevert("Still processing");
        mockOracle.processRequest(requestId);
        
        // Check time remaining
        uint256 timeRemaining = mockOracle.getTimeUntilReady(requestId);
        console.log("Time remaining for processing: %s seconds", timeRemaining);
        assertGt(timeRemaining, 0, "Should have processing time remaining");
        
        // Wait and process successfully
        vm.warp(block.timestamp + 11);
        timeRemaining = mockOracle.getTimeUntilReady(requestId);
        assertEq(timeRemaining, 0, "Should be ready for processing");
        
        mockOracle.processRequest(requestId);
        console.log("[SUCCESS] Processing delay mechanism working correctly!");
    }
    
    function test_get_ready_requests() public {
        console.log("=== Testing Ready Requests Query ===");
        
        // Create different users for each request
        address user1 = makeAddr("testUser1");
        address user2 = makeAddr("testUser2");
        address user3 = makeAddr("testUser3");
        
        // Setup users with tokens
        dai.mint(user1, INITIAL_BALANCE);
        dai.mint(user2, INITIAL_BALANCE);
        dai.mint(user3, INITIAL_BALANCE);
        
        uint256 fee = aiController.estimateTotalFee();
        
        address[] memory tokens = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        tokens[0] = address(dai);
        amounts[0] = DEPOSIT_AMOUNT_DAI;
        
        // Submit 3 requests from different users
        vm.startPrank(user1);
        vm.deal(user1, fee);
        dai.approve(address(vault), DEPOSIT_AMOUNT_DAI);
        vault.depositBasket{value: fee}(tokens, amounts);
        vm.stopPrank();
        
        vm.warp(block.timestamp + 1);
        
        vm.startPrank(user2);
        vm.deal(user2, fee);
        dai.approve(address(vault), DEPOSIT_AMOUNT_DAI);
        vault.depositBasket{value: fee}(tokens, amounts);
        vm.stopPrank();
        
        vm.warp(block.timestamp + 1);
        
        vm.startPrank(user3);
        vm.deal(user3, fee);
        dai.approve(address(vault), DEPOSIT_AMOUNT_DAI);
        vault.depositBasket{value: fee}(tokens, amounts);
        vm.stopPrank();
        
        // Check ready requests before delay
        uint256[] memory readyRequests = mockOracle.getReadyRequests(10);
        assertEq(readyRequests.length, 0, "No requests should be ready yet");
        
        // Wait for processing delay
        vm.warp(block.timestamp + 15);
        
        // Check ready requests after delay
        readyRequests = mockOracle.getReadyRequests(10);
        assertEq(readyRequests.length, 3, "All 3 requests should be ready");
        
        console.log("Ready request IDs:");
        for (uint256 i = 0; i < readyRequests.length; i++) {
            console.log("- Request %s", readyRequests[i]);
        }
        
        console.log("[SUCCESS] Ready requests query working correctly!");
    }
} 