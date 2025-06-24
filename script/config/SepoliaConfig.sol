// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/// @title SepoliaConfig
/// @notice Configuration constants for Sepolia testnet deployment
contract SepoliaConfig {
    // =============================================================
    //                   CURRENT ENHANCED CONTRACTS
    // =============================================================

    // Core system contracts (enhanced versions)
    address constant AI_STABLECOIN = 0xf0072115e6b861682e73a858fBEE36D512960c6f;
    address payable constant COLLATERAL_VAULT = payable(0x3fAA42438AA43020611BC6a5269e109CC8B7a03c);
    address constant RISK_ORACLE_CONTROLLER = 0xf8D3A0d5dE0368319123a43b925d01D867Af2229;

    // =============================================================
    //                   BACKUP V1 CONTRACTS (WORKING)
    // =============================================================

    // 🎯 IMPORTANT: These addresses represent SUCCESSFUL RWA integration
    // Current user has 15,385.08 AIUSD backed by OUSG + crypto assets
    // Keep these for potential rollback or comparison testing

    address constant AI_STABLECOIN_V1 = 0xf0072115e6b861682e73a858fBEE36D512960c6f; // Same token
    address constant COLLATERAL_VAULT_V1 = 0x3fAA42438AA43020611BC6a5269e109CC8B7a03c; // Working vault
    address constant RISK_ORACLE_CONTROLLER_V1 = 0xf8D3A0d5dE0368319123a43b925d01D867Af2229; // Enhanced controller

    // Success metrics from V1:
    // - User: 0x4841AfEcfAB609Fb0253640484Dcd3dE5d1cB264
    // - AIUSD Balance: 15,385.08 tokens
    // - Proof of: OUSG RWA -> AI Assessment -> AIUSD Minting SUCCESS
    // - Date: June 2025

    // =============================================================
    //                     RWA TOKEN ADDRESSES
    // =============================================================

    // Real-World Assets (Treasury-backed)
    address constant OUSG_TOKEN = 0x27675B132A8a872Fdc50A19b854A9398c62b8905;
    address constant OUSG_USD_PRICE_FEED = 0x13A0cc7e061d876512F548c92d327a2A10cc81F0;

    // =============================================================
    //                   TRADITIONAL CRYPTO TOKENS
    // =============================================================

    // Test tokens for traditional crypto collateral
    address constant WETH_TOKEN = 0xe1cb3cFbf87E27c52192d90A49DB6B331C522846;
    address constant WBTC_TOKEN = 0x4b62e33297A6D7eBe7CBFb92A0Bf175209467022;
    address constant DAI_TOKEN = 0xDE27C8D88E8F949A7ad02116F4D8BAca459af5D4;
    address constant USDC_TOKEN = 0x94a9D9AC8a22534E3FaCa9F4e7F2E2cf85d5E4C8;

    // Price feeds for traditional crypto (Chainlink)
    address constant ETH_USD_PRICE_FEED = 0x694AA1769357215DE4FAC081bf1f309aDC325306;
    address constant BTC_USD_PRICE_FEED = 0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43;
    address constant DAI_USD_PRICE_FEED = 0x14866185B1962B63C3Ea9E03Bc1da838bab34C19;
    address constant USDC_USD_PRICE_FEED = 0xA2F78ab2355fe2f984D808B5CeE7FD0A93D5270E;

    // =============================================================
    //                    CHAINLINK CONFIGURATION
    // =============================================================

    // Chainlink Functions setup
    uint64 constant CHAINLINK_SUBSCRIPTION_ID = 5075;
    uint32 constant CHAINLINK_GAS_LIMIT = 300_000;
    bytes32 constant CHAINLINK_DON_ID = 0x66756e2d657468657265756d2d7365706f6c69612d3100000000000000000000;

    // =============================================================
    //                    DEPLOYMENT UTILITIES
    // =============================================================

    /// @notice Get current enhanced contract addresses
    function getCurrentContracts() external pure returns (address vault, address controller, address stablecoin) {
        return (COLLATERAL_VAULT, RISK_ORACLE_CONTROLLER, AI_STABLECOIN);
    }

    /// @notice Get V1 backup contract addresses
    function getV1Contracts() external pure returns (address vault, address controller, address stablecoin) {
        return (COLLATERAL_VAULT_V1, RISK_ORACLE_CONTROLLER_V1, AI_STABLECOIN_V1);
    }
}
