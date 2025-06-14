#!/bin/bash

echo "🚀 AI Stablecoin Deployment Guide"
echo "================================="
echo ""
echo "This guide shows the proper order for deploying the AI Stablecoin system."
echo "Each script should be run individually to ensure proper setup."
echo ""

echo "📋 Prerequisites:"
echo "- Set up .env file with required variables:"
echo "  - DEPLOYER_PUBLIC_KEY"
echo "  - DEPLOYER_PRIVATE_KEY"
echo "  - SEPOLIA_RPC_URL"
echo "  - ETHERSCAN_API_KEY"
echo "  - GAS_LIMIT"
echo "  - GAS_PRICE"
echo ""

echo "🔄 Deployment Order:"
echo ""

echo "1️⃣  Deploy Test Tokens (if not already deployed)"
echo "source .env && forge script script/00_DeployTestTokens.s.sol:DeployTestTokensScript --rpc-url \$SEPOLIA_RPC_URL --broadcast --private-key \$DEPLOYER_PRIVATE_KEY --etherscan-api-key \$ETHERSCAN_API_KEY --verify -vvvv"
echo ""

echo "2️⃣  Deploy AI Stablecoin (if not already deployed)"
echo "source .env && forge script script/01_DeployStablecoin.s.sol:DeployStablecoinScript --rpc-url \$SEPOLIA_RPC_URL --broadcast --private-key \$DEPLOYER_PRIVATE_KEY --etherscan-api-key \$ETHERSCAN_API_KEY --verify -vvvv"
echo ""

echo "3️⃣  Deploy AI Controller"
echo "⚠️  IMPORTANT: Update ORA_ORACLE_SEPOLIA address in 02_DeployAIController.s.sol"
echo "source .env && forge script script/02_DeployAIController.s.sol:DeployAIControllerScript --rpc-url \$SEPOLIA_RPC_URL --broadcast --private-key \$DEPLOYER_PRIVATE_KEY --etherscan-api-key \$ETHERSCAN_API_KEY --verify -vvvv"
echo ""

echo "4️⃣  Deploy Vault"
echo "⚠️  IMPORTANT: Set AI_CONTROLLER_ADDRESS in .env with address from step 3"
echo "source .env && forge script script/03_DeployVault.s.sol:DeployVaultScript --rpc-url \$SEPOLIA_RPC_URL --broadcast --private-key \$DEPLOYER_PRIVATE_KEY --etherscan-api-key \$ETHERSCAN_API_KEY --verify -vvvv"
echo ""

echo "5️⃣  Setup System Permissions & Tokens"
echo "⚠️  IMPORTANT: Set AI_VAULT_ADDRESS in .env with address from step 4"
echo "source .env && forge script script/04_SetupSystem.s.sol:SetupSystemScript --rpc-url \$SEPOLIA_RPC_URL --broadcast --private-key \$DEPLOYER_PRIVATE_KEY --etherscan-api-key \$ETHERSCAN_API_KEY --gas-limit \$GAS_LIMIT --gas-price \$GAS_PRICE --verify -vvvv"
echo ""

echo "✅ After deployment, update config/SepoliaConfig.sol with new addresses"
echo ""

echo "🧪 Test the system:"
echo "./test/run_tests.sh"
echo ""

echo "📝 Environment Variables Needed:"
echo "# Basic deployment"
echo "DEPLOYER_PUBLIC_KEY=0x..."
echo "DEPLOYER_PRIVATE_KEY=0x..."
echo "SEPOLIA_RPC_URL=https://..."
echo "ETHERSCAN_API_KEY=..."
echo "GAS_LIMIT=3000000"
echo "GAS_PRICE=20000000000"
echo ""
echo "# After step 3"
echo "AI_CONTROLLER_ADDRESS=0x..."
echo ""
echo "# After step 4"
echo "AI_VAULT_ADDRESS=0x..." 



# chmod +x script/deploy_guide.sh