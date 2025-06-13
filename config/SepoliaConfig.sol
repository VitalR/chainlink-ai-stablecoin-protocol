// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/// @notice Latest configuration of deployed contracts
library SepoliaConfig {
    uint256 public constant CHAIN_ID = 11155111;

    address public constant AISTABLECOIN = 0xb4036672FE9f82ff0B9149beBD6721538e085ffa;

    address public constant MOCK_DAI = 0xF19061331751efd44eCd2E9f49903b7D68651368;
    address public constant MOCK_WETH = 0x7f4eb26422b35D3AA5a72D7711aD12905bb69F59;
    address public constant MOCK_WBTC = 0x4a098CaCd639aE0CC70F6f03d4A01608286b155d;
}
