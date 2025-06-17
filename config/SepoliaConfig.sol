// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/// @notice Latest configuration of deployed contracts
library SepoliaConfig {
    uint256 public constant CHAIN_ID = 11_155_111;

    // Core system contracts (update after deployment)
    address public constant AI_STABLECOIN = 0xb4036672FE9f82ff0B9149beBD6721538e085ffa;
    address public constant RISK_ORACLE_CONTROLLER = 0x067b6c730DBFc6F180A70eae12D45305D12fe58A;
    address public constant COLLATERAL_VAULT = 0x3b8Fd1cB957B96e9082c270938B1C1C083e3fb94;

    // Mock tokens for testing
    address public constant MOCK_DAI = 0xF19061331751efd44eCd2E9f49903b7D68651368;
    address public constant MOCK_WETH = 0x7f4eb26422b35D3AA5a72D7711aD12905bb69F59;
    address public constant MOCK_WBTC = 0x4a098CaCd639aE0CC70F6f03d4A01608286b155d;
    address public constant MOCK_USDC = 0x0000000000000000000000000000000000000000; // To be set after deployment

    // Chainlink Functions Configuration
    address public constant CHAINLINK_FUNCTIONS_ROUTER = 0xb83E47C2bC239B3bf370bc41e1459A34b41238D0;
    bytes32 public constant CHAINLINK_DON_ID = 0x66756e2d657468657265756d2d7365706f6c69612d3100000000000000000000;
    uint32 public constant CHAINLINK_GAS_LIMIT = 300000;
    uint64 public constant CHAINLINK_SUBSCRIPTION_ID = 2912; // Updated with actual subscription ID

    // Chainlink Data Feeds (Sepolia Testnet)
    address public constant ETH_USD_PRICE_FEED = 0x694AA1769357215DE4FAC081bf1f309aDC325306;
    address public constant BTC_USD_PRICE_FEED = 0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43;
    address public constant LINK_USD_PRICE_FEED = 0xc59E3633BAAC79493d908e63626716e204A45EdF;
    address public constant DAI_USD_PRICE_FEED = 0x14866185B1962B63C3Ea9E03Bc1da838bab34C19;
    address public constant USDC_USD_PRICE_FEED = 0xA2F78ab2355fe2f984D808B5CeE7FD0A93D5270E;
}
