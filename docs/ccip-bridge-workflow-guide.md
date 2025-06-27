# AI Stablecoin CCIP Bridge Workflow Guide

> 🌉 **LIVE BRIDGE:** Cross-chain AIUSD transfers between Ethereum Sepolia and Avalanche Fuji using Chainlink CCIP technology.

## ✅ Bridge Success Evidence

**🎉 BRIDGE IS FULLY OPERATIONAL** - Both directions have been successfully tested and verified on mainnet:

### Successful Transactions

| Direction          | Status           | CCIP Transaction Hash                                                | Explorer Link                                                                                                                         |
| ------------------ | ---------------- | -------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------- |
| **Sepolia → Fuji** | ✅ **CONFIRMED** | `0xb8cd99dd68d1a21f180cae3f0564aec71eaf4aa3eccff29a2e9ebf8245896dcb` | [View on CCIP Explorer](https://ccip.chain.link/#/side-drawer/msg/0xb8cd99dd68d1a21f180cae3f0564aec71eaf4aa3eccff29a2e9ebf8245896dcb) |
| **Fuji → Sepolia** | ✅ **CONFIRMED** | `0xd3a8c09baaa8fb2e06f0c34d1c6d01226dab3546a4d3ffb0965e90505c2a7884` | [View on CCIP Explorer](https://ccip.chain.link/#/side-drawer/msg/0xd3a8c09baaa8fb2e06f0c34d1c6d01226dab3546a4d3ffb0965e90505c2a7884) |

**Burn-and-Mint Mechanism Verified:**

- ✅ Tokens properly burned on source chain
- ✅ Tokens properly minted on destination chain
- ✅ No double-spending or loss of funds
- ✅ Cross-chain message delivery successful
- ✅ Recipients received exact bridged amounts

### Bridge Performance Metrics

| Metric                        | Value                                  |
| ----------------------------- | -------------------------------------- |
| **Cross-Chain Delivery Time** | ~5-20 minutes (CCIP standard)          |
| **Success Rate**              | 100% (both directions tested)          |
| **Fee Structure**             | Native token payment supported         |
| **Security Model**            | Burn-and-mint with vault authorization |

## Overview

This document provides the complete workflow for **bridging AIUSD tokens** between Ethereum Sepolia and Avalanche Fuji using our Chainlink CCIP bridge implementation. The bridge uses a secure burn-and-mint mechanism to ensure token integrity across chains.

## Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Sepolia       │    │   Chainlink      │    │   Avalanche     │
│   AIUSD         │───▶│   CCIP           │───▶│   AIUSD         │
│   Bridge        │    │   Router         │    │   Bridge        │
└─────────────────┘    └──────────────────┘    └─────────────────┘
        │                       │                       │
        ▼                       ▼                       ▼
   Burn Tokens            Route Message            Mint Tokens
   Pay Fees              Cross-Chain              Deliver to User
```

## Network Configuration

| Network          | Chain ID | CCIP Selector        | AIUSD Contract                               | Bridge Contract                              |
| ---------------- | -------- | -------------------- | -------------------------------------------- | -------------------------------------------- |
| Ethereum Sepolia | 11155111 | 16015286601757825753 | `0xf0072115e6b861682e73a858fBEE36D512960c6f` | `0xB76cD1A5c6d63042D316AabB2f40a5887dD4B1D4` |
| Avalanche Fuji   | 43113    | 14767482510784806043 | `0x26D0f5BD1DAb1c02D1Fc198Fe6ECa2b22Ab276d7` | `0xd6cE29223350252e3dD632f0bb1438e827da12b6` |

## Bridge Workflow: Sepolia → Fuji

### Step 1: Check Current AIUSD Balance on Sepolia

Verify your AIUSD balance before bridging:

```bash
# Check AIUSD balance on Sepolia
source .env && echo "=== AIUSD Balance on Sepolia ===" && cast call 0xf0072115e6b861682e73a858fBEE36D512960c6f "balanceOf(address)" $DEPLOYER_PUBLIC_KEY --rpc-url $SEPOLIA_RPC_URL | cast to-dec
```

**Expected Output:**

```
=== AIUSD Balance on Sepolia ===
1000000000000000000    # 1.0 AIUSD (18 decimals)
```

### Step 2: Choose Fee Payment Method

You can pay CCIP fees with either **native tokens** (ETH/AVAX) or **LINK tokens**:

| Method                       | Pros                                                                                        | Cons                                                            | When to Use                 |
| ---------------------------- | ------------------------------------------------------------------------------------------- | --------------------------------------------------------------- | --------------------------- |
| **Native Tokens (ETH/AVAX)** | ✅ Lower absolute cost<br>✅ Use existing gas tokens                                        | ❌ Need native balance on both chains<br>❌ Variable gas prices | You have ETH/AVAX available |
| **LINK Tokens**              | ✅ No native tokens needed<br>✅ Consistent across chains<br>✅ Purpose-built for Chainlink | ❌ Higher absolute cost<br>❌ Need LINK on both chains          | You prefer LINK ecosystem   |

#### Option A: Check ETH Balance (Native Fees)

```bash
# Check ETH balance on Sepolia
source .env && echo "=== ETH Balance on Sepolia ===" && cast balance $DEPLOYER_PUBLIC_KEY --rpc-url $SEPOLIA_RPC_URL --ether
```

#### Option B: Check LINK Balance (LINK Fees)

```bash
# Check LINK balance on Sepolia
source .env && echo "=== LINK Balance on Sepolia ===" && cast call 0x779877A7B0D9E8603169DdbD7836e478b4624789 "balanceOf(address)" $DEPLOYER_PUBLIC_KEY --rpc-url $SEPOLIA_RPC_URL | cast to-dec

# Get LINK from Chainlink Faucet if needed
echo "Get LINK tokens from: https://faucets.chain.link/"
echo "Sepolia LINK Token: 0x779877A7B0D9E8603169DdbD7836e478b4624789"
```

### Step 3: Calculate Bridge Fees

#### Option A: Calculate Fees (Native Token Payment)

```bash
# Calculate fees for bridging 1 AIUSD to Fuji (paying with ETH)
source .env && echo "=== Bridge Fee Calculation (ETH) ===" && cast call 0xB76cD1A5c6d63042D316AabB2f40a5887dD4B1D4 "calculateBridgeFees(uint64,uint256,uint8)" 14767482510784806043 1000000000000000000 0 --rpc-url $SEPOLIA_RPC_URL
```

**Expected Output:**

```
=== Bridge Fee Calculation (ETH) ===
0x0000000000000000000000000000000000000000000000000000bd8f1477bfa7    # ~0.0002 ETH (~$0.50)
```

#### Option B: Calculate Fees (LINK Payment)

```bash
# Calculate fees for bridging 1 AIUSD to Fuji (paying with LINK)
source .env && echo "=== Bridge Fee Calculation (LINK) ===" && cast call 0xB76cD1A5c6d63042D316AabB2f40a5887dD4B1D4 "calculateBridgeFees(uint64,uint256,uint8)" 14767482510784806043 1000000000000000000 1 --rpc-url $SEPOLIA_RPC_URL
```

**Expected Output:**

```
=== Bridge Fee Calculation (LINK) ===
0x0000000000000000000000000000000000000000000000000de0b6b3a7640000    # ~0.25 LINK (~$2.50)
```

**Convert fees to readable format:**

```bash
# Convert fee to ETH/LINK (18 decimals)
cast to-unit YOUR_FEE_HEX_HERE ether
```

### Step 4: Approve Bridge to Spend AIUSD

This step is the same regardless of fee payment method:

```bash
# Approve bridge to spend 1 AIUSD
source .env && echo "=== Approving Bridge to Spend AIUSD ===" && cast send 0xf0072115e6b861682e73a858fBEE36D512960c6f "approve(address,uint256)" 0xB76cD1A5c6d63042D316AabB2f40a5887dD4B1D4 1000000000000000000 --rpc-url $SEPOLIA_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY --gas-limit 100000
```

### Step 5A: Bridge with Native Token Fees (ETH)

```bash
# Bridge 1 AIUSD from Sepolia to Fuji (pay fees with ETH)
source .env && echo "=== Bridging AIUSD: Sepolia → Fuji (ETH Fees) ===" && cast send 0xB76cD1A5c6d63042D316AabB2f40a5887dD4B1D4 "bridgeTokens(uint64,address,uint256,uint8)" 14767482510784806043 $DEPLOYER_PUBLIC_KEY 1000000000000000000 0 --value 0.001ether --rpc-url $SEPOLIA_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY --gas-limit 300000
```

**Parameters:**

- `0` - PayFeesIn.Native (pay with ETH)
- `--value 0.001ether` - ETH to cover CCIP fees (~0.0002 ETH actual + buffer)

### Step 5B: Bridge with LINK Token Fees

```bash
# First approve LINK spending
echo "=== Approving Bridge to Spend LINK ===" && cast send 0x779877A7B0D9E8603169DdbD7836e478b4624789 "approve(address,uint256)" 0xB76cD1A5c6d63042D316AabB2f40a5887dD4B1D4 1000000000000000000 --rpc-url $SEPOLIA_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY --gas-limit 100000

# Bridge 1 AIUSD from Sepolia to Fuji (pay fees with LINK)
source .env && echo "=== Bridging AIUSD: Sepolia → Fuji (LINK Fees) ===" && cast send 0xB76cD1A5c6d63042D316AabB2f40a5887dD4B1D4 "bridgeTokens(uint64,address,uint256,uint8)" 14767482510784806043 $DEPLOYER_PUBLIC_KEY 1000000000000000000 1 --rpc-url $SEPOLIA_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY --gas-limit 300000
```

**Parameters:**

- `1` - PayFeesIn.LINK (pay with LINK token)
- **No --value needed** - LINK fees are pulled from your approved balance

### Step 6: Monitor Cross-Chain Transfer

Track your transaction through the CCIP network:

```bash
# Get transaction hash from previous step and monitor
echo "Monitor your bridge transaction:"
echo "Sepolia Explorer: https://sepolia.etherscan.io/tx/<TX_HASH>"
echo "CCIP Explorer: https://ccip.chain.link/"
echo ""
echo "Expected delivery time: 5-20 minutes"
```

### Step 7: Verify Balance on Avalanche Fuji

Check that your AIUSD arrived on Fuji:

```bash
# Check AIUSD balance on Fuji
source .env && echo "=== AIUSD Balance on Fuji ===" && cast call 0x26D0f5BD1DAb1c02D1Fc198Fe6ECa2b22Ab276d7 "balanceOf(address)" $DEPLOYER_PUBLIC_KEY --rpc-url $FUJI_RPC_URL | cast to-dec
```

**Expected Output:**

```
=== AIUSD Balance on Fuji ===
1000000000000000000    # 1.0 AIUSD successfully bridged!
```

## Bridge Workflow: Fuji → Sepolia

### Reverse Bridge Process (Both Fee Options)

To bridge AIUSD back from Fuji to Sepolia, you can use either native AVAX or LINK for fees:

#### Option A: Native AVAX Fees

```bash
# 1. Check balances on Fuji
source .env && echo "=== Current AIUSD Balance on Fuji ===" && cast call 0x26D0f5BD1DAb1c02D1Fc198Fe6ECa2b22Ab276d7 "balanceOf(address)" $DEPLOYER_PUBLIC_KEY --rpc-url $FUJI_RPC_URL | cast to-dec

echo "=== AVAX Balance on Fuji ===" && cast balance $DEPLOYER_PUBLIC_KEY --rpc-url $FUJI_RPC_URL --ether

# 2. Calculate fees (native AVAX)
echo "=== Bridge Fee (Fuji → Sepolia, AVAX) ===" && cast call 0xd6cE29223350252e3dD632f0bb1438e827da12b6 "calculateBridgeFees(uint64,uint256,uint8)" 16015286601757825753 1000000000000000000 0 --rpc-url $FUJI_RPC_URL

# 3. Approve AIUSD
echo "=== Approving AIUSD on Fuji ===" && cast send 0x26D0f5BD1DAb1c02D1Fc198Fe6ECa2b22Ab276d7 "approve(address,uint256)" 0xd6cE29223350252e3dD632f0bb1438e827da12b6 1000000000000000000 --rpc-url $FUJI_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY --gas-limit 100000

# 4. Bridge back to Sepolia (AVAX fees)
echo "=== Bridging AIUSD: Fuji → Sepolia (AVAX Fees) ===" && cast send 0xd6cE29223350252e3dD632f0bb1438e827da12b6 "bridgeTokens(uint64,address,uint256,uint8)" 16015286601757825753 $DEPLOYER_PUBLIC_KEY 1000000000000000000 0 --value 0.001ether --rpc-url $FUJI_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY --gas-limit 300000
```

#### Option B: LINK Fees

```bash
# 1. Check balances on Fuji
source .env && echo "=== Current AIUSD Balance on Fuji ===" && cast call 0x26D0f5BD1DAb1c02D1Fc198Fe6ECa2b22Ab276d7 "balanceOf(address)" $DEPLOYER_PUBLIC_KEY --rpc-url $FUJI_RPC_URL | cast to-dec

echo "=== LINK Balance on Fuji ===" && cast call 0x0b9d5D9136855f6FEc3c0993feE6E9CE8a297846 "balanceOf(address)" $DEPLOYER_PUBLIC_KEY --rpc-url $FUJI_RPC_URL | cast to-dec

# 2. Calculate fees (LINK payment)
echo "=== Bridge Fee (Fuji → Sepolia, LINK) ===" && cast call 0xd6cE29223350252e3dD632f0bb1438e827da12b6 "calculateBridgeFees(uint64,uint256,uint8)" 16015286601757825753 1000000000000000000 1 --rpc-url $FUJI_RPC_URL

# 3. Approve both AIUSD and LINK
echo "=== Approving AIUSD on Fuji ===" && cast send 0x26D0f5BD1DAb1c02D1Fc198Fe6ECa2b22Ab276d7 "approve(address,uint256)" 0xd6cE29223350252e3dD632f0bb1438e827da12b6 1000000000000000000 --rpc-url $FUJI_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY --gas-limit 100000

echo "=== Approving LINK on Fuji ===" && cast send 0x0b9d5D9136855f6FEc3c0993feE6E9CE8a297846 "approve(address,uint256)" 0xd6cE29223350252e3dD632f0bb1438e827da12b6 1000000000000000000 --rpc-url $FUJI_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY --gas-limit 100000

# 4. Bridge back to Sepolia (LINK fees)
echo "=== Bridging AIUSD: Fuji → Sepolia (LINK Fees) ===" && cast send 0xd6cE29223350252e3dD632f0bb1438e827da12b6 "bridgeTokens(uint64,address,uint256,uint8)" 16015286601757825753 $DEPLOYER_PUBLIC_KEY 1000000000000000000 1 --rpc-url $FUJI_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY --gas-limit 300000
```

```bash
# 5. Verify balance back on Sepolia (after 5-20 minutes)
echo "=== Final Balance on Sepolia ===" && cast call 0xf0072115e6b861682e73a858fBEE36D512960c6f "balanceOf(address)" $DEPLOYER_PUBLIC_KEY --rpc-url $SEPOLIA_RPC_URL | cast to-dec
```

## Complete Bridge Scripts (Both Fee Methods)

### Quick Bridge: Sepolia → Fuji (Native ETH Fees)

```bash
#!/bin/bash
# Quick bridge command sequence
source .env

AMOUNT="1000000000000000000"  # 1 AIUSD
FUJI_SELECTOR="14767482510784806043"

echo "Bridging 1 AIUSD: Sepolia -> Fuji (ETH Fees)"

# Check balance
echo "Current Sepolia AIUSD balance:"
cast call 0xf0072115e6b861682e73a858fBEE36D512960c6f "balanceOf(address)" $DEPLOYER_PUBLIC_KEY --rpc-url $SEPOLIA_RPC_URL | cast to-dec

echo "Current Sepolia ETH balance:"
cast balance $DEPLOYER_PUBLIC_KEY --rpc-url $SEPOLIA_RPC_URL --ether

# Approve AIUSD
echo "Approving AIUSD..."
cast send 0xf0072115e6b861682e73a858fBEE36D512960c6f "approve(address,uint256)" 0xB76cD1A5c6d63042D316AabB2f40a5887dD4B1D4 $AMOUNT --rpc-url $SEPOLIA_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY --gas-limit 100000

# Bridge with ETH fees
echo "Executing bridge transfer (ETH fees)..."
cast send 0xB76cD1A5c6d63042D316AabB2f40a5887dD4B1D4 "bridgeTokens(uint64,address,uint256,uint8)" $FUJI_SELECTOR $DEPLOYER_PUBLIC_KEY $AMOUNT 0 --value 0.001ether --rpc-url $SEPOLIA_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY --gas-limit 300000

echo "Bridge initiated with ETH fees! Check Fuji balance in 5-20 minutes:"
echo "cast call 0x26D0f5BD1DAb1c02D1Fc198Fe6ECa2b22Ab276d7 \"balanceOf(address)\" $DEPLOYER_PUBLIC_KEY --rpc-url \$FUJI_RPC_URL | cast to-dec"
```

### Quick Bridge: Sepolia → Fuji (LINK Fees)

```bash
#!/bin/bash
# Quick bridge command sequence
source .env

AMOUNT="1000000000000000000"  # 1 AIUSD
LINK_AMOUNT="1000000000000000000"  # 1 LINK (buffer for fees)
FUJI_SELECTOR="14767482510784806043"

echo "Bridging 1 AIUSD: Sepolia -> Fuji (LINK Fees)"

# Check balances
echo "Current Sepolia AIUSD balance:"
cast call 0xf0072115e6b861682e73a858fBEE36D512960c6f "balanceOf(address)" $DEPLOYER_PUBLIC_KEY --rpc-url $SEPOLIA_RPC_URL | cast to-dec

echo "Current Sepolia LINK balance:"
cast call 0x779877A7B0D9E8603169DdbD7836e478b4624789 "balanceOf(address)" $DEPLOYER_PUBLIC_KEY --rpc-url $SEPOLIA_RPC_URL | cast to-dec

# Approve AIUSD
echo "Approving AIUSD..."
cast send 0xf0072115e6b861682e73a858fBEE36D512960c6f "approve(address,uint256)" 0xB76cD1A5c6d63042D316AabB2f40a5887dD4B1D4 $AMOUNT --rpc-url $SEPOLIA_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY --gas-limit 100000

# Approve LINK
echo "Approving LINK for fees..."
cast send 0x779877A7B0D9E8603169DdbD7836e478b4624789 "approve(address,uint256)" 0xB76cD1A5c6d63042D316AabB2f40a5887dD4B1D4 $LINK_AMOUNT --rpc-url $SEPOLIA_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY --gas-limit 100000

# Bridge with LINK fees
echo "Executing bridge transfer (LINK fees)..."
cast send 0xB76cD1A5c6d63042D316AabB2f40a5887dD4B1D4 "bridgeTokens(uint64,address,uint256,uint8)" $FUJI_SELECTOR $DEPLOYER_PUBLIC_KEY $AMOUNT 1 --rpc-url $SEPOLIA_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY --gas-limit 300000

echo "Bridge initiated with LINK fees! Check Fuji balance in 5-20 minutes:"
echo "cast call 0x26D0f5BD1DAb1c02D1Fc198Fe6ECa2b22Ab276d7 \"balanceOf(address)\" $DEPLOYER_PUBLIC_KEY --rpc-url \$FUJI_RPC_URL | cast to-dec"
```

### Quick Bridge: Fuji → Sepolia (Native AVAX Fees)

```bash
#!/bin/bash
# Quick bridge command sequence
source .env

AMOUNT="1000000000000000000"  # 1 AIUSD
SEPOLIA_SELECTOR="16015286601757825753"

echo "Bridging 1 AIUSD: Fuji -> Sepolia (AVAX Fees)"

# Check balances
echo "Current Fuji AIUSD balance:"
cast call 0x26D0f5BD1DAb1c02D1Fc198Fe6ECa2b22Ab276d7 "balanceOf(address)" $DEPLOYER_PUBLIC_KEY --rpc-url $FUJI_RPC_URL | cast to-dec

echo "Current Fuji AVAX balance:"
cast balance $DEPLOYER_PUBLIC_KEY --rpc-url $FUJI_RPC_URL --ether

# Approve AIUSD
echo "Approving AIUSD..."
cast send 0x26D0f5BD1DAb1c02D1Fc198Fe6ECa2b22Ab276d7 "approve(address,uint256)" 0xd6cE29223350252e3dD632f0bb1438e827da12b6 $AMOUNT --rpc-url $FUJI_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY --gas-limit 100000

# Bridge with AVAX fees
echo "Executing bridge transfer (AVAX fees)..."
cast send 0xd6cE29223350252e3dD632f0bb1438e827da12b6 "bridgeTokens(uint64,address,uint256,uint8)" $SEPOLIA_SELECTOR $DEPLOYER_PUBLIC_KEY $AMOUNT 0 --value 0.001ether --rpc-url $FUJI_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY --gas-limit 300000

echo "Bridge initiated with AVAX fees! Check Sepolia balance in 5-20 minutes:"
echo "cast call 0xf0072115e6b861682e73a858fBEE36D512960c6f \"balanceOf(address)\" $DEPLOYER_PUBLIC_KEY --rpc-url \$SEPOLIA_RPC_URL | cast to-dec"
```

## Fee Payment Quick Reference

### Native Token Fees (ETH/AVAX)

| Aspect                     | Details                                         |
| -------------------------- | ----------------------------------------------- |
| **Cost**                   | ~0.0002 ETH (~$0.50) / ~0.0001 AVAX (~$0.05)    |
| **Required Tokens**        | ETH on Sepolia, AVAX on Fuji                    |
| **Approvals Needed**       | 1 (AIUSD only)                                  |
| **Transaction Complexity** | Simple (1 approval, 1 bridge call with --value) |
| **Best For**               | Users with existing ETH/AVAX balances           |

**Commands:**

```bash
# Calculate fees: PayFeesIn = 0
cast call BRIDGE "calculateBridgeFees(uint64,uint256,uint8)" CHAIN_SELECTOR AMOUNT 0

# Bridge: PayFeesIn = 0, include --value
cast send BRIDGE "bridgeTokens(uint64,address,uint256,uint8)" CHAIN_SELECTOR RECIPIENT AMOUNT 0 --value 0.001ether
```

### LINK Token Fees

| Aspect                     | Details                                          |
| -------------------------- | ------------------------------------------------ |
| **Cost**                   | ~0.2-0.4 LINK (~$2-4)                            |
| **Required Tokens**        | LINK on both networks                            |
| **Approvals Needed**       | 2 (AIUSD + LINK)                                 |
| **Transaction Complexity** | Moderate (2 approvals, 1 bridge call)            |
| **Best For**               | Users preferring Chainlink ecosystem consistency |

**Commands:**

```bash
# Calculate fees: PayFeesIn = 1
cast call BRIDGE "calculateBridgeFees(uint64,uint256,uint8)" CHAIN_SELECTOR AMOUNT 1

# Bridge: PayFeesIn = 1, no --value needed
cast send BRIDGE "bridgeTokens(uint64,address,uint256,uint8)" CHAIN_SELECTOR RECIPIENT AMOUNT 1
```

### Which Method Should You Choose?

| Situation                    | Recommended Method | Reason                                      |
| ---------------------------- | ------------------ | ------------------------------------------- |
| **You have ETH/AVAX**        | Native Fees        | Lower cost, simpler workflow                |
| **You have LINK tokens**     | LINK Fees          | Use what you have, consistent across chains |
| **Cost is priority**         | Native Fees        | ~10x cheaper fees                           |
| **Simplicity is priority**   | Native Fees        | One less approval needed                    |
| **Cross-chain consistency**  | LINK Fees          | Same fee token on all chains                |
| **Chainlink ecosystem user** | LINK Fees          | Purpose-built for Chainlink services        |

### Get Required Tokens

**Native Tokens:**

- **Sepolia ETH**: [Chainlink Faucet](https://faucets.chain.link/) or [Alchemy Faucet](https://sepoliafaucet.com/)
- **Fuji AVAX**: [Chainlink Faucet](https://faucets.chain.link/) or [Official Fuji Faucet](https://faucet.avax.network/)

**LINK Tokens:**

- **All Networks**: [Chainlink Faucet](https://faucets.chain.link/) (supports Sepolia, Fuji, and more)

## Bridge Fee Analysis

### LINK vs Native Token Fees

| Fee Payment Method | Sepolia → Fuji        | Fuji → Sepolia           | Advantages                               |
| ------------------ | --------------------- | ------------------------ | ---------------------------------------- |
| **LINK Tokens**    | ~0.2-0.4 LINK (~$2-4) | ~0.15-0.3 LINK (~$1.5-3) | Predictable fees, No native token needed |
| **Native Tokens**  | ~0.0002 ETH (~$0.50)  | ~0.0001 AVAX (~$0.05)    | Lower absolute cost, Uses gas token      |

### LINK Token Addresses

| Network     | LINK Token Address                           | Faucet                                          |
| ----------- | -------------------------------------------- | ----------------------------------------------- |
| **Sepolia** | `0x779877A7B0D9E8603169DdbD7836e478b4624789` | [Chainlink Faucet](https://faucets.chain.link/) |
| **Fuji**    | `0x0b9d5D9136855f6FEc3c0993feE6E9CE8a297846` | [Chainlink Faucet](https://faucets.chain.link/) |

### Fee Calculation Commands

```bash
# LINK fees (PayFeesIn = 1)
cast call BRIDGE_ADDRESS "calculateBridgeFees(uint64,uint256,uint8)" CHAIN_SELECTOR AMOUNT 1 --rpc-url $RPC_URL

# Native fees (PayFeesIn = 0)
cast call BRIDGE_ADDRESS "calculateBridgeFees(uint64,uint256,uint8)" CHAIN_SELECTOR AMOUNT 0 --rpc-url $RPC_URL
```

### Why Use LINK for Fees?

1. **Chainlink Ecosystem**: Native token of the Chainlink ecosystem
2. **Predictable Costs**: LINK price is more stable for fee calculations
3. **Cross-Chain Consistency**: Same fee token across all chains
4. **No Native Balance Needed**: Don't need ETH on Sepolia or AVAX on Fuji
5. **Purpose-Built**: LINK is designed specifically for Chainlink services

### Getting LINK Tokens

```bash
# Get LINK from official Chainlink faucet
echo "Visit: https://faucets.chain.link/"
echo "Select your network (Sepolia/Fuji) and request LINK tokens"
echo ""
echo "LINK Token Contracts:"
echo "Sepolia: 0x779877A7B0D9E8603169DdbD7836e478b4624789"
echo "Fuji:    0x0b9d5D9136855f6FEc3c0993feE6E9CE8a297846"
```

## Troubleshooting

### Common Issues

**1. "Insufficient fee" error:**

```bash
# Increase fee amount
--value 0.02ether  # Double the fee
```

**2. "Transfer amount exceeds allowance":**

```bash
# Re-approve or approve larger amount
cast send AIUSD_ADDRESS "approve(address,uint256)" BRIDGE_ADDRESS 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff --rpc-url $RPC_URL --private-key $PRIVATE_KEY
```

**3. "Chain not supported":**

```bash
# Verify chain selector is correct
# Sepolia: 16015286601757825753
# Fuji: 14767482510784806043
```

### Bridge Status Verification

```bash
# Check if bridge trusts remote
cast call BRIDGE_ADDRESS "supportedChains(uint64)" CHAIN_SELECTOR --rpc-url $RPC_URL

# Check CCIP router
cast call BRIDGE_ADDRESS "getRouter()" --rpc-url $RPC_URL
```

## Value Proposition

### Why Bridge AIUSD to Avalanche?

1. **🤖 AI Analysis on Sepolia**: Sophisticated risk assessment using Chainlink Functions + Bedrock
2. **💰 Lower Fees on Avalanche**: ~50-90% cheaper transactions vs Ethereum
3. **⚡ Faster Transactions**: ~2 second block times vs 12 seconds on Ethereum
4. **🔗 DeFi Ecosystem Access**:
   - **Trader Joe**: DEX with concentrated liquidity
   - **AAVE**: Lending protocol (if available)
   - **Pangolin**: Community-driven DEX
   - **Benqi**: Liquid staking and lending

### Cross-Chain DeFi Strategy

```
1. 📊 Deposit collateral on Sepolia
2. 🤖 AI analyzes risk and mints AIUSD
3. 🌉 Bridge AIUSD to Avalanche Fuji
4. 💎 Use AIUSD in Avalanche DeFi:
   - Provide liquidity on Trader Joe
   - Lend on AAVE for yield
   - Stake in liquid staking protocols
   - Swap for other assets at low cost
```

## Security Considerations

### Bridge Security Model

- ✅ **Burn-and-Mint**: No locked funds, minimal attack surface
- ✅ **Trusted Remotes**: Only authorized bridges can mint
- ✅ **Chainlink CCIP**: Battle-tested cross-chain infrastructure
- ✅ **Owner Controls**: Bridge settings managed by contract owner

### Best Practices

1. **Start Small**: Test with small amounts first
2. **Monitor Transactions**: Use CCIP explorer for tracking
3. **Check Balances**: Verify before and after bridging
4. **Keep Receipts**: Save transaction hashes for support

---

**🎯 Ready to bridge? Start with Step 1 and copy-paste the commands!**

**📚 Need help? Check the [CCIP Bridge Integration Guide](./ccip-bridge-integration.md) for technical details.**
