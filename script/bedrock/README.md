# Bedrock AI Engine Scripts

> 🔗 **LIVE TRANSACTION PROOFS:** See [../../docs/bedrock-ai-workflow-transaction-proofs.md](../../docs/bedrock-ai-workflow-transaction-proofs.md) for concrete on-chain evidence of the complete Bedrock workflow including diversified deposits (WETH+WBTC+DAI+LINK), AI processing, and withdrawals.

This folder contains scripts for the **BEDROCK AI Engine** workflow - our enterprise-grade Amazon Bedrock integration for DeFi risk assessment.

## Quick Start Workflow

### 1. Execute Bedrock Deposit

```bash
# Single token deposit (100 DAI)
source .env && BEDROCK_SCENARIO=single forge script script/bedrock/ExecuteDepositWithBedrock.s.sol:ExecuteDepositWithBedrockScript --rpc-url $SEPOLIA_RPC_URL --broadcast --private-key $DEPLOYER_PRIVATE_KEY -vv

# Diversified portfolio (WETH + WBTC + DAI)
source .env && BEDROCK_SCENARIO=diversified forge script script/bedrock/ExecuteDepositWithBedrock.s.sol:ExecuteDepositWithBedrockScript --rpc-url $SEPOLIA_RPC_URL --broadcast --private-key $DEPLOYER_PRIVATE_KEY -vv

# Institutional deposit (Large amounts)
source .env && BEDROCK_SCENARIO=institutional forge script script/bedrock/ExecuteDepositWithBedrock.s.sol:ExecuteDepositWithBedrockScript --rpc-url $SEPOLIA_RPC_URL --broadcast --private-key $DEPLOYER_PRIVATE_KEY -vv
```

### 2. Get Integrated Processing Command

```bash
# Get ready-to-use commands for your deposit (RECOMMENDED)
source .env && forge script script/bedrock/GetDepositData.s.sol:GetDepositDataScript --sig "getBedrockProcessingCommand()" --rpc-url $SEPOLIA_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY -vv
```

### 3. Run Integrated Bedrock Processor

```bash
# Copy-paste the command from Step 2 output
cd test/standalone && node ProcessBedrockDeposit.js --requestId 123 --tokens "DAI" --amounts "100" --totalValue 100
```

### 4. Execute Final Processing

```bash
# Copy-paste the command from Step 3 output
source .env && forge script script/execute/ProcessManualRequest.s.sol --sig "processWithAIResponse(uint256,string)" 123 "RATIO:145 CONFIDENCE:80 SOURCE:BEDROCK_AI" --rpc-url $SEPOLIA_RPC_URL --broadcast --private-key $DEPLOYER_PRIVATE_KEY -vv
```

## Scripts

### `ExecuteDepositWithBedrock.s.sol`

Creates Bedrock AI deposits with different scenarios:

- **single**: 100 DAI deposit
- **diversified**: WETH + WBTC + DAI portfolio
- **institutional**: Large value deposits

**Key Features:**

- Off-chain AI processing via AWS Bedrock
- Multiple portfolio scenarios
- System status checking
- Comprehensive logging

### `GetDepositData.s.sol`

Retrieves and formats deposit data for AI processing:

- Latest deposit information
- Request ID extraction
- Ready-to-use command generation
- Integration with ProcessBedrockDeposit.js

**Key Functions:**

- `getLatestDepositData()` - General deposit info
- `getBedrockProcessingCommand()` - **RECOMMENDED** - Ready commands
- `getPositionData(uint256)` - Specific position data

## Environment Variables

```bash
# Required for deposits
export DEPLOYER_PRIVATE_KEY=0x...
export DEPLOYER_PUBLIC_KEY=0x...
export SEPOLIA_RPC_URL=https://...

# Optional user switching
export USER_PRIVATE_KEY=0x...
export USER_PUBLIC_KEY=0x...
export DEPOSIT_TARGET_USER=USER  # or DEPLOYER (default)

# AWS Bedrock (for AI processing)
export AWS_REGION=us-east-1
export AWS_ACCESS_KEY_ID=your_key
export AWS_SECRET_ACCESS_KEY=your_secret
```

## Verification Commands

```bash
# Check Bedrock system status
source .env && forge script script/bedrock/ExecuteDepositWithBedrock.s.sol:ExecuteDepositWithBedrockScript --sig "checkBedrockSystemStatus()" --rpc-url $SEPOLIA_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY -vv

# Check latest deposit data
source .env && forge script script/bedrock/GetDepositData.s.sol:GetDepositDataScript --rpc-url $SEPOLIA_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY -vv

# Demonstrate Bedrock advantages
source .env && forge script script/bedrock/ExecuteDepositWithBedrock.s.sol:ExecuteDepositWithBedrockScript --sig "demonstrateBedrockAdvantages()" --rpc-url $SEPOLIA_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY -vv
```

## Integration Flow

```
ExecuteDepositWithBedrock.s.sol
            ↓
   Creates on-chain request
            ↓
GetDepositData.s.sol (getBedrockProcessingCommand)
            ↓
   Outputs formatted commands
            ↓
../../test/standalone/ProcessBedrockDeposit.js
            ↓
   AWS Bedrock AI analysis
            ↓
../execute/ProcessManualRequest.s.sol
            ↓
   On-chain processing & AIUSD minting
```

## Benefits

✅ **Enterprise AI**: Amazon Bedrock + Claude 3 Sonnet  
✅ **Real Data**: Works with actual user deposits  
✅ **Guaranteed Processing**: Manual fallback ensures completion  
✅ **Optimized Ratios**: Superior capital efficiency (70-90%)  
✅ **Production Ready**: Handles real value transactions

## Bedrock Processing Time Breakdown:

### Quick Components (~30 seconds - 2 minutes):

- ✅ **Bedrock API Response**: AWS Bedrock typically responds in 5-30 seconds
- ✅ **On-chain Transaction**: Final processing takes ~30 seconds

### Manual/Human Components (1-8 minutes):

- 🔧 **Manual Steps**: Copy-pasting commands between steps
- 🔧 **Command Execution**: Running multiple terminal commands
- 🔧 **Data Verification**: Checking outputs and formatting
- 🔧 **Environment Setup**: Switching directories, sourcing .env files

The **"2-10 minutes"** accounts for:

1. **Best Case (2-3 minutes)**: Experienced user, all commands ready, smooth execution
2. **Typical Case (3-7 minutes)**: Normal user following documentation step-by-step
3. **Worst Case (7-10 minutes)**: New user, troubleshooting, or complex portfolio analysis

---

📖 **See [bedrock-ai-workflow-guide.md](../../docs/bedrock-ai-workflow-guide.md) for complete documentation**
