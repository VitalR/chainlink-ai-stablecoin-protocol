# Demo Scripts

This folder contains demonstration scripts for the AI Stablecoin hackathon project.

## 🎯 Available Demos

### **1. `HackathonAutomationDemo.s.sol`** - **Complete Automation Showcase**

**Purpose**: Full Chainlink Automation demonstration for hackathon presentation

**What it demonstrates**:

- ✅ Complete user workflow (opt-in → deposit → stuck position → automated recovery)
- ✅ Chainlink Automation integration (`checkUpkeep` and `performUpkeep`)
- ✅ Emergency withdrawal timing and execution
- ✅ Time-warp simulation for quick testing
- ✅ Real contract integration with deployed addresses

**How to run**:

```bash
# Complete demo with all features
forge script script/demo/HackathonAutomationDemo.s.sol:HackathonAutomationDemoScript \
  --sig "runFullDemo()" --rpc-url $SEPOLIA_RPC_URL --broadcast --private-key $DEPLOYER_PRIVATE_KEY

# Show registration instructions for Chainlink
forge script script/demo/HackathonAutomationDemo.s.sol:HackathonAutomationDemoScript \
  --sig "showRegistrationInstructions()" --rpc-url $SEPOLIA_RPC_URL
```

**Key features**:

- Uses **real deployed contracts** (not mocks)
- Demonstrates **complete user journey**
- Shows **Chainlink Automation** in action
- **Hackathon presentation ready**

### **2. `TestEngineSelection.s.sol`** - **AI Engine Selection Testing**

**Purpose**: Test and demonstrate the AI engine selection functionality

**What it demonstrates**:

- ✅ All 3 AI engines: ALGO, BEDROCK, TEST_TIMEOUT
- ✅ Backward compatibility with legacy deposits
- ✅ Engine-specific behavior and processing
- ✅ Error handling for different engines

**How to run**:

```bash
# Test all engine types
forge script script/demo/TestEngineSelection.s.sol:TestEngineSelectionScript \
  --rpc-url $SEPOLIA_RPC_URL --broadcast --private-key $DEPLOYER_PRIVATE_KEY
```

**Engine types tested**:

- **ALGO** - Chainlink Functions with sophisticated algorithmic analysis
- **BEDROCK** - Off-chain Amazon Bedrock AI processing
- **TEST_TIMEOUT** - Testing engine for automation scenarios

## 🧹 Recently Cleaned Up

**Removed redundant scripts**:

- ❌ `TestEmergencyAutomation.s.sol` - Functionality covered by `HackathonAutomationDemo.s.sol`
- ❌ `CompleteAutomationTest.s.sol` - Duplicate of hackathon demo functionality
- ❌ `UserOptInDemo.s.sol` - Opt-in process covered in hackathon demo
- ❌ `BedrockPositionCreation.s.sol` - Superseded by integrated `script/bedrock/` workflow

## 🎯 When to Use Which Demo

### **For Hackathon Judges/Sponsors**

- Use `HackathonAutomationDemo.s.sol` → **Complete showcase**

### **For Testing Engine Selection**

- Use `TestEngineSelection.s.sol` → **Engine functionality**

### **For Bedrock AI Workflow**

- Use `script/bedrock/ExecuteDepositWithBedrock.s.sol` → **Enterprise AI**

### **For Manual Processing**

- Use `script/execute/ProcessManualRequest.s.sol` → **AI response processing**

## 📚 Related Documentation

- **Automation**: [docs/chainlink-automation-guide.md](../../docs/chainlink-automation-guide.md)
- **Bedrock AI**: [docs/bedrock-ai-workflow-guide.md](../../docs/bedrock-ai-workflow-guide.md)
- **Engine Selection**: [docs/engine-selection.md](../../docs/engine-selection.md)
- **Deployment Status**: [docs/project-deployment-status.md](../../docs/project-deployment-status.md)

---

**💡 These demos showcase our complete AI-powered stablecoin system with enterprise-grade reliability and hackathon-ready presentation quality!**
