# Chainlink Functions Integration

This directory contains the JavaScript code that runs on Chainlink's decentralized oracle network to perform AI-powered risk assessments for our stablecoin protocol.

## Overview

The `ai-risk-assessment.js` file contains sophisticated AI logic that analyzes portfolio composition, token-specific risks, and market conditions to determine optimal collateral ratios for our AI stablecoin system.

## Prerequisites

### LINK Token Requirements

This integration requires **LINK tokens** to pay for Chainlink Functions requests:

- **Testnet LINK**: Get free testnet LINK from [faucets.chain.link/sepolia](https://faucets.chain.link/sepolia)
- **Mainnet LINK**: Purchase LINK tokens from exchanges or DEXs
- **Cost**: Each Functions request costs ~0.1-0.5 LINK depending on computation complexity
- **Subscription Model**: Fund once, use many times until balance depletes

### Supported Networks

- **Sepolia Testnet** (recommended for development)
- **Ethereum Mainnet** (production ready)
- **Polygon, Arbitrum, Avalanche** (also supported)

## AI Risk Assessment Algorithm

### Core Features

1. **Multi-factor Analysis**

   - Portfolio diversification scoring
   - Token-specific risk profiles
   - Position size risk assessment
   - Market sentiment analysis

2. **Token Risk Profiles**

   - ETH: Medium volatility, high liquidity
   - WBTC: Medium volatility, high liquidity
   - DAI/USDC: Low volatility, stable assets
   - LINK: Higher volatility, medium liquidity
   - Other tokens: Configurable risk parameters

3. **Diversification Bonuses**

   - 15% bonus for 3+ different tokens
   - 8% bonus for 2 different tokens
   - 10% additional bonus for including stablecoins

4. **Position Size Penalties**
   - 5% penalty for positions > $100k
   - 2% penalty for positions > $50k

### Outputs

- **Collateral Ratio**: 125% - 200% based on risk analysis
- **Confidence Score**: 30% - 95% based on data quality and diversification
- **Risk Factors**: Detailed breakdown of risk components

## Deployment Steps

### 1. Get LINK Tokens

**For Sepolia Testnet:**

```bash
# Visit faucets.chain.link/sepolia and request:
# - 0.5 ETH (for gas fees)
# - 25 LINK (for Functions requests)
```

**For Mainnet:**

- Purchase LINK from exchanges (Coinbase, Binance, etc.)
- Swap for LINK on DEXs (Uniswap, 1inch, etc.)
- Bridge LINK from other chains using Chainlink CCIP

### 2. Create Chainlink Functions Subscription

1. Visit [functions.chain.link](https://functions.chain.link)
2. Connect your wallet (Sepolia testnet)
3. Create a new subscription
4. Fund it with **2-5 LINK** for testing (more for production)

### 3. Update Configuration

Update `CHAINLINK_SUBSCRIPTION_ID` in `config/SepoliaConfig.sol` with your subscription ID.

### 4. Deploy RiskOracleController

```bash
source .env && forge script script/02_DeployRiskOracleController.s.sol:DeployRiskOracleControllerScript --rpc-url $SEPOLIA_RPC_URL --broadcast --private-key $DEPLOYER_PRIVATE_KEY --etherscan-api-key $ETHERSCAN_API_KEY --verify -vvvv
```

### 5. Add Consumer to Subscription

1. Go back to [functions.chain.link](https://functions.chain.link)
2. Add your deployed RiskOracleController address as a consumer

### 6. Test the Integration

```bash
source .env && forge script script/TestRiskOracleController.s.sol:TestRiskOracleControllerScript --rpc-url $SEPOLIA_RPC_URL --broadcast --private-key $DEPLOYER_PRIVATE_KEY -vvvv
```

## How It Works

1. **Vault Request**: When users deposit/withdraw, the vault calls `requestRiskAssessment()`
2. **LINK Payment**: The subscription automatically pays LINK for the request
3. **Chainlink Functions**: The request triggers our JavaScript code on Chainlink's DON
4. **AI Analysis**: The code analyzes portfolio composition and calculates optimal ratios
5. **Response**: Results are returned via `fulfillRequest()` callback
6. **Automatic Processing**: The vault uses the new ratio for minting/burning decisions

## Key Benefits for Hackathon

- **Multiple Chainlink Services**: Uses both Functions and Data Feeds
- **LINK Token Integration**: Demonstrates proper LINK token economics
- **Real AI Logic**: Sophisticated risk assessment, not just random numbers
- **Production Ready**: Error handling, fallbacks, and security measures
- **Demonstrable**: Clear before/after comparisons with different portfolios

## LINK Token Economics

### Cost Structure

- **Functions Request**: ~0.1-0.5 LINK per request
- **Data Feeds**: Free to read (already funded by Chainlink)
- **Subscription Model**: Pay once, use until depleted

### Optimization Tips

- Batch multiple assessments in one request
- Cache results for similar portfolios
- Use circuit breakers to prevent excessive requests
- Monitor subscription balance and refill proactively

## Testing Scenarios

Try these different portfolios to see varying risk assessments:

1. **Conservative**: 50% DAI, 30% USDC, 20% ETH → Lower ratio
2. **Aggressive**: 100% single volatile token → Higher ratio
3. **Diversified**: 25% each of ETH, WBTC, DAI, USDC → Moderate ratio
4. **Large Position**: $200k+ single position → Higher ratio due to size penalty

## Error Handling

The system includes comprehensive error handling:

- Invalid token symbols default to high-risk parameters
- Network failures return conservative 150% ratio with 50% confidence
- Price feed failures use fallback calculations
- LINK balance monitoring with emergency fallbacks
- All errors are logged for debugging

## Monitoring & Maintenance

### Subscription Management

- Monitor LINK balance at [functions.chain.link](https://functions.chain.link)
- Set up alerts for low balances
- Refill before reaching zero to avoid service interruption

### Performance Metrics

- Track request success rates
- Monitor response times (~30-60 seconds typical)
- Analyze cost per request for optimization

This integration showcases the power of combining Chainlink's decentralized oracle network with sophisticated AI logic for DeFi risk management, while properly utilizing LINK tokens for sustainable oracle economics.
