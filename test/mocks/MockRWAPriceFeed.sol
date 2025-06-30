// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { AggregatorV3Interface } from "@chainlink/contracts/shared/interfaces/AggregatorV3Interface.sol";

/// @title MockRWAPriceFeed - Simulates Chainlink price feeds for RWA tokens
/// @notice Mock implementation that simulates realistic RWA token price behavior
/// @dev This can be used for OUSG (appreciating) or USDY (stable) tokens
contract MockRWAPriceFeed is AggregatorV3Interface {
    struct RoundData {
        uint80 roundId;
        int256 answer;
        uint256 startedAt;
        uint256 updatedAt;
        uint80 answeredInRound;
    }

    uint8 public constant override decimals = 8; // Standard Chainlink format
    string public description;
    uint256 public constant override version = 1;

    // Price tracking
    int256 public basePrice;
    uint256 public lastUpdateTime;
    uint256 public annualYieldRate; // Basis points (e.g., 530 = 5.3%)
    bool public isStable; // True for USDY-like tokens, false for OUSG-like

    uint80 private latestRoundId;
    mapping(uint80 => RoundData) private rounds;

    constructor(string memory _description, int256 _basePrice, uint256 _annualYieldRate, bool _isStable) {
        description = _description;
        basePrice = _basePrice;
        annualYieldRate = _annualYieldRate;
        isStable = _isStable;
        lastUpdateTime = block.timestamp;
        latestRoundId = 1;

        // Initialize first round
        rounds[1] = RoundData({
            roundId: 1,
            answer: _basePrice,
            startedAt: block.timestamp,
            updatedAt: block.timestamp,
            answeredInRound: 1
        });
    }

    /// @notice Get the latest price (calculates current price based on time)
    function latestRoundData()
        external
        view
        override
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        // Calculate current price based on time elapsed
        int256 currentPrice = _calculateCurrentPrice();

        // Return current round with calculated price
        RoundData memory round = rounds[latestRoundId];
        return (
            round.roundId,
            currentPrice, // Use calculated price
            round.startedAt,
            block.timestamp, // Current update time
            round.answeredInRound
        );
    }

    /// @notice Get historical round data
    function getRoundData(uint80 _roundId)
        external
        view
        override
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        require(_roundId <= latestRoundId && _roundId > 0, "Round not found");
        RoundData memory round = rounds[_roundId];
        return (round.roundId, round.answer, round.startedAt, round.updatedAt, round.answeredInRound);
    }

    /// @notice Calculate current price based on yield and time
    function _calculateCurrentPrice() internal view returns (int256) {
        if (isStable) {
            // Stable tokens like USDY should stay around $1
            return basePrice; // e.g., 100000000 for $1.00
        } else {
            // Appreciating tokens like OUSG should grow with yield
            uint256 timeElapsed = block.timestamp - lastUpdateTime;
            // Fixed: annualYieldRate is in basis points (500 = 5%), so divide by 10000
            // Formula: (basePrice * yieldRate * timeElapsed) / (365 days * 10000 basis points)
            uint256 yieldAccrued = (uint256(basePrice) * annualYieldRate * timeElapsed) / (365 days * 10_000);
            return basePrice + int256(yieldAccrued);
        }
    }

    /// @notice Update yield rate (for testing different scenarios)
    function updateYieldRate(uint256 _newRate) external {
        annualYieldRate = _newRate;
    }

    /// @notice Manual price update (for testing)
    function updatePrice(int256 _newPrice) external {
        basePrice = _newPrice;
        lastUpdateTime = block.timestamp;
    }
}
