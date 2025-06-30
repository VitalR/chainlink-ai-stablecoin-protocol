# AI-Powered Stablecoin Protocol with Chainlink + Amazon Bedrock

## 🏆 Built for Chromion Chainlink Hackathon 2025

> **Showcasing innovation in AI-powered DeFi with comprehensive Chainlink ecosystem integration**

## 🚀 **TL;DR - 60 Second Overview**

**What**: AI-powered stablecoin with dynamic collateral ratios (125-200%) based on portfolio risk analysis  
**Innovation**: First DeFi protocol combining Amazon Bedrock AI + Chainlink Functions hybrid architecture  
**Chainlink Usage**: Functions (AI), Data Feeds (pricing), CCIP (bridge), Automation (emergency withdrawals)  
**Value**: 70-90% capital efficiency vs 300% traditional overcollateralization

**Quick Start**: `git clone && forge install && forge test` - [Full Setup Guide](docs/deployment-guide.md)

### **🚀 Hackathon Innovation Highlights**

- **🤖 First DeFi protocol** with Amazon Bedrock + Chainlink Functions hybrid AI architecture
- **🌉 Cross-chain bridge** enabling liquidity flow via Chainlink CCIP
- **⚡ Emergency automation** using Chainlink Automation for stuck position recovery
- **📊 Real-time pricing** via Chainlink Data Feeds integration
- **🔄 Multi-chain deployment** on Ethereum Sepolia & Avalanche Fuji

---

## 📋 Project Overview

An innovative stablecoin protocol that leverages **hybrid AI** (Amazon Bedrock + algorithmic intelligence) to dynamically assess portfolio risk and determine optimal collateral ratios in real-time. The protocol maximizes capital efficiency by rewarding diversified portfolios with lower collateral requirements.

### **🎯 Core Value Proposition**

- **Dynamic Collateral Ratios**: 125-200% based on AI-analyzed portfolio risk
- **Enterprise AI Integration**: Amazon Bedrock (Claude 3 Sonnet) via Chainlink Functions
- **Cross-Chain Liquidity**: Bridge AIUSD between Ethereum and Avalanche
- **Autonomous Operations**: Chainlink Automation for emergency risk management
- **Capital Efficiency**: Lower collateral for diversified, low-risk portfolios

---

## 🏗️ System Architecture & Stack

### **Core Smart Contracts**

| Contract                      | Description                               | Chain         |
| ----------------------------- | ----------------------------------------- | ------------- |
| `AIStablecoin.sol`            | AIUSD token with vault-based minting      | Sepolia, Fuji |
| `CollateralVault.sol`         | Manages collateral deposits and positions | Sepolia,      |
| `RiskOracleController.sol`    | Chainlink Functions + AI processing       | Sepolia       |
| `AIStablecoinCCIPBridge.sol`  | Cross-chain bridge via Chainlink CCIP     | Sepolia, Fuji |
| `AutoEmergencyWithdrawal.sol` | Chainlink Automation for risk management  | Sepolia,      |

### **Technology Stack**

**Blockchain**: Ethereum Sepolia, Avalanche Fuji  
**Oracle Network**: Chainlink (Functions, Data Feeds, CCIP, Automation)  
**AI Engine**: Amazon Bedrock (Claude 3 Sonnet)
**Testing**: Foundry  
**Deployment**: Forge Scripts, CI/CD  
**Frontend**: Next.js (React.js + Web3.js)

---

## ⛓️ Chainlink Ecosystem Integration

> **✅ Requirement**: Project uses Chainlink to make state changes on blockchain

### **1. 🤖 Chainlink Functions**

**Primary AI Processing Engine**

- **File**: `src/RiskOracleController.sol` ([Lines 314-327](src/RiskOracleController.sol#L314-L327))
- **Function**: Executes Amazon Bedrock AI analysis in decentralized manner
- **State Change**: Mints AIUSD based on AI-determined collateral ratios
- **Implementation**: DON secrets for AWS credentials, JavaScript execution

### **2. 📊 Chainlink Data Feeds**

**Real-Time Price Oracle Integration**

- **File**: `src/RiskOracleController.sol` ([Lines 728-776](src/RiskOracleController.sol#L728-L776))
- **Function**: Fetches real-time asset prices for collateral valuation
- **State Change**: Updates position values, triggers liquidations
- **Feeds**: ETH/USD, BTC/USD, USDC/USD, LINK/USD

### **3. 🌉 Chainlink CCIP**

**Cross-Chain Bridge Infrastructure**

- **File**: `src/crosschain/AIStablecoinCCIPBridge.sol` ([Lines 100-175](src/crosschain/AIStablecoinCCIPBridge.sol#L100-L175))
- **Function**: Burns AIUSD on source chain, mints on destination
- **State Change**: Cross-chain token transfers with burn-and-mint mechanism
- **Networks**: Ethereum Sepolia ↔ Avalanche Fuji

### **4. ⚡ Chainlink Automation**

**Emergency Withdrawal Automation**

- **File**: `src/automation/AutoEmergencyWithdrawal.sol` ([Lines 122-232](src/automation/AutoEmergencyWithdrawal.sol#L122-L232))
- **Function**: Monitors at-risk positions, triggers emergency withdrawals for stuck requests
- **State Change**: Executes automatic emergency withdrawals when AI processing fails beyond timeout
- **Upkeep**: Time-based automation for user protection and system reliability

---

## 🧠 Amazon Bedrock AI Integration

### **Hybrid AI Architecture**

**Primary**: Amazon Bedrock (Claude 3 Sonnet)

- Enterprise-grade AI for sophisticated portfolio analysis
- Market sentiment integration and dynamic risk assessment
- Executed via Chainlink Functions for decentralization

**Fallback**: Algorithmic AI

- Multi-factor analysis: diversification, volatility, liquidity
- High reliability when Bedrock is unavailable
- Sophisticated decision-making with 125-200% ratios

**Recovery**: Manual Processing System

- Multiple strategies for edge cases and system failures
- Time-based escalation (30min → 2hrs → 4hrs)
- Maintains protocol operation under all conditions

> **📖 Detailed Implementation**: See [Amazon Bedrock AI Workflow Guide](docs/bedrock-ai-workflow-guide.md)

---

## ✨ Key Features & Innovations

### **🎯 Dynamic Risk-Based Ratios**

- **Diversified Portfolio**: 125-135% collateral ratio
- **Moderate Risk**: 140-160% collateral ratio
- **High Risk/Concentrated**: 170-200% collateral ratio
- **Real-time adjustment** based on market conditions

### **🌉 Cross-Chain Liquidity Flow**

- **AI Analysis**: Sophisticated risk assessment on Ethereum Sepolia
- **DeFi Execution**: Bridge to Avalanche for lower fees and faster transactions
- **Bidirectional**: Move liquidity where it's needed most
- **Production Ready**: Verified transactions with CCIP Explorer tracking

> **📖 Bridge Guide**: See [CCIP Bridge Integration](docs/ccip-bridge-integration.md)

### **⚡ Autonomous Operations**

- **24/7 Monitoring**: Chainlink Automation for continuous position monitoring
- **Automatic Emergency Withdrawals**: Protect users from permanently stuck positions
- **Timeout Recovery**: Rapid response when AI processing fails beyond acceptable timeouts
- **Gas Optimization**: Efficient automation with minimal gas costs for emergency scenarios

> **📖 Automation Guide**: See [Chainlink Automation Integration](docs/chainlink-automation-integration.md)

---

## 📁 Files Using Chainlink

### **Smart Contracts with Chainlink Integration**

```
src/
├── RiskOracleController.sol          # Chainlink Functions (Primary)
├── CollateralVault.sol               # Chainlink Data Feeds
├── crosschain/
│   └── AIStablecoinCCIPBridge.sol    # Chainlink CCIP
└── automation/
    └── AutoEmergencyWithdrawal.sol   # Chainlink Automation
```

_These contracts implement the core Chainlink integrations that make state changes on the blockchain._

### **Configuration Files**

```
config/
├── SepoliaConfig.sol                # Sepolia network configuration
└── FujiConfig.sol                   # Avalanche Fuji network configuration
```

---

## 🚀 Quick Start

### **1. Install Dependencies**

```bash
git clone <repository>
cd ai-stablecoin
forge install
npm install
```

### **2. Set Environment Variables**

```bash
cp .env.example .env
# Add your RPC URLs, private keys, and API keys
```

### **3. Deploy to Testnet**

**Prerequisites:**

- Get testnet LINK tokens from [Chainlink Faucets](https://faucets.chain.link/sepolia)
- Create Chainlink Functions subscription at [functions.chain.link](https://functions.chain.link)
- Register Chainlink Automation Upkeep for emergency withdrawals at [automation.chain.link](https://automation.chain.link/sepolia)
- Set up AWS Bedrock access with Claude 3 Sonnet enabled

**📖 Detailed Deployment Guide**: See [Complete Deployment Documentation](docs/deployment-guide.md)

### **4. Test the System**

```bash
# Run comprehensive test suite
forge test

# Test live AI integration
./test/standalone/demo.sh
```

---

## 📚 Documentation

### **Detailed Implementation Guides**

- **[🤖 Chainlink Integration Overview](docs/chainlink-integration.md)** - Complete Chainlink ecosystem usage
- **[🧠 Amazon Bedrock AI Workflow](docs/bedrock-ai-workflow-guide.md)** - AI processing implementation
- **[🌉 CCIP Bridge Integration](docs/ccip-bridge-integration.md)** - Cross-chain bridge setup
- **[⚡ Chainlink Automation](docs/chainlink-automation-integration.md)** - Autonomous operations
- **[📊 Deployment Status](docs/project-deployment-status.md)** - Live deployment information

### **User Guides & Workflows**

- **[Manual Processing Guide](docs/manual-processing-guide.md)** - Emergency procedures
- **[Bridge Workflow Guide](docs/ccip-bridge-workflow-guide.md)** - Cross-chain operations
- **[AI Transaction Proofs](docs/bedrock-ai-workflow-transaction-proofs.md)** - Live AI execution examples

---

## 🌐 Live Deployments

### **Ethereum Sepolia**

- **AIStablecoin**: [View on Etherscan](https://sepolia.etherscan.io/address/0xf0072115e6b861682e73a858fBEE36D512960c6f)
- **CollateralVault**: [View on Etherscan](https://sepolia.etherscan.io/address/0x1EeFd496e33ACE44e8918b08bAB9E392b46e1563)
- **RiskOracleController**: [View on Etherscan](https://sepolia.etherscan.io/address/0xB4F6B67C9Cd82bbBB5F97e2f40ebf972600980e4)
- **AutoEmergencyWithdrawal**: [View on Etherscan](https://sepolia.etherscan.io/address/0xE3a872020c0dB6e7c716c39e76A5C98f24cebF92)
- **CCIP Bridge**: [View on Etherscan](https://sepolia.etherscan.io/address/0xB76cD1A5c6d63042D316AabB2f40a5887dD4B1D4)

### **Avalanche Fuji**

- **AIStablecoin**: [View on Snowtrace](https://testnet.snowtrace.io/address/0x26D0f5BD1DAb1c02D1Fc198Fe6ECa2b22Ab276d7)
- **CCIP Bridge**: [View on Snowtrace](https://testnet.snowtrace.io/address/0xd6cE29223350252e3dD632f0bb1438e827da12b6)

### **Cross-Chain Bridge Transactions**

- **Sepolia → Fuji**: [CCIP Explorer](https://ccip.chain.link/msg/0xb8cd99dd68d1a21f180cae3f0564aec71eaf4aa3eccff29a2e9ebf8245896dcb)
- **Fuji → Sepolia**: [CCIP Explorer](https://ccip.chain.link/msg/0xd3a8c09baaa8fb2e06f0c34d1c6d01226dab3546a4d3ffb0965e90505c2a7884)

> **📖 Complete Deployment Status**: See [Project Deployment Status](docs/project-deployment-status.md) for detailed addresses and verification links.

---

## 🧪 Testing & Coverage

### **Test Results**

- **Total Tests**: 142 tests across 10 test suites
- **Pass Rate**: 100% (142/142 tests passing)
- **Coverage**: Comprehensive testing of all Chainlink integrations

### **Key Test Categories**

- ✅ **Chainlink Functions**: AI processing, callbacks, error handling
- ✅ **CCIP Bridge**: Cross-chain transfers, security, fee handling
- ✅ **Data Feeds**: Price validation, staleness checks, fallbacks
- ✅ **Automation**: Upkeep conditions, emergency triggers
- ✅ **Integration**: End-to-end workflows, multi-contract interactions

---

## 🏆 Hackathon Alignment

### **Chromion Hackathon Requirements ✅**

- ✅ **Chainlink State Changes**: Multiple Chainlink services modify blockchain state
- ✅ **Public Repository**: Open-source codebase with comprehensive documentation
- ✅ **Chainlink File References**: Clear documentation of all Chainlink integrations
- ✅ **Architecture Description**: Detailed technical stack and system design
- ✅ **Live Demo**: Deployed contracts with verified transactions

### **Prize Categories**

- **DeFi Innovation**: Revolutionary AI-powered collateral efficiency
- **Cross-Chain**: Chainlink CCIP bridge enabling multi-chain liquidity
- **AI Integration**: First Amazon Bedrock + Chainlink Functions hybrid
- **Technical Excellence**: Comprehensive Chainlink ecosystem utilization

---

## 🎯 Key Benefits

✅ **Enterprise AI**: Amazon Bedrock (Claude 3 Sonnet) for sophisticated analysis  
✅ **Reliable Fallback**: Algorithmic AI ensures system never fails  
✅ **Community Support**: Manual processing helps stuck users  
✅ **Multiple Chainlink Services**: Functions + Data Feeds + CCIP + Automation integration  
✅ **Dynamic Ratios**: Rewards smart diversification with lower collateral requirements  
✅ **Production Ready**: Comprehensive security and recovery mechanisms  
✅ **Cross-Chain Bridge**: Seamless AIUSD transfers between Ethereum and Avalanche via CCIP

This represents the **future of AI-powered DeFi** - where intelligent risk assessment creates more capital-efficient and fair financial protocols while maintaining enterprise-grade reliability! 🚀

---

## ⚠️ **Important Disclaimers**

**🔬 Experimental Technology**: This protocol uses AI for financial decisions. AI models may have biases or make errors. Never invest more than you can afford to lose.

**🏦 Not Financial Advice**: This is experimental DeFi technology for educational and testing purposes. Consult qualified financial advisors before making investment decisions.

**🔒 Security Notice**: While extensively tested, smart contracts may contain bugs. Use at your own risk on testnets only until full security audits are completed.

---

##   Links

- **📂 Repository**: [GitHub Source Code](https://github.com/VitalR/chainlink-ai-stablecoin-protocol)
- **📖 Documentation**: [Complete Technical Docs](docs/)
- **🏆 Hackathon**: [Chromion Chainlink Hackathon 2025](https://chromion-chainlink-hackathon.devfolio.co/)

---

**Built with ❤️ for the Chromion Chainlink Hackathon 2025** | **License**: MIT | **Status**: Testnet Ready
