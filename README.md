# AI-Powered Stablecoin Protocol with Chainlink + Amazon Bedrock

## 🏆 Built for Chromion Chainlink Hackathon 2025

_Showcasing innovation in AI-powered DeFi across multiple technical categories_

### **Technical Innovation Areas:**

- **🤖 AI Integration** - Amazon Bedrock + Chainlink Functions hybrid architecture
- **🏦 DeFi Innovation** - Dynamic risk-based collateral ratios for capital efficiency
- **🔗 Cross-Platform** - Multiple Chainlink services integration (Functions + Data Feeds)

### **🚀 Technical Achievement Goals:**

✅ **First DeFi protocol** with Amazon Bedrock integration  
✅ **Hybrid AI architecture** combining enterprise AI + algorithmic intelligence  
✅ **Decentralized AI execution** via Chainlink's oracle network  
✅ **Dynamic financial parameters** that reward smart portfolio management

### **🤖 Revolutionary AI Architecture:**

✅ **Amazon Bedrock** (Claude 3 Sonnet or equivalent) for enterprise-grade risk analysis  
✅ **Sophisticated algorithmic AI** fallback for reliability  
✅ **Chainlink Functions** for decentralized AI execution  
✅ **Chainlink Data Feeds** for real-time price data

---

## Overview

An innovative stablecoin protocol that uses **hybrid AI** (Amazon Bedrock + algorithmic intelligence) to dynamically assess portfolio risk and determine optimal collateral ratios in real-time.

## 🚀 System Architecture

### Core Components

1. **AIStablecoin (AIUSD)** - The stablecoin token with vault-based minting
2. **CollateralVault** - Manages collateral deposits and positions
3. **RiskOracleController** - Handles Chainlink Functions integration and manual processing
4. **MockChainlinkFunctionsRouter** - Testing router that simulates Chainlink Functions behavior

### Hybrid AI System Features

#### ✅ **Amazon Bedrock Integration**

- **Primary AI**: Claude 3 Sonnet (or available Bedrock model) for sophisticated portfolio analysis
- **Enterprise-grade**: AWS's managed AI service for reliability
- **Dynamic risk assessment**: Real-time portfolio composition analysis
- **Market sentiment integration**: Advanced sentiment analysis capabilities

#### ✅ **Algorithmic AI Fallback**

- **Sophisticated multi-factor analysis**: Portfolio diversification, token volatility, liquidity scoring
- **Dynamic parameter adjustment**: Position size analysis, market conditions
- **Intelligent decision making**: 125-200% collateral ratios based on risk
- **High reliability**: Always available when Bedrock is unavailable

#### ✅ **Manual Processing System**

When AI systems are unavailable, the system provides multiple recovery strategies:

**Strategy 1: Process with Off-Chain AI** (Available after 30 minutes)

- Use external AI services (ChatGPT, Claude, local models)
- Parse AI response for ratio and confidence
- Mint normally with AI-determined parameters

**Strategy 2: Emergency Withdrawal** (Available after 2 hours)

- Return all collateral without minting
- User-initiated or processor-triggered
- Direct vault withdrawal after 4 hours

**Strategy 3: Force Default Mint** (Available after 30 minutes)

- Conservative 150% collateral ratio
- 50% confidence score
- Quick resolution without AI analysis

#### ✅ **Time-Based Recovery Timeline**

```
0-30 min:  Wait for normal Chainlink Functions callback
30 min+:   Manual processing available (Strategies 1 & 3)
2 hours+:  Emergency withdrawal available (Strategy 2)
4 hours+:  Direct vault withdrawal available
```

## 🛠 Usage

### For Users

#### 1. Deposit Collateral and Request AI Analysis

```solidity
// Approve tokens first
IERC20(wethAddress).approve(vaultAddress, amount);

// Deposit collateral basket
address[] memory tokens = [wethAddress, usdcAddress];
uint256[] memory amounts = [10 ether, 5000 * 1e6];

vault.depositBasket(tokens, amounts);
```

#### 2. Normal Flow (AI Works)

- **Amazon Bedrock** or **Algorithmic AI** analyzes your collateral within ~1-5 minutes
- Optimal ratio determined (e.g., 135% = diversified, 175% = concentrated)
- AIUSD automatically minted to your address

#### 3. If AI Gets Stuck (Manual Processing)

```solidity
// After 30 minutes, request manual processing
controller.requestManualProcessing(requestId);

// Or after 2 hours, emergency withdraw
controller.emergencyWithdraw(requestId);
```

### For Manual Processors

#### 1. Find Requests Needing Help

```solidity
// Get list of stuck requests
(uint256[] memory requestIds,
 address[] memory users,
 uint256[] memory timestamps,
 ManualStrategy[][] memory strategies) =
    controller.getManualProcessingCandidates(0, 10);
```

#### 2. Process with External AI

```solidity
// Use ChatGPT, Claude, or any AI service to analyze the collateral
string memory aiResponse = "RATIO:145 CONFIDENCE:85 SOURCE:EXTERNAL_AI";

controller.processWithOffChainAI(
    requestId,
    aiResponse,
    ManualStrategy.PROCESS_WITH_OFFCHAIN_AI
);
```

### For System Administrators

#### 1. Authorize Manual Processors

```solidity
controller.setAuthorizedManualProcessor(processorAddress, true);
```

#### 2. Circuit Breaker Controls

```solidity
// Emergency pause
controller.pauseProcessing();

// Resume operations
controller.resumeProcessing();
```

## 🧪 Testing

### Run All Tests

```bash
# Build contracts
forge build

# Run Chainlink Functions integration tests
./test/utils/run_improved_tests.sh

# Run E2E workflow tests
./test/utils/run_tests.sh

# Run all tests
forge test
```

### Test Coverage

- ✅ **Amazon Bedrock integration** via Chainlink Functions
- ✅ **Algorithmic AI fallback** processing and failure handling
- ✅ **Manual processing workflows** after timeout
- ✅ **Emergency withdrawal** functionality
- ✅ **Circuit breaker** functionality
- ✅ **Authorization and security** controls
- ✅ **Complete deposit and withdrawal** flows

## 🚀 Deployment

### Prerequisites

1. **AWS Setup**: Amazon Bedrock access with Claude 3 Sonnet enabled
2. **Chainlink Setup**: Functions subscription with LINK tokens
3. **Network Setup**: Deploy to Sepolia testnet or Ethereum mainnet

### Deploy Script

```bash
source .env && forge script script/deploy/02_DeployRiskOracleController.s.sol:DeployRiskOracleControllerScript --rpc-url $SEPOLIA_RPC_URL --broadcast --private-key $DEPLOYER_PRIVATE_KEY --etherscan-api-key $ETHERSCAN_API_KEY --verify -vvvv
```

### Post-Deployment Setup

1. **Configure AWS credentials** in Chainlink Functions secrets
2. **Add supported collateral tokens** with prices
3. **Authorize initial manual processors**
4. **Test with small deposits** first

## 🔧 Configuration

### AI Response Timeouts

- **Normal Processing**: 1-5 minutes (Chainlink Functions)
- **Manual Processing**: 30 minutes
- **Emergency Withdrawal**: 2 hours
- **Direct Vault Withdrawal**: 4 hours

### Safety Parameters

- **Default Conservative Ratio**: 150%
- **AI Ratio Range**: 125-200%
- **Circuit Breaker Threshold**: 5 failures
- **Auto-Reset Time**: 1 hour

## 🛡 Security Features

### Multi-Layer Protection

1. **Hybrid AI Architecture**: Primary + fallback AI systems
2. **Time-Based Permissions**: Graduated access to recovery functions
3. **Authorization Controls**: Only approved processors can intervene
4. **Circuit Breaker**: Automatic system pause on repeated failures
5. **Safe External Calls**: Gas-limited calls prevent DoS attacks

### Emergency Procedures

1. **Immediate**: Circuit breaker pause (owner only)
2. **30 minutes**: Manual processing available
3. **2 hours**: Emergency withdrawal available
4. **4 hours**: Direct vault withdrawal available

## 📊 AI Performance

### Response Sources

- **AMAZON_BEDROCK_AI**: Primary enterprise AI via Claude 3 Sonnet
- **ALGORITHMIC_AI**: Sophisticated fallback analysis
- **EXTERNAL_AI**: Manual processing with external services
- **FALLBACK**: Conservative default (150% ratio)

### Example AI Analysis

**Traditional Stablecoin**: "Everyone needs 150% collateral"

**Our AI Stablecoin**:

- **Portfolio A** (100% ETH): AI determines high risk → 175% collateral required
- **Portfolio B** (diversified): AI determines low risk → 135% collateral required

## 🤝 Community Involvement

### Become a Manual Processor

1. **Get Authorized**: Contact system administrators
2. **Monitor Requests**: Use `getManualProcessingCandidates()`
3. **Help Users**: Process stuck requests with external AI
4. **Future Rewards**: Processor incentive system planned

### AI Integration Examples

```javascript
// Example 1: Using OpenAI API for manual processing
const openaiResponse = await openai.chat.completions.create({
  model: 'gpt-4',
  messages: [
    {
      role: 'user',
      content: `Analyze this DeFi collateral basket for optimal collateral ratio.
             Consider: diversification, volatility, liquidity, position size.
             Respond: RATIO:XXX CONFIDENCE:YY (125-200%, 30-95%).
             Portfolio: ${basketData} Value: $${totalValue}`,
    },
  ],
});

// Example 2: Using Anthropic Claude API for manual processing
const claudeResponse = await anthropic.messages.create({
  model: 'claude-3-sonnet-20240229',
  max_tokens: 1000,
  messages: [
    {
      role: 'user',
      content: `Analyze this DeFi collateral basket for optimal collateral ratio.
             Consider: diversification, volatility, liquidity, position size.
             Respond: RATIO:XXX CONFIDENCE:YY (125-200%, 30-95%).
             Portfolio: ${basketData} Value: $${totalValue}`,
    },
  ],
});

// Parse and submit (works with any AI service)
await controller.processWithOffChainAI(requestId, aiResponse.content, 0);
```

**Note**: These examples are for **manual processing** by community processors. Our primary AI system uses **Amazon Bedrock (Claude 3 Sonnet)** via Chainlink Functions.

## 📚 Additional Resources

- **Amazon Bedrock**: [AWS Bedrock Documentation](https://docs.aws.amazon.com/bedrock/)
- **Chainlink Functions**: [Chainlink Functions Documentation](https://docs.chain.link/chainlink-functions)
- **Foundry Framework**: [Foundry Book](https://book.getfoundry.sh)

## 🐛 Troubleshooting

### Common Issues

**Q: My AI request is stuck, what do I do?**  
A: Wait 30 minutes, then call `requestManualProcessing()`. Community processors will help.

**Q: Can I lose my collateral?**  
A: No! Multiple recovery mechanisms ensure funds are never permanently stuck.

**Q: How does the hybrid AI work?**  
A: Primary: Amazon Bedrock (Claude 3). Fallback: Sophisticated algorithmic AI. Always reliable.

**Q: What if Chainlink Functions fail?**  
A: Manual processing system kicks in with external AI services and emergency withdrawals.

---

## 🎯 Key Benefits

✅ **Enterprise AI**: Amazon Bedrock (Claude 3 Sonnet) for sophisticated analysis  
✅ **Reliable Fallback**: Algorithmic AI ensures system never fails  
✅ **Community Support**: Manual processing helps stuck users  
✅ **Multiple Chainlink Services**: Functions + Data Feeds integration  
✅ **Dynamic Ratios**: Rewards smart diversification with lower collateral requirements  
✅ **Production Ready**: Comprehensive security and recovery mechanisms

This represents the **future of AI-powered DeFi** - where intelligent risk assessment creates more capital-efficient and fair financial protocols while maintaining enterprise-grade reliability! 🚀

## 🧠 Bedrock AI Engine Workflow

For **enterprise-grade AI analysis** using Amazon Bedrock, use our integrated workflow:

```bash
# 1. Execute Bedrock deposit
source .env && BEDROCK_SCENARIO=single forge script script/bedrock/ExecuteDepositWithBedrock.s.sol:ExecuteDepositWithBedrockScript --rpc-url $SEPOLIA_RPC_URL --broadcast --private-key $DEPLOYER_PRIVATE_KEY -vv

# 2. Get integrated processing command (RECOMMENDED)
source .env && forge script script/bedrock/GetDepositData.s.sol:GetDepositDataScript --sig "getBedrockProcessingCommand()" --rpc-url $SEPOLIA_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY -vv

# 3. Run the integrated Bedrock processor (copy-paste from step 2 output)
cd test/standalone && node ProcessBedrockDeposit.js --requestId 123 --tokens "DAI" --amounts "100" --totalValue 100

# 4. Execute the final processing command (copy-paste from step 3 output)
source .env && forge script script/execute/ProcessManualRequest.s.sol --sig "processWithAIResponse(uint256,string)" 123 "RATIO:145 CONFIDENCE:80 SOURCE:BEDROCK_AI" --rpc-url $SEPOLIA_RPC_URL --broadcast --private-key $DEPLOYER_PRIVATE_KEY -vv
```

**📖 Complete documentation:** [docs/bedrock-ai-workflow-guide.md](docs/bedrock-ai-workflow-guide.md)

## Quick Deploy & Test
