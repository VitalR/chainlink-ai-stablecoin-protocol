# AI Stablecoin Avalanche Fuji Deployment Guide

## Overview

This guide covers deploying the AI Stablecoin system to Avalanche Fuji testnet, enabling cross-chain functionality via Chainlink CCIP. The deployment includes the complete AI Stablecoin ecosystem with cross-chain bridging capabilities.

## Architecture

```
Ethereum Sepolia                 Avalanche Fuji
┌─────────────────┐              ┌─────────────────┐
│ AI Stablecoin   │              │ AI Stablecoin   │
│ (AI Analysis)   │              │ (DeFi Liquidity)│
└─────────────────┘              └─────────────────┘
         │                                │
┌─────────────────┐   CCIP Bridge   ┌─────────────────┐
│ CCIP Bridge     │◄───────────────►│ CCIP Bridge     │
│ (Burn & Send)   │                 │ (Receive & Mint)│
└─────────────────┘                 └─────────────────┘
```

## Prerequisites

### 1. Environment Setup

```bash
# Run the setup script
./script/utils/setup-fuji.sh
```

### 2. Required Environment Variables

Add to your `.env` file:

```bash
# Avalanche Fuji RPC
FUJI_RPC_URL=https://api.avax-test.network/ext/bc/C/rpc

# Deployment wallet (needs AVAX for gas)
DEPLOYER_PRIVATE_KEY=your_private_key_here

# Existing Sepolia addresses (if bridging)
AI_STABLECOIN_ADDRESS=0xf0072115e6b861682e73a858fBEE36D512960c6f
AI_STABLECOIN_BRIDGE_Ethereum_Sepolia_ADDRESS=<after_sepolia_bridge_deployment>
```

### 3. Get Testnet AVAX

Visit [Avalanche Faucet](https://faucet.avax.network/) to get testnet AVAX for gas fees.

## Deployment Options

### Option 1: Full System Deployment

Deploy the complete AI Stablecoin system to Fuji:

```bash
forge script script/deploy/08_DeployToFuji.s.sol:DeployToFujiScript \
  --rpc-url $FUJI_RPC_URL \
  --broadcast \
  --verify
```

This deploys:

- ✅ AI Stablecoin contract
- ✅ CCIP Bridge contract
- ✅ Configures bridge as authorized vault
- ✅ Sets up Sepolia as supported source chain

### Option 2: Bridge-Only Deployment

If AI Stablecoin already exists on Fuji:

```bash
forge script script/deploy/07_DeployCCIPBridge.s.sol:DeployCCIPBridgeScript \
  --rpc-url $FUJI_RPC_URL \
  --broadcast \
  --verify
```

## Post-Deployment Configuration

### 1. Update Configuration File

After deployment, update `config/FujiConfig.sol` with the deployed addresses:

```solidity
// Update these addresses after deployment
address public constant AI_STABLECOIN = 0x<DEPLOYED_ADDRESS>;
address public constant AI_STABLECOIN_CCIP_BRIDGE = 0x<DEPLOYED_ADDRESS>;
```

### 2. Configure Cross-Chain Trust

Set up bidirectional trust between Sepolia and Fuji bridges:

```bash
# Configure Fuji bridge to trust Sepolia bridge
forge script script/crosschain/SetupCCIPBridge.s.sol:SetupCCIPBridgeScript \
  --rpc-url $FUJI_RPC_URL \
  --broadcast

# Configure Sepolia bridge to trust Fuji bridge (run on Sepolia)
forge script script/crosschain/SetupCCIPBridge.s.sol:SetupCCIPBridgeScript \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast
```

### 3. Verify Deployment

Check contracts on [SnowTrace](https://testnet.snowtrace.io/):

```bash
# Test bridge configuration
forge script script/deploy/08_DeployToFuji.s.sol:DeployToFujiScript \
  --sig "testBridgeConfiguration()" \
  --rpc-url $FUJI_RPC_URL
```

## Network Information

| Parameter          | Value                                        |
| ------------------ | -------------------------------------------- |
| **Chain ID**       | 43113                                        |
| **Currency**       | AVAX                                         |
| **Block Explorer** | https://testnet.snowtrace.io/                |
| **CCIP Router**    | `0xF694E193200268f9a4868e4Aa017A0118C9a8177` |
| **LINK Token**     | `0x0b9d5D9136855f6FEc3c0993feE6E9CE8a297846` |
| **Chain Selector** | `14767482510784806043`                       |

## Usage Examples

### Bridging AIUSD from Sepolia to Fuji

1. **On Sepolia**: Approve bridge to spend AIUSD

```solidity
aiStablecoin.approve(bridgeAddress, amount);
```

2. **On Sepolia**: Bridge tokens to Fuji

```solidity
bridge.bridgeTokens{value: fee}(
    14767482510784806043, // Fuji chain selector
    recipient,            // Address to receive on Fuji
    amount,              // Amount to bridge
    PayFeesIn.Native     // Pay fees in ETH
);
```

3. **Result**:
   - AIUSD burned on Sepolia
   - AIUSD minted on Fuji (5-10 minutes later)

### Fee Calculation

```solidity
// Calculate bridging fees
uint256 fees = bridge.calculateBridgeFees(
    14767482510784806043, // Fuji selector
    amount,
    PayFeesIn.Native
);
```

## Value Proposition

### For Users

- **AI Analysis**: Benefit from sophisticated AI risk assessment on Sepolia
- **DeFi Access**: Use AIUSD in Avalanche's thriving DeFi ecosystem
- **Lower Costs**: Enjoy faster transactions and lower fees on Avalanche
- **Liquidity**: Access to Trader Joe, AAVE, Pangolin, and other protocols

### For Developers

- **Proven Security**: Battle-tested burn-and-mint bridge mechanism
- **Chainlink Integration**: 4 Chainlink services (Functions, Data Feeds, Automation, CCIP)
- **Flexibility**: Support for both LINK and native token fee payments
- **Monitoring**: Comprehensive events and view functions

## Avalanche DeFi Integration

Once AIUSD is on Fuji, users can:

1. **Trader Joe**: Provide liquidity in AIUSD pairs
2. **AAVE**: Use AIUSD as collateral or earn yield
3. **Pangolin**: Swap AIUSD for other assets
4. **Curve** (if available): Stable swaps with other stablecoins

## Monitoring and Maintenance

### Bridge Health Checks

```bash
# Check bridge status
cast call $BRIDGE_ADDRESS "supportedChains(uint64)" 16015286601757825753 --rpc-url $FUJI_RPC_URL

# Check trusted remotes
cast call $BRIDGE_ADDRESS "trustedRemoteBridges(uint64)" 16015286601757825753 --rpc-url $FUJI_RPC_URL

# Check vault authorization
cast call $AI_STABLECOIN_ADDRESS "authorizedVaults(address)" $BRIDGE_ADDRESS --rpc-url $FUJI_RPC_URL
```

### CCIP Message Tracking

Monitor cross-chain messages on [CCIP Explorer](https://ccip.chain.link/).

## Troubleshooting

### Common Issues

1. **"ChainNotSupported" Error**

   - Ensure destination chain is added: `bridge.setSupportedChain(chainSelector, true)`

2. **"UntrustedSource" Error**

   - Configure trusted remote: `bridge.setTrustedRemote(chainSelector, remoteBridge)`

3. **"InsufficientBalance" Error**

   - Check user has enough AIUSD and bridge allowance

4. **Bridge Delays**
   - CCIP messages take 5-10 minutes to process
   - Check [CCIP Explorer](https://ccip.chain.link/) for message status

### Support Channels

- **Chainlink CCIP**: [Discord](https://discord.gg/chainlink)
- **Avalanche**: [Discord](https://discord.gg/avalanche)
- **Documentation**: [Avalanche Docs](https://docs.avax.network/)

## Security Considerations

1. **Bridge Authorization**: Only authorized vaults can mint/burn
2. **Trusted Sources**: Only trusted bridges can trigger minting
3. **Chain Validation**: All supported chains explicitly configured
4. **Emergency Controls**: Owner can pause and withdraw stuck funds

## Future Enhancements

1. **Additional Chains**: Expand to Polygon, Arbitrum, Base
2. **DeFi Integrations**: Direct integration with major protocols
3. **Rate Limiting**: Add daily/weekly bridge limits
4. **Automated Rebalancing**: Smart contract-based liquidity management

---

**Ready to bridge the future of AI-powered DeFi across chains!** 🌉
