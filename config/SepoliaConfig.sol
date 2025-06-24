// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/// @notice Latest configuration of deployed contracts
library SepoliaConfig {
    uint256 public constant CHAIN_ID = 11_155_111;

    // Core system contracts (update after deployment)
    address public constant AI_STABLECOIN = 0xf0072115e6b861682e73a858fBEE36D512960c6f; // UPDATED
    address public constant RISK_ORACLE_CONTROLLER = 0xf8D3A0d5dE0368319123a43b925d01D867Af2229; // UPDATED - Enhanced with OUSG
    address public constant COLLATERAL_VAULT = 0x3fAA42438AA43020611BC6a5269e109CC8B7a03c; // UPDATED - Enhanced with Dynamic Pricing

    // Mock tokens for testing - UPDATED with fresh deployment
    address public constant MOCK_DAI = 0xDE27C8D88E8F949A7ad02116F4D8BAca459af5D4;
    address public constant MOCK_WETH = 0xe1cb3cFbf87E27c52192d90A49DB6B331C522846;
    address public constant MOCK_WBTC = 0x4b62e33297A6D7eBe7CBFb92A0Bf175209467022;
    address public constant MOCK_USDC = 0x3bf2384010dCb178B8c19AE30a817F9ea1BB2c94;

    // === RWA TOKENS (Ondo Finance) === UPDATED
    address public constant MOCK_OUSG = 0x27675B132A8a872Fdc50A19b854A9398c62b8905; // DEPLOYED
    address public constant OUSG_USD_PRICE_FEED = 0x13A0cc7e061d876512F548c92d327a2A10cc81F0; // DEPLOYED

    // Chainlink Functions Configuration
    address public constant CHAINLINK_FUNCTIONS_ROUTER = 0xb83E47C2bC239B3bf370bc41e1459A34b41238D0;
    bytes32 public constant CHAINLINK_DON_ID = 0x66756e2d657468657265756d2d7365706f6c69612d3100000000000000000000;
    uint32 public constant CHAINLINK_GAS_LIMIT = 300000;
    uint64 public constant CHAINLINK_SUBSCRIPTION_ID = 5075; // UPDATED with your new subscription

    // Chainlink Data Feeds (Sepolia Testnet)
    address public constant ETH_USD_PRICE_FEED = 0x694AA1769357215DE4FAC081bf1f309aDC325306;
    address public constant BTC_USD_PRICE_FEED = 0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43;
    address public constant LINK_USD_PRICE_FEED = 0xc59E3633BAAC79493d908e63626716e204A45EdF;
    address public constant DAI_USD_PRICE_FEED = 0x14866185B1962B63C3Ea9E03Bc1da838bab34C19;
    address public constant USDC_USD_PRICE_FEED = 0xA2F78ab2355fe2f984D808B5CeE7FD0A93D5270E;
}
