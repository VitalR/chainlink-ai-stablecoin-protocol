# Automation Scripts

This folder contains essential scripts for Chainlink Automation testing and management for the AI Stablecoin emergency withdrawal system.

## 📁 **Script Overview**

### **Core Scripts**

#### `OptIntoAutomation.s.sol`

- **Purpose**: Opt user into automation monitoring
- **Usage**: Must run BEFORE creating positions for automation to work
- **Command**: `forge script script/automation/OptIntoAutomation.s.sol:OptIntoAutomationScript --rpc-url $SEPOLIA_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY --broadcast`

#### `CreateStuckPosition.s.sol`

- **Purpose**: Create a position using TEST_TIMEOUT engine (guaranteed to get stuck)
- **Usage**: For testing automation with a stuck position
- **Command**: `forge script script/automation/CreateStuckPosition.s.sol:CreateStuckPositionScript --rpc-url $SEPOLIA_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY --broadcast`

#### `DiagnoseAutomation.s.sol`

- **Purpose**: Check automation status and position eligibility
- **Usage**: Monitor positions and automation readiness
- **Command**: `forge script script/automation/DiagnoseAutomation.s.sol:DiagnoseAutomationScript --rpc-url $SEPOLIA_RPC_URL`

## 🚀 **Complete Testing Flow**

### **Automatic Testing (Real Chainlink Automation)**

```bash
# 1. Opt into automation
source .env && forge script script/automation/OptIntoAutomation.s.sol:OptIntoAutomationScript --rpc-url $SEPOLIA_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY --broadcast

# 2. Create stuck position
source .env && forge script script/automation/CreateStuckPosition.s.sol:CreateStuckPositionScript --rpc-url $SEPOLIA_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY --broadcast

# 3. Monitor status (run every few minutes)
source .env && forge script script/automation/DiagnoseAutomation.s.sol:DiagnoseAutomationScript --rpc-url $SEPOLIA_RPC_URL

# 4. Wait 5+ minutes for automatic emergency withdrawal by Chainlink
```

### **Manual Testing (Without Automation)**

```bash
# 1. Ensure user is NOT opted into automation (opt out if needed)
source .env && cast send 0xE3a872020c0dB6e7c716c39e76A5C98f24cebF92 "optOutOfAutomation()" --rpc-url $SEPOLIA_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY

# 2. Create stuck position (without automation monitoring)
source .env && forge script script/automation/CreateStuckPosition.s.sol:CreateStuckPositionScript --rpc-url $SEPOLIA_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY --broadcast

# 3. Wait 5+ minutes for emergency delay

# 4. Use manual emergency withdrawal via vault
source .env && cast send 0x1EeFd496e33ACE44e8918b08bAB9E392b46e1563 "emergencyWithdraw(uint256)" [REQUEST_ID] --rpc-url $SEPOLIA_RPC_URL --private-key $DEPLOYER_PRIVATE_KEY
```

## ✅ **Real Test Evidence**

These scripts were used to generate the live proof transactions:

- **Position Creation**: https://sepolia.etherscan.io/tx/0xabe61594c626b0265ec8e87eafacabf13246f916d9af2a4aeab58b102c0c2532
- **Automated Recovery**: https://sepolia.etherscan.io/tx/0x5e2ed6ef751bfbd49cd5365cb72f0c952d5fd16d130d0b7b8c091321944e67ea

## 📋 **Prerequisites**

Before running any scripts:

1. **Environment Variables**: Set in `.env` file

   ```
   DEPLOYER_PUBLIC_KEY=your_wallet_address
   DEPLOYER_PRIVATE_KEY=your_private_key
   SEPOLIA_RPC_URL=your_sepolia_rpc_url
   ```

2. **Test Assets**:

   - Minimum 1 WETH on Sepolia
   - Sepolia ETH for gas

3. **Emergency Delay**:
   - Default: 4 hours (too long for testing)
   - Recommended: 5 minutes (run `UpdateEmergencyDelay.s.sol`)

## 🔧 **Troubleshooting**

### **Common Issues**

1. **"User not opted in"** → Run `OptIntoAutomation.s.sol` first
2. **"Position not eligible"** → Wait full emergency delay period
3. **"No active positions"** → Position was already processed/withdrawn

### **Diagnostic Commands**

```bash
# Check if user is opted in
cast call 0xE3a872020c0dB6e7c716c39e76A5C98f24cebF92 "userOptedIn(address)(bool)" YOUR_ADDRESS --rpc-url $SEPOLIA_RPC_URL

# Check emergency delay
cast call 0x1EeFd496e33ACE44e8918b08bAB9E392b46e1563 "emergencyWithdrawalDelay()(uint256)" --rpc-url $SEPOLIA_RPC_URL

# Monitor vault events
# https://sepolia.etherscan.io/address/0x1EeFd496e33ACE44e8918b08bAB9E392b46e1563#events
```

## 🧪 **Additional Testing**

For comprehensive testing, use the unit test suite:

```bash
# Run all automation tests
forge test --match-contract AutoEmergencyWithdrawalTest -vv

# Specific test scenarios:
# - Basic opt-in/opt-out functionality
# - Automation with no eligible positions
# - Automation with pending positions (not yet eligible)
# - Automation with eligible positions
# - Performing emergency withdrawal automation
# - Multiple users with different eligibility
# - Round-robin checking with many users
# - Admin emergency withdrawal
# - Automation enabled/disabled
# - Error conditions and edge cases
```

---

**🎯 These essential scripts provide focused testing coverage for the Chainlink Automation system with proven real transaction evidence!**
