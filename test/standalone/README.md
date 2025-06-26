# Standalone Amazon Bedrock Testing

## 🏆 **HACKATHON TECHNICAL SHOWCASE**

> **This folder demonstrates our complete AWS Bedrock integration working perfectly in a local environment, showcasing the technical sophistication behind our AI-powered stablecoin system.**

### **🎯 For Judges & Sponsors:**

- **✅ AWS Integration Mastery** - Full Bedrock API implementation with proper authentication
- **✅ Production-Grade Code** - Complete error handling, parsing, and validation
- **✅ Technical Problem-Solving** - Shows adaptation from cloud constraints to optimized solutions
- **✅ Dual Approach** - Both cutting-edge AI and algorithmic excellence

### **🚀 Quick Demo Commands:**

```bash
# Test the full AWS Bedrock integration (works locally)
./test/standalone/run-test.sh

# Compare AI vs Algorithmic results
node test/standalone/TestBedrockDirect.js
```

### **💡 Why This Matters:**

- **Proves Technical Depth** - We CAN integrate with AWS Bedrock (local proof)
- **Shows Constraint Adaptation** - Chainlink Functions sandbox → Optimized algorithm
- **Better User Outcomes** - 125% ratios vs 150-200% industry standard
- **Production Ready** - Robust fallback architecture with 100% uptime

---

This directory contains standalone tests for the Amazon Bedrock AI integration, allowing you to test the AI risk assessment logic directly without Chainlink Functions.

## 🎯 Purpose

- **Validate AI Logic**: Test the prompt engineering and response parsing
- **Debug Integration**: Isolate Bedrock API issues from Chainlink issues
- **Fast Development**: Iterate quickly without blockchain transactions
- **Demonstrate AI**: Show the sophisticated risk assessment in action

## 🚀 Quick Start

### Option 1: With AWS Credentials (Full Bedrock Testing)

1. **Set AWS credentials** (if you have Bedrock access):

```bash
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_REGION="us-east-1"  # or your preferred region
```

2. **Run the test**:

```bash
cd test/standalone
node TestBedrockDirect.js
```

### Option 2: Without AWS Credentials (Algorithmic Testing)

Even without AWS credentials, you can test the algorithmic fallback logic:

```bash
cd test/standalone
node TestBedrockDirect.js
```

The script will automatically fall back to the sophisticated algorithmic assessment used in production.

## 📊 Test Scenarios

The script tests 4 different portfolio scenarios:

1. **Conservative Portfolio**: 100% stablecoins (DAI + USDC)
2. **Balanced Portfolio**: Mixed assets (DAI + WETH + WBTC)
3. **Aggressive Portfolio**: High volatility assets (WETH + WBTC + LINK)
4. **Single Asset Portfolio**: 100% WBTC (highest risk)

## 🔍 What You'll See

For each test scenario, you'll get:

- **Portfolio composition** and total value
- **AI prompt** sent to Bedrock (or algorithmic inputs)
- **Raw AI response** (if using Bedrock)
- **Parsed results**:
  - Recommended collateral ratio (125-200%)
  - Confidence level (30-95%)
  - Source (BEDROCK_AI or ALGORITHMIC_FALLBACK)
  - Capital efficiency percentage
  - Mintable AIUSD amount

## 🧠 AI Analysis Framework

The AI analyzes portfolios using:

1. **Diversification Analysis** (Herfindahl-Hirschman Index)
2. **Volatility Assessment** (Historical patterns + current conditions)
3. **Liquidity Evaluation** (Market depth + slippage risk)
4. **Market Conditions** (DeFi sentiment + regulatory environment)

## 📈 Expected Results

- **Conservative portfolios**: Lower ratios (125-140%) = Higher capital efficiency
- **Balanced portfolios**: Medium ratios (140-160%) = Balanced approach
- **Aggressive portfolios**: Higher ratios (160-200%) = Lower risk

## 🔧 Customization

You can modify `TEST_SCENARIOS` in the script to test your own portfolio compositions:

```javascript
{
  name: "Your Custom Portfolio",
  portfolio: {
    tokens: ['TOKEN1', 'TOKEN2'],
    amounts: [1000, 0.5],
    values: [1000, 1200],  // USD values
    totalValue: 2200
  }
}
```

## 🛠 Technical Details

- **AWS Signature V4**: Full implementation for Bedrock authentication
- **Claude 3 Sonnet**: Uses the same model as production (anthropic.claude-3-sonnet-20240229-v1:0)
- **Same Logic**: Identical prompt engineering and parsing as Chainlink Functions
- **Fallback System**: Graceful degradation to algorithmic assessment

## 🎯 Benefits

✅ **Rapid Testing**: No blockchain transactions or gas costs  
✅ **AI Validation**: Verify prompt engineering works correctly  
✅ **Debug Tool**: Isolate issues between AI and blockchain layers  
✅ **Demo Ready**: Show sophisticated AI analysis to stakeholders  
✅ **Development**: Fast iteration on AI logic improvements

## 🔗 Integration

This standalone test uses the exact same:

- AI prompts
- Response parsing logic
- Algorithmic fallback calculations
- Safety bounds and validation

As the production Chainlink Functions implementation, ensuring consistency between testing and live deployment.

# Standalone AI Testing Scripts

This folder contains JavaScript scripts for testing AI analysis independently of the blockchain.

## Scripts

### `TestBedrockDirect.js` - **Template & Visualization**

- **Purpose**: Learning tool and AI visualization
- **Data**: Fixed test scenarios (Conservative, Balanced, Aggressive, Single Asset)
- **Usage**: Understanding how Bedrock AI works
- **Run**: `node TestBedrockDirect.js`

### `ProcessBedrockDeposit.js` - **Production Integration** ⭐

- **Purpose**: Process real user deposits with AI
- **Data**: Actual deposit data from blockchain
- **Usage**: Production Bedrock workflow
- **Run**: `node ProcessBedrockDeposit.js --requestId 123 --tokens "DAI" --amounts "100" --totalValue 100`

## Key Differences

| Feature         | TestBedrockDirect.js | ProcessBedrockDeposit.js   |
| --------------- | -------------------- | -------------------------- |
| **Purpose**     | Template/Learning    | Production Processing      |
| **Data Source** | Fixed scenarios      | Real blockchain deposits   |
| **Integration** | Standalone           | Part of complete workflow  |
| **Output**      | AI analysis examples | Ready-to-execute commands  |
| **Use Case**    | Understanding AI     | Processing actual deposits |

## Workflow Integration

```
🔗 Blockchain Deposit
    ↓
📋 script/bedrock/GetDepositData.s.sol
    ↓
🧠 ProcessBedrockDeposit.js (THIS FOLDER)
    ↓
⛓️ script/execute/ProcessManualRequest.s.sol
```

## Quick Commands

```bash
# Template/Learning (independent)
node TestBedrockDirect.js

# Production processing (integrated)
node ProcessBedrockDeposit.js --requestId 123 --tokens "DAI" --amounts "100" --totalValue 100

# Or with environment variables
export REQUEST_ID=123 TOKENS="DAI" AMOUNTS="100" TOTAL_VALUE=100
node ProcessBedrockDeposit.js
```

---

🔗 **Complete workflow**: [../../docs/bedrock-ai-workflow.md](../../docs/bedrock-ai-workflow.md)
