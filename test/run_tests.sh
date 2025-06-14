#!/bin/bash

echo "🧪 Running AI Stablecoin E2E Tests..."
echo "=================================="

# Run the comprehensive test suite
forge test --match-contract AIStablecoinE2E -vvv

echo ""
echo "📊 Test Summary:"
echo "Deposit Flow Tests:"
echo "- Single token deposit flow"
echo "- Diversified basket flow" 
echo "- Fee handling and refunds"
echo "- Error cases and validation"
echo "- Position management"
echo "- Multiple users"

echo "Withdraw Flow Tests:"
echo "- Basic withdraw mechanics"
echo "- Full position withdrawal"
echo "- Diversified basket withdrawals"
echo "- Ratio maintenance"
echo "- Error cases and DeFi approvals"
echo "- Multiple partial withdrawals"

echo ""
echo "✅ Tests completed!" 


############################
# Make script executable
# chmod +x test/run_tests.sh

# Run all E2E tests
#./test/run_tests.sh
############################