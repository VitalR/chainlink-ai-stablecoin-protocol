// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/// @notice Configuration for Avalanche Fuji testnet deployment
/// @dev This config supports the AI Stablecoin cross-chain bridge to Avalanche
library FujiConfig {
    uint256 public constant CHAIN_ID = 43_113; // Avalanche Fuji

    // =============================================================
    //                    CORE SYSTEM CONTRACTS
    // =============================================================
    
    // AI Stablecoin system contracts (DEPLOYED)
    address public constant AI_STABLECOIN = 0x26D0f5BD1DAb1c02D1Fc198Fe6ECa2b22Ab276d7; // DEPLOYED: AI Stablecoin on Fuji
    address public constant RISK_ORACLE_CONTROLLER = address(0); // DEPLOY: Risk Oracle with Fuji config
    address public constant COLLATERAL_VAULT = address(0); // DEPLOY: Collateral vault for Fuji assets

    // =============================================================
    //                    CCIP BRIDGE INFRASTRUCTURE
    // =============================================================
    
    // CCIP Bridge contracts (DEPLOYED)
    address public constant AI_STABLECOIN_CCIP_BRIDGE = 0xd6cE29223350252e3dD632f0bb1438e827da12b6; // DEPLOYED: Main bridge contract
    
    // Official Chainlink CCIP infrastructure on Avalanche Fuji
    address public constant CCIP_ROUTER = 0xF694E193200268f9a4868e4Aa017A0118C9a8177; // Official Fuji CCIP Router
    uint64 public constant FUJI_CHAIN_SELECTOR = 14767482510784806043; // Avalanche Fuji CCIP selector
    
    // Cross-chain trust relationships
    uint64 public constant ETHEREUM_SEPOLIA_SELECTOR = 16015286601757825753;
    address public constant TRUSTED_SEPOLIA_BRIDGE = 0xB76cD1A5c6d63042D316AabB2f40a5887dD4B1D4; // SET: Sepolia bridge deployed

    // =============================================================
    //                    AVALANCHE NATIVE TOKENS
    // =============================================================
    
    // Official tokens on Avalanche Fuji
    address public constant LINK_TOKEN = 0x0b9d5D9136855f6FEc3c0993feE6E9CE8a297846; // Official Fuji LINK
    address public constant WAVAX = 0xd00ae08403B9bbb9124bB305C09058E32C39A48c; // Wrapped AVAX on Fuji
    
    // Popular testnet tokens on Fuji (if available)
    address public constant USDC_E = 0x5425890298aed601595a70AB815c96711a31Bc65; // USDC.e on Fuji
    address public constant WETH_E = 0x86d67c3D38D2bCeE722E601025C25a575021c6EA; // WETH.e on Fuji
    address public constant WBTC_E = 0x50b7545627a5162F82A992c33b87aDc75187B218; // WBTC.e on Fuji

    // =============================================================
    //                    CHAINLINK INFRASTRUCTURE
    // =============================================================
    
    // Chainlink Functions (if available on Fuji)
    address public constant CHAINLINK_FUNCTIONS_ROUTER = address(0); // UPDATE: If Functions available
    bytes32 public constant CHAINLINK_DON_ID = bytes32(0); // UPDATE: Fuji DON ID
    uint32 public constant CHAINLINK_GAS_LIMIT = 300000;
    uint64 public constant CHAINLINK_SUBSCRIPTION_ID = 0; // UPDATE: After subscription creation

    // Chainlink Data Feeds (Avalanche Fuji Testnet)
    address public constant AVAX_USD_PRICE_FEED = 0x5498BB86BC934c8D34FDA08E81D444153d0D06aD; // AVAX/USD
    address public constant ETH_USD_PRICE_FEED = 0x86d67c3D38D2bCeE722E601025C25a575021c6EA; // ETH/USD (if available)
    address public constant BTC_USD_PRICE_FEED = 0x31CF013A08c6Ac228C94551d535d5BAfE19c602a; // BTC/USD
    address public constant LINK_USD_PRICE_FEED = 0x79c91fd4F8b3DaBEe17d286EB11cEE4D83521775; // LINK/USD

    // =============================================================
    //                    AVALANCHE DEFI ECOSYSTEM
    // =============================================================
    
    // Major DeFi protocols on Avalanche (for reference)
    // Note: These are mainnet addresses - update with Fuji addresses if available
    address public constant TRADER_JOE_ROUTER = address(0); // UPDATE: Trader Joe on Fuji
    address public constant PANGOLIN_ROUTER = address(0); // UPDATE: Pangolin on Fuji
    address public constant AAVE_POOL = address(0); // UPDATE: AAVE on Fuji (if available)
    
    // =============================================================
    //                    DEPLOYMENT CONFIGURATION
    // =============================================================
    
    // Bridge deployment parameters
    uint256 public constant BRIDGE_INITIAL_GAS_LIMIT = 200_000; // Gas for cross-chain calls
    bool public constant SUPPORTS_NATIVE_FEE_PAYMENT = true; // AVAX fee payments
    bool public constant SUPPORTS_LINK_FEE_PAYMENT = true; // LINK fee payments

    // Network-specific settings
    uint256 public constant BLOCK_TIME = 2; // Avalanche ~2 second blocks
    uint256 public constant FINALITY_BLOCKS = 1; // Fast finality on Avalanche
    
    // =============================================================
    //                    AUTOMATION CONTRACTS
    // =============================================================
    
    // Chainlink Automation (if deployed)
    address public constant AUTO_EMERGENCY_WITHDRAWAL = address(0); // DEPLOY: If automation needed

    // =============================================================
    //                    HELPER FUNCTIONS
    // =============================================================
    
    /// @notice Check if bridge is properly configured
    /// @return isConfigured True if all essential addresses are set
    function isBridgeConfigured() internal pure returns (bool isConfigured) {
        return AI_STABLECOIN != address(0) && 
               AI_STABLECOIN_CCIP_BRIDGE != address(0) &&
               TRUSTED_SEPOLIA_BRIDGE != address(0);
    }
    
    /// @notice Get supported cross-chain destinations
    /// @return selectors Array of supported chain selectors
    function getSupportedChains() internal pure returns (uint64[] memory selectors) {
        selectors = new uint64[](1);
        selectors[0] = ETHEREUM_SEPOLIA_SELECTOR; // Sepolia is primary source
        return selectors;
    }
    
    /// @notice Get network display name
    /// @return name Human-readable network name
    function getNetworkName() internal pure returns (string memory name) {
        return "Avalanche Fuji Testnet";
    }
} 