// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/// @notice Latest configuration of deployed contracts
library SepoliaConfig {
    uint256 public constant CHAIN_ID = 11_155_111;

    address public constant AI_STABLECOIN = 0xb4036672FE9f82ff0B9149beBD6721538e085ffa;
    address public constant AI_CONTROLLER = 0x2D07d4664Eda995431d5dBc011bA14D9DA530f2d;
    address public constant AI_VAULT = 0x2C5f279b44A7f4F272C818b2Dc07cAA6F5aAC01D;

    address public constant MOCK_DAI = 0xF19061331751efd44eCd2E9f49903b7D68651368;
    address public constant MOCK_WETH = 0x7f4eb26422b35D3AA5a72D7711aD12905bb69F59;
    address public constant MOCK_WBTC = 0x4a098CaCd639aE0CC70F6f03d4A01608286b155d;
}
