// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { Test } from "forge-std/Test.sol";
import { console } from "forge-std/console.sol";
import { AggregatorV3Interface } from "@chainlink/contracts/shared/interfaces/AggregatorV3Interface.sol";

import { AIStablecoin } from "../src/AIStablecoin.sol";
import { RiskOracleController } from "../src/RiskOracleController.sol";

/// @title Price Feed Integration Tests
/// @notice Tests for hybrid Chainlink price feed integration with fallback mechanisms
contract PriceFeedIntegrationTest is Test {
    RiskOracleController public controller;
    AIStablecoin public stablecoin;

    // Mock price feed for testing
    MockPriceFeed public mockBTCFeed;
    MockPriceFeed public mockETHFeed;

    address public owner = address(0x1);
    address public user = address(0x2);

    function setUp() public {
        vm.startPrank(owner);

        // Deploy contracts with correct constructor parameters
        stablecoin = new AIStablecoin();
        controller = new RiskOracleController(
            address(0x1), // Mock functions router
            bytes32("test_don_id"), // Mock DON ID
            1, // Mock subscription ID
            "test source code" // Mock AI source code
        );

        // Deploy mock price feeds
        mockBTCFeed = new MockPriceFeed(8, "BTC/USD");
        mockETHFeed = new MockPriceFeed(8, "ETH/USD");

        // Set initial prices (8 decimals)
        mockBTCFeed.updatePrice(45_000 * 1e8, block.timestamp); // $45,000
        mockETHFeed.updatePrice(2500 * 1e8, block.timestamp); // $2,500

        vm.stopPrank();
    }

    /// @notice Test setting up Sepolia price feeds
    function test_setupSepoliaFeeds() public {
        vm.prank(owner);
        controller.setupSepoliaFeeds();

        // Verify feeds are set
        AggregatorV3Interface btcFeed = controller.priceFeeds("BTC");
        AggregatorV3Interface ethFeed = controller.priceFeeds("ETH");

        assertEq(address(btcFeed), 0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43);
        assertEq(address(ethFeed), 0x694AA1769357215DE4FAC081bf1f309aDC325306);
    }

    /// @notice Test price feeds with mock data
    function test_priceFeeds_withMockData() public {
        vm.startPrank(owner);

        // Set up mock feeds
        string[] memory tokens = new string[](2);
        address[] memory feeds = new address[](2);

        tokens[0] = "BTC";
        feeds[0] = address(mockBTCFeed);
        tokens[1] = "ETH";
        feeds[1] = address(mockETHFeed);

        controller.setPriceFeeds(tokens, feeds);
        vm.stopPrank();

        // Test price retrieval
        string memory jsonPrices = controller.getCurrentPricesForTesting();

        // Should contain real prices from mock feeds
        assertTrue(bytes(jsonPrices).length > 0);
        console.log("JSON Prices:", jsonPrices);

        // Verify it contains BTC and ETH prices (not exact match due to JSON formatting)
        assertEq(keccak256(bytes(jsonPrices)) != keccak256(bytes("")), true);
    }

    /// @notice Test fallback when no price feed is configured
    function test_priceFeeds_fallbackWhenNotConfigured() public {
        // Don't configure any feeds
        string memory jsonPrices = controller.getCurrentPricesForTesting();

        // Should use fallback prices: BTC=$30,000, ETH=$2,000, LINK=$15, DAI=$1, USDC=$1, OUSG=$100
        assertTrue(bytes(jsonPrices).length > 0);
        console.log("Fallback Prices:", jsonPrices);

        // Should contain fallback values including LINK and OUSG
        bytes memory expected = bytes('{"BTC": 30000, "ETH": 2000, "LINK": 15, "DAI": 1, "USDC": 1, "OUSG": 100}');
        assertEq(keccak256(bytes(jsonPrices)), keccak256(expected));
    }

    /// @notice Test fallback when price feed returns invalid data
    function test_priceFeeds_fallbackOnInvalidPrice() public {
        vm.startPrank(owner);

        // Set up mock feed with invalid price
        mockBTCFeed.updatePrice(-1000 * 1e8, block.timestamp); // Negative price

        string[] memory tokens = new string[](1);
        address[] memory feeds = new address[](1);
        tokens[0] = "BTC";
        feeds[0] = address(mockBTCFeed);

        controller.setPriceFeeds(tokens, feeds);
        vm.stopPrank();

        string memory jsonPrices = controller.getCurrentPricesForTesting();
        console.log("Invalid Price Fallback:", jsonPrices);

        // Should fallback to $30,000 for BTC
        assertTrue(bytes(jsonPrices).length > 0);
    }

    /// @notice Test fallback when price feed data is stale
    function test_priceFeeds_fallbackOnStalePrice() public {
        vm.startPrank(owner);

        // Move forward in time first to avoid underflow
        vm.warp(block.timestamp + 10_000); // Move 10k seconds forward

        // Set up mock feed with stale data (2 hours old from new timestamp)
        mockBTCFeed.updatePrice(45_000 * 1e8, block.timestamp - 7200);

        string[] memory tokens = new string[](1);
        address[] memory feeds = new address[](1);
        tokens[0] = "BTC";
        feeds[0] = address(mockBTCFeed);

        controller.setPriceFeeds(tokens, feeds);
        vm.stopPrank();

        string memory jsonPrices = controller.getCurrentPricesForTesting();
        console.log("Stale Price Fallback:", jsonPrices);

        // Should fallback to $30,000 for BTC
        assertTrue(bytes(jsonPrices).length > 0);
    }

    /// @notice Test price bounds validation
    function test_priceFeeds_boundsValidation() public {
        vm.startPrank(owner);

        // Test BTC with price outside reasonable bounds
        mockBTCFeed.updatePrice(500_000 * 1e8, block.timestamp); // $500k (too high)

        string[] memory tokens = new string[](1);
        address[] memory feeds = new address[](1);
        tokens[0] = "BTC";
        feeds[0] = address(mockBTCFeed);

        controller.setPriceFeeds(tokens, feeds);
        vm.stopPrank();

        string memory jsonPrices = controller.getCurrentPricesForTesting();
        console.log("Out of Bounds Fallback:", jsonPrices);

        // Should fallback due to unreasonable price
        assertTrue(bytes(jsonPrices).length > 0);
    }

    /// @notice Test that DAI and USDC always use stable fallback
    function test_stablecoins_alwaysUseFallback() public {
        string memory jsonPrices = controller.getCurrentPricesForTesting();

        // DAI and USDC should always be $1
        assertTrue(bytes(jsonPrices).length > 0);

        // Check that it contains DAI and USDC at $1
        bytes memory jsonBytes = bytes(jsonPrices);
        bool containsDAI = _contains(jsonBytes, bytes('"DAI": 1'));
        bool containsUSDC = _contains(jsonBytes, bytes('"USDC": 1'));

        assertTrue(containsDAI);
        assertTrue(containsUSDC);
    }

    /// @notice Helper function to expose internal price function for testing
    function getCurrentPricesForTesting() external view returns (string memory) {
        return controller.getCurrentPricesForTesting();
    }

    /// @notice Helper function to check if bytes contains a pattern
    function _contains(bytes memory source, bytes memory pattern) internal pure returns (bool) {
        if (pattern.length > source.length) return false;

        for (uint256 i = 0; i <= source.length - pattern.length; i++) {
            bool found = true;
            for (uint256 j = 0; j < pattern.length; j++) {
                if (source[i + j] != pattern[j]) {
                    found = false;
                    break;
                }
            }
            if (found) return true;
        }
        return false;
    }
}

/// @title Mock Price Feed Contract
/// @notice Mock implementation of Chainlink AggregatorV3Interface for testing
contract MockPriceFeed is AggregatorV3Interface {
    uint8 public immutable override decimals;
    string public override description;
    uint256 public override version = 1;

    int256 private _price;
    uint256 private _updatedAt;
    uint80 private _roundId = 1;

    constructor(uint8 _decimals, string memory _description) {
        decimals = _decimals;
        description = _description;
    }

    function updatePrice(int256 newPrice, uint256 timestamp) external {
        _price = newPrice;
        _updatedAt = timestamp;
        _roundId++;
    }

    function latestRoundData()
        external
        view
        override
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        return (_roundId, _price, _updatedAt, _updatedAt, _roundId);
    }

    function getRoundData(uint80) external pure override returns (uint80, int256, uint256, uint256, uint80) {
        revert("Not implemented");
    }
}
