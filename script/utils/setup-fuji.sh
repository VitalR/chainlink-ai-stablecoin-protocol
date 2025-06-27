#!/bin/bash

# AI Stablecoin - Avalanche Fuji Setup Script
# This script helps configure environment variables for Fuji deployment

echo "🏔️  AI Stablecoin - Avalanche Fuji Setup"
echo "========================================"

# Check if .env file exists
if [ ! -f .env ]; then
    echo "Creating .env file..."
    touch .env
fi

echo ""
echo "📋 Required Environment Variables for Fuji:"
echo ""

# Fuji RPC URL
echo "1. FUJI_RPC_URL (Avalanche Fuji RPC endpoint)"
echo "   Recommended: https://api.avax-test.network/ext/bc/C/rpc"
echo "   Or use a service like Infura/Alchemy"
echo ""

# Private Key
echo "2. DEPLOYER_PRIVATE_KEY (Your deployment wallet private key)"
echo "   ⚠️  Make sure this wallet has AVAX for gas fees"
echo "   Get testnet AVAX from faucets below ⬇️"
echo ""

# Testnet AVAX Faucet Options
echo "💧 Testnet AVAX Faucet Options:"
echo ""
echo "   Primary Faucets (Recommended):"
echo "   • Chainlink Faucets: https://faucets.chain.link/"
echo "     (Provides both AVAX and LINK, no mainnet balance required)"
echo "   • Alchemy Faucet: https://www.alchemy.com/faucets/avalanche-fuji"
echo "     (Free with account, higher limits)"
echo "   • QuickNode Faucet: https://faucet.quicknode.com/avalanche/fuji"
echo ""
echo "   Alternative Options:"
echo "   • Official Avalanche: https://faucet.avax.network/"
echo "   • Core Faucet: https://core.app/tools/testnet-faucet/ (requires mainnet AVAX)"
echo "   • POW Faucet: https://faucet.avax.network/ (solve captchas)"
echo ""
echo "   Community Help:"
echo "   • Avalanche Discord: https://discord.gg/avalanche (ask in dev channels)"
echo "   • Chainlink Discord: https://discord.gg/chainlink"
echo ""
echo "   💡 Tip: If core.app requires mainnet AVAX, buy $1-2 worth on any exchange"
echo "        and send to your wallet to satisfy the requirement."
echo ""

# Existing addresses from Sepolia (if deploying bridge)
echo "3. AI_STABLECOIN_ADDRESS (From Sepolia deployment)"
echo "   Current Sepolia address: 0xf0072115e6b861682e73a858fBEE36D512960c6f"
echo ""

echo "4. AI_STABLECOIN_BRIDGE_Ethereum_Sepolia_ADDRESS (If already deployed)"
echo "   This will be set after running 07_DeployCCIPBridge.s.sol on Sepolia"
echo ""

# Network verification
echo "📊 Network Information:"
echo "Chain ID: 43113 (Avalanche Fuji)"
echo "Currency: AVAX"
echo "Block Explorer: https://testnet.snowtrace.io/"
echo "CCIP Router: 0xF694E193200268f9a4868e4Aa017A0118C9a8177"
echo "LINK Token: 0x0b9d5D9136855f6FEc3c0993feE6E9CE8a297846"
echo ""

# Deployment commands
echo "🚀 Deployment Commands:"
echo ""
echo "1. Deploy full system to Fuji:"
echo "   forge script script/deploy/08_DeployToFuji.s.sol:DeployToFujiScript \\"
echo "     --rpc-url \$FUJI_RPC_URL \\"
echo "     --broadcast \\"
echo "     --verify"
echo ""

echo "2. Deploy just the CCIP bridge (if AI Stablecoin already exists):"
echo "   forge script script/deploy/07_DeployCCIPBridge.s.sol:DeployCCIPBridgeScript \\"
echo "     --rpc-url \$FUJI_RPC_URL \\"
echo "     --broadcast \\"
echo "     --verify"
echo ""

echo "3. Configure bridge connections:"
echo "   forge script script/crosschain/SetupCCIPBridge.s.sol:SetupCCIPBridgeScript \\"
echo "     --rpc-url \$FUJI_RPC_URL \\"
echo "     --broadcast"
echo ""

# Verification
echo "🔍 Verification:"
echo "After deployment, verify contracts on SnowTrace:"
echo "https://testnet.snowtrace.io/"
echo ""

# Testing
echo "🧪 Testing Bridge:"
echo "1. Mint some AIUSD on Sepolia"
echo "2. Approve Sepolia bridge to spend AIUSD"
echo "3. Call bridgeTokens() to send to Fuji"
echo "4. Check balance on Fuji after ~5-10 minutes"
echo ""

# Useful links
echo "🔗 Useful Links:"
echo "Multiple Faucet Options:"
echo "  • Chainlink Faucets: https://faucets.chain.link/ (BEST OPTION)"
echo "  • Alchemy Faucet: https://www.alchemy.com/faucets/avalanche-fuji"
echo "  • QuickNode Faucet: https://faucet.quicknode.com/avalanche/fuji"
echo "  • Official Avalanche: https://faucet.avax.network/"
echo "Block Explorers & Tools:"
echo "  • Fuji Block Explorer: https://testnet.snowtrace.io/"
echo "  • Chainlink CCIP Explorer: https://ccip.chain.link/"
echo "Documentation:"
echo "  • Avalanche Documentation: https://docs.avax.network/"
echo "Community Support:"
echo "  • Avalanche Discord: https://discord.gg/avalanche"
echo "  • Chainlink Discord: https://discord.gg/chainlink"
echo ""

echo "✅ Setup complete! Make sure to:"
echo "1. Add required environment variables to .env"
echo "2. Get testnet AVAX from the faucet"
echo "3. Run the deployment scripts"
echo ""

# Check if forge is installed
if ! command -v forge &> /dev/null; then
    echo "❌ Foundry not found. Install it from: https://getfoundry.sh/"
    exit 1
fi

echo "🛠️  Foundry detected. Ready to deploy!" 