// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/// @notice Latest configuration of deployed contracts
library SepoliaConfig {
    uint256 public constant CHAIN_ID = 11_155_111;

    // Core system contracts
    address public constant AI_STABLECOIN = 0xb4036672FE9f82ff0B9149beBD6721538e085ffa;
    address public constant AI_CONTROLLER = 0x067b6c730DBFc6F180A70eae12D45305D12fe58A;
    address public constant AI_VAULT = 0x3b8Fd1cB957B96e9082c270938B1C1C083e3fb94;

    // External Oracle
    address public constant ORA_ORACLE = 0x0A0f4321214BB6C7811dD8a71cF587bdaF03f0A0;

    // Mock Oracle for Demo
    address public constant MOCK_ORACLE = 0x8E6cD9Aad0Ba18abC02883d948A067B246beB3D8;

    // Mock tokens for testing
    address public constant MOCK_DAI = 0xF19061331751efd44eCd2E9f49903b7D68651368;
    address public constant MOCK_WETH = 0x7f4eb26422b35D3AA5a72D7711aD12905bb69F59;
    address public constant MOCK_WBTC = 0x4a098CaCd639aE0CC70F6f03d4A01608286b155d;
}
