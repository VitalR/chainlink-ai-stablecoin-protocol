// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import { ERC20 } from "@openzeppelin/token/ERC20/ERC20.sol";

/// @title MockOUSG - Mock Ondo Short-Term US Government Bond Fund
/// @notice Mock implementation of Ondo's OUSG token for testing
/// @dev This appreciates in value over time like the real OUSG token
contract MockOUSG is ERC20 {
    address public immutable owner;

    // Mock price that appreciates over time (simulating treasury yield)
    uint256 public pricePerToken = 100.0e18; // Simplified: $100.00 for easy demo calculations
    uint256 public lastUpdateTime;
    uint256 public constant ANNUAL_YIELD_RATE = 500; // 5.0% annual yield (500 basis points)

    constructor() ERC20("Mock Ondo Short-Term US Government Bond Fund", "OUSG") {
        owner = msg.sender;
        lastUpdateTime = block.timestamp;
    }

    /// @notice Mint tokens to an address (for testing)
    function mint(address to, uint256 amount) external {
        require(msg.sender == owner, "Only owner can mint");
        _mint(to, amount);
    }

    /// @notice Get current price per token (appreciates with simulated yield)
    function getCurrentPrice() external returns (uint256) {
        _updatePrice();
        return pricePerToken;
    }

    /// @notice Get current price without state update
    function getPrice() external view returns (uint256) {
        return pricePerToken;
    }

    /// @notice Update price based on time elapsed (simulates yield accrual)
    function _updatePrice() internal {
        uint256 timeElapsed = block.timestamp - lastUpdateTime;
        if (timeElapsed > 0) {
            // Simple linear appreciation for demo (real OUSG uses more complex mechanics)
            uint256 yieldAccrued = (pricePerToken * ANNUAL_YIELD_RATE * timeElapsed) / (365 days * 1000);
            pricePerToken += yieldAccrued;
            lastUpdateTime = block.timestamp;
        }
    }

    /// @notice Override transfer to update price
    function transfer(address to, uint256 amount) public override returns (bool) {
        _updatePrice();
        return super.transfer(to, amount);
    }

    /// @notice Override transferFrom to update price
    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        _updatePrice();
        return super.transferFrom(from, to, amount);
    }
}
