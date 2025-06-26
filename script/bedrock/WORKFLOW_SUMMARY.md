# 🚀 Bedrock AI Workflow - Quick Reference

## Complete 4-Step Process

### 1️⃣ Execute Bedrock Deposit

```bash
source .env && BEDROCK_SCENARIO=single forge script script/bedrock/ExecuteDepositWithBedrock.s.sol:ExecuteDepositWithBedrockScript --rpc-url $SEPOLIA_RPC_URL --broadcast --private-key $DEPLOYER_PRIVATE_KEY -vv
```

### 2️⃣ Get Processing Command

```bash
source .env && forge script script/bedrock/GetDepositData.s.sol:GetDepositDataScript --sig "getBedrockProcessingCommand()" --rpc-url $SEPOLIA_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY -vv
```

### 3️⃣ Run AI Analysis

```bash
cd test/standalone && node ProcessBedrockDeposit.js --requestId 123 --tokens "DAI" --amounts "100" --totalValue 100
```

### 4️⃣ Process Response

```bash
source .env && forge script script/execute/ProcessManualRequest.s.sol --sig "processWithAIResponse(uint256,string)" 123 "RATIO:145 CONFIDENCE:80 SOURCE:BEDROCK_AI" --rpc-url $SEPOLIA_RPC_URL --broadcast --private-key $DEPLOYER_PRIVATE_KEY -vv
```

## Scenarios Available

- `BEDROCK_SCENARIO=single` → 100 DAI
- `BEDROCK_SCENARIO=diversified` → WETH + WBTC + DAI
- `BEDROCK_SCENARIO=institutional` → Large amounts

## Key Benefits

✅ **Enterprise AI** (Claude 3 Sonnet)  
✅ **Real Data Integration**  
✅ **Guaranteed Processing**  
✅ **Superior Capital Efficiency** (70-90%)  
✅ **Copy-Paste Commands** (No manual data entry)

---

📖 **Full docs**: [../../docs/bedrock-ai-workflow.md](../../docs/bedrock-ai-workflow.md)
