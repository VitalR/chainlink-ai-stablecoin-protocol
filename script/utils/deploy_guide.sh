#!/bin/bash

# AI Stablecoin Deployment Guide - Chainlink Functions Edition
# This script provides step-by-step deployment instructions for the AI-powered stablecoin system

set -e

echo "🚀 AI Stablecoin Deployment Guide - Chainlink Functions Edition"
echo "=============================================================="
echo ""

# Check environment
if [ ! -f .env ]; then
    echo "❌ Error: .env file not found"
    echo "Please create .env with required variables:"
    echo "  DEPLOYER_PRIVATE_KEY=your_private_key"
    echo "  DEPLOYER_PUBLIC_KEY=your_public_key"
    echo "  SEPOLIA_RPC_URL=your_sepolia_rpc_url"
    echo "  ETHERSCAN_API_KEY=your_etherscan_api_key"
    exit 1
fi

source .env

echo "✅ Environment loaded"
echo "📍 Deployer: $DEPLOYER_PUBLIC_KEY"
echo ""

echo "📋 PREREQUISITES:"
echo "1. Get testnet LINK tokens from https://faucets.chain.link/sepolia"
echo "2. Create Chainlink Functions subscription at https://functions.chain.link"
echo "3. Update CHAINLINK_SUBSCRIPTION_ID in config/SepoliaConfig.sol"
echo ""

read -p "Have you completed the prerequisites? (y/n): " prerequisites
if [ "$prerequisites" != "y" ]; then
    echo "Please complete prerequisites first!"
    exit 1
fi

echo ""
echo "🔧 DEPLOYMENT SEQUENCE:"
echo "======================="

echo ""
echo "Step 1: Deploy All Tokens"
echo "--------------------------"
read -p "Deploy all tokens (test tokens + RWA)? (y/n): " deploy_tokens
if [ "$deploy_tokens" = "y" ]; then
    forge script script/deploy/00_DeployTokens.s.sol:DeployTokensScript \
        --rpc-url $SEPOLIA_RPC_URL \
        --broadcast \
        --private-key $DEPLOYER_PRIVATE_KEY \
        --etherscan-api-key $ETHERSCAN_API_KEY \
        --verify -vvvv
    echo "✅ All tokens deployed (test + RWA)"
    echo "⚠️  Remember to update SepoliaConfig.sol with deployed addresses!"
fi

echo ""
echo "Step 2: Deploy AI Stablecoin (AIUSD)"
echo "------------------------------------"
read -p "Deploy AIUSD token? (y/n): " deploy_stablecoin
if [ "$deploy_stablecoin" = "y" ]; then
    forge script script/deploy/01_DeployStablecoin.s.sol:DeployStablecoinScript \
        --rpc-url $SEPOLIA_RPC_URL \
        --broadcast \
        --private-key $DEPLOYER_PRIVATE_KEY \
        --etherscan-api-key $ETHERSCAN_API_KEY \
        --verify -vvvv
    echo "✅ AIUSD token deployed"
fi

echo ""
echo "Step 3: Deploy RiskOracleController (Chainlink Functions)"
echo "---------------------------------------------------------"
read -p "Deploy RiskOracleController with Chainlink Functions? (y/n): " deploy_controller
if [ "$deploy_controller" = "y" ]; then
    forge script script/deploy/02_DeployController.s.sol:DeployControllerScript \
        --rpc-url $SEPOLIA_RPC_URL \
        --broadcast \
        --private-key $DEPLOYER_PRIVATE_KEY \
        --etherscan-api-key $ETHERSCAN_API_KEY \
        --verify -vvvv
    echo "✅ RiskOracleController deployed"
    echo "⚠️  Remember to add the controller address as a consumer in your Chainlink Functions subscription!"
fi

echo ""
echo "Step 4: Deploy CollateralVault"
echo "-------------------------------"
read -p "Deploy CollateralVault? (y/n): " deploy_vault
if [ "$deploy_vault" = "y" ]; then
    forge script script/deploy/03_DeployVault.s.sol:DeployVaultScript \
        --rpc-url $SEPOLIA_RPC_URL \
        --broadcast \
        --private-key $DEPLOYER_PRIVATE_KEY \
        --etherscan-api-key $ETHERSCAN_API_KEY \
        --verify -vvvv
    echo "✅ CollateralVault deployed"
fi

echo ""
echo "Step 5: System Setup"
echo "--------------------"
read -p "Run system setup (authorize vault, etc.)? (y/n): " setup_system
if [ "$setup_system" = "y" ]; then
    forge script script/deploy/04_SetupSystem.s.sol:SetupSystemScript \
        --rpc-url $SEPOLIA_RPC_URL \
        --broadcast \
        --private-key $DEPLOYER_PRIVATE_KEY \
        -vvvv
    echo "✅ System setup complete"
fi

echo ""
echo "🎉 DEPLOYMENT COMPLETE!"
echo "======================="
echo ""
echo "🔗 Key Features Deployed:"
echo "• AI-powered risk assessment via Chainlink Functions"
echo "• Real-time price feeds via Chainlink Data Feeds"
echo "• Dynamic collateral ratios (125%-200%)"
echo "• Multi-token collateral support (ETH, WBTC, DAI, OUSG)"
echo "• Real World Assets (RWA) integration with Treasury tokens"
echo "• Decentralized oracle network integration"
echo ""
echo "🧪 Testing:"
echo "Run: forge script script/execute/TestRiskOracleController.s.sol --rpc-url \$SEPOLIA_RPC_URL --broadcast --private-key \$DEPLOYER_PRIVATE_KEY -vvvv"
echo ""
echo "💡 Next Steps:"
echo "1. Update frontend config with deployed addresses"
echo "2. Monitor Chainlink Functions subscription balance"
echo "3. Test different portfolio compositions"
echo "4. Demo the AI risk assessment features"
echo ""
echo "📚 Documentation:"
echo "• Chainlink Functions: chainlink-functions/README.md"
echo "• System Overview: README.md"

# chmod +x script/utils/deploy_guide.sh