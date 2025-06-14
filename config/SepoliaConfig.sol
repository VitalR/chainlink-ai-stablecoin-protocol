// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/// @notice Latest configuration of deployed contracts
library SepoliaConfig {
    uint256 public constant CHAIN_ID = 11_155_111;

    // Core system contracts
    address public constant AI_STABLECOIN = 0xb4036672FE9f82ff0B9149beBD6721538e085ffa;
    address public constant AI_CONTROLLER = 0x0C8516a5B5465547746DFB0cA80897E456Cc68C8;
    address public constant AI_VAULT = 0x0d8a34dCD87b50291c4F7b0706Bfde71Abd1aFf2;

    // External Oracle
    address public constant ORA_ORACLE = 0x0A0f4321214BB6C7811dD8a71cF587bdaF03f0A0;

    // Mock tokens for testing
    address public constant MOCK_DAI = 0xF19061331751efd44eCd2E9f49903b7D68651368;
    address public constant MOCK_WETH = 0x7f4eb26422b35D3AA5a72D7711aD12905bb69F59;
    address public constant MOCK_WBTC = 0x4a098CaCd639aE0CC70F6f03d4A01608286b155d;
}
