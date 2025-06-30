# Complete Deployment Guide

## 🚀 AI Stablecoin Protocol Deployment

This guide provides step-by-step instructions for deploying the AI Stablecoin protocol to Ethereum Sepolia and Avalanche Fuji testnets.

## Prerequisites

### 1. Environment Setup

```bash
# Clone repository
git clone <repository>
cd ai-stablecoin

# Install dependencies
forge install
npm install

# Copy environment template
cp .env.example .env
```

### 2. Required Accounts & Services

- **Wallet**: Funded with testnet ETH and AVAX
- **Chainlink Functions**: Subscription with LINK tokens
- **AWS Bedrock**: Access to Claude 3 Sonnet
- **Etherscan API**: For contract verification

### 3. Get Testnet Tokens

- **Sepolia ETH**: [Chainlink Faucet](https://faucets.chain.link/sepolia)
- **Sepolia LINK**: [Chainlink Faucet](https://faucets.chain.link/sepolia)
- **Fuji AVAX**: [Avalanche Faucet](https://faucet.avax.network/)

## Environment Configuration

```bash
# .env file configuration
SEPOLIA_RPC_URL=https://eth-sepolia.g.alchemy.com/v2/YOUR_KEY
FUJI_RPC_URL=https://api.avax-test.network/ext/bc/C/rpc
DEPLOYER_PRIVATE_KEY=0x...
ETHERSCAN_API_KEY=YOUR_ETHERSCAN_KEY

# Chainlink Functions
CHAINLINK_SUBSCRIPTION_ID=5075
CHAINLINK_DON_ID=0x66756e2d657468657265756d2d7365706f6c69612d3100000000000000000000

# AWS Bedrock
AWS_REGION=us-east-1
AWS_ACCESS_KEY_ID=YOUR_AWS_KEY
AWS_SECRET_ACCESS_KEY=YOUR_AWS_SECRET
```

## Deployment Steps

### Step 1: Deploy Test Tokens

```bash
source .env && forge script script/deploy/00_DeployTokens.s.sol:DeployTokensScript \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast \
  --private-key $DEPLOYER_PRIVATE_KEY \
  --etherscan-api-key $ETHERSCAN_API_KEY \
  --verify -vvvv
```

### Step 2: Deploy AIUSD Stablecoin

```bash
forge script script/deploy/01_DeployStablecoin.s.sol:DeployStablecoinScript \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast \
  --private-key $DEPLOYER_PRIVATE_KEY \
  --etherscan-api-key $ETHERSCAN_API_KEY \
  --verify -vvvv
```

### Step 3: Deploy RiskOracleController (Chainlink Functions)

```bash
forge script script/deploy/02_DeployController.s.sol:DeployControllerScript \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast \
  --private-key $DEPLOYER_PRIVATE_KEY \
  --etherscan-api-key $ETHERSCAN_API_KEY \
  --verify -vvvv
```

### Step 4: Deploy Automation Contracts

```bash
forge script script/deploy/03_DeployAutomation.s.sol:DeployAutomationScript \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast \
  --private-key $DEPLOYER_PRIVATE_KEY \
  --etherscan-api-key $ETHERSCAN_API_KEY \
  --verify -vvvv
```

### Step 5: Deploy CollateralVault (Data Feeds)

```bash
forge script script/deploy/04_DeployVault.s.sol:DeployVaultScript \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast \
  --private-key $DEPLOYER_PRIVATE_KEY \
  --etherscan-api-key $ETHERSCAN_API_KEY \
  --verify -vvvv
```

### Step 6: Authorize Vault

```bash
forge script script/deploy/05_AuthorizeVault.s.sol:AuthorizeVaultScript \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast \
  --private-key $DEPLOYER_PRIVATE_KEY \
  --etherscan-api-key $ETHERSCAN_API_KEY \
  --verify -vvvv
```

### Step 7: Deploy CCIP Bridge

```bash
forge script script/deploy/07_DeployCCIPBridge.s.sol:DeployCCIPBridgeScript \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast \
  --private-key $DEPLOYER_PRIVATE_KEY \
  --etherscan-api-key $ETHERSCAN_API_KEY \
  --verify -vvvv
```

### Step 8: Deploy to Avalanche Fuji

```bash
forge script script/deploy/08_DeployToFuji.s.sol:DeployToFujiScript \
  --rpc-url $FUJI_RPC_URL \
  --broadcast \
  --private-key $DEPLOYER_PRIVATE_KEY \
  --verify -vvvv
```

## Post-Deployment Configuration

### 1. Configure Chainlink Functions

1. Visit [functions.chain.link](https://functions.chain.link)
2. Add RiskOracleController as consumer to your subscription
3. Update AI source code:

```bash
forge script script/execute/UpdateAISourceCode.s.sol:UpdateAISourceCodeScript \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast \
  --private-key $DEPLOYER_PRIVATE_KEY -vv
```

### 2. Register Chainlink Automation

1. Visit [automation.chain.link/sepolia](https://automation.chain.link/sepolia)
2. Register upkeep for AutoEmergencyWithdrawal contract
3. Fund with LINK tokens

### 3. Fund Contracts

```bash
# Fund RiskOracleController with LINK
forge script script/execute/FundContracts.s.sol:FundContractsScript \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast \
  --private-key $DEPLOYER_PRIVATE_KEY -vv
```

## Verification

### Test Deployment

```bash
# Run full test suite
forge test --fork-url $SEPOLIA_RPC_URL

# Test AI integration
./test/standalone/demo.sh

# Test cross-chain bridge
forge script script/demo/TestCCIPBridge.s.sol \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast \
  --private-key $DEPLOYER_PRIVATE_KEY -vv
```

### Verify Contracts

```bash
# Verify all contracts on Etherscan
forge verify-contract --chain sepolia CONTRACT_ADDRESS src/CONTRACT.sol:CONTRACT --etherscan-api-key $ETHERSCAN_API_KEY
```

## Troubleshooting

### Common Issues

1. **Insufficient LINK Balance**

   ```bash
   # Check subscription balance
   forge script script/utils/CheckSubscription.s.sol --rpc-url $SEPOLIA_RPC_URL -vv
   ```

2. **Contract Verification Failed**

   ```bash
   # Retry verification
   forge verify-contract --chain sepolia ADDRESS src/Contract.sol:Contract --etherscan-api-key $ETHERSCAN_API_KEY --watch
   ```

3. **AI Request Timeout**
   ```bash
   # Check Functions activity
   # Visit functions.chain.link to monitor requests
   ```

## Security Checklist

- [ ] Private keys stored securely
- [ ] Contract addresses verified on Etherscan
- [ ] Chainlink subscription funded
- [ ] Automation upkeeps registered
- [ ] Emergency procedures tested
- [ ] Multi-sig setup for mainnet (if applicable)

## Next Steps

1. Update frontend configuration with deployed addresses
2. Create demo video showing the protocol in action
3. Submit to hackathon with all required documentation
4. Consider security audit before mainnet deployment

---

For detailed technical documentation, see the [complete docs folder](../docs/).
 