#!/bin/bash

echo "🧪 Running AI Stablecoin E2E Tests..."
echo "=================================="

# Run the comprehensive test suite
forge test --match-contract AIStablecoinE2E -vvv

echo ""
echo "📊 Test Summary:"
echo "- Single token deposit flow"
echo "- Diversified basket flow" 
echo "- Fee handling and refunds"
echo "- Error cases and validation"
echo "- Position management"
echo "- Multiple users"

echo ""
echo "✅ Tests completed!" 