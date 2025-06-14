#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Running AIControllerV2 Tests${NC}"
echo "=================================================="

# Check if forge is installed
if ! command -v forge &> /dev/null; then
    echo -e "${RED}ERROR: Forge not found. Please install Foundry first.${NC}"
    exit 1
fi

# Run the V2 system tests
echo -e "${YELLOW}Running Manual Processing Tests...${NC}"

# Test normal ORA callback flow
echo -e "\n${YELLOW}1. Testing Normal ORA Callback Flow${NC}"
forge test --match-test test_normalORACallbackFlow -vv

if [ $? -eq 0 ]; then
    echo -e "${GREEN}PASS: Normal ORA callback flow test passed${NC}"
else
    echo -e "${RED}FAIL: Normal ORA callback flow test failed${NC}"
    exit 1
fi

# Test manual processing request
echo -e "\n${YELLOW}2. Testing Manual Processing Request${NC}"
forge test --match-test test_requestManualProcessing -vv

if [ $? -eq 0 ]; then
    echo -e "${GREEN}PASS: Manual processing request test passed${NC}"
else
    echo -e "${RED}FAIL: Manual processing request test failed${NC}"
    exit 1
fi

# Test off-chain AI processing
echo -e "\n${YELLOW}3. Testing Off-Chain AI Processing${NC}"
forge test --match-test test_processWithOffChainAI -vv

if [ $? -eq 0 ]; then
    echo -e "${GREEN}PASS: Off-chain AI processing test passed${NC}"
else
    echo -e "${RED}FAIL: Off-chain AI processing test failed${NC}"
    exit 1
fi

# Test force default mint
echo -e "\n${YELLOW}4. Testing Force Default Mint${NC}"
forge test --match-test test_forceDefaultMint -vv

if [ $? -eq 0 ]; then
    echo -e "${GREEN}PASS: Force default mint test passed${NC}"
else
    echo -e "${RED}FAIL: Force default mint test failed${NC}"
    exit 1
fi

# Test emergency withdrawal via processor
echo -e "\n${YELLOW}5. Testing Emergency Withdrawal via Processor${NC}"
forge test --match-test test_emergencyWithdrawalViaProcessor -vv

if [ $? -eq 0 ]; then
    echo -e "${GREEN}PASS: Emergency withdrawal via processor test passed${NC}"
else
    echo -e "${RED}FAIL: Emergency withdrawal via processor test failed${NC}"
    exit 1
fi

# Test user emergency withdraw
echo -e "\n${YELLOW}6. Testing User Emergency Withdraw${NC}"
forge test --match-test test_userEmergencyWithdraw -vv

if [ $? -eq 0 ]; then
    echo -e "${GREEN}PASS: User emergency withdraw test passed${NC}"
else
    echo -e "${RED}FAIL: User emergency withdraw test failed${NC}"
    exit 1
fi

# Test vault emergency withdraw
echo -e "\n${YELLOW}7. Testing Vault Emergency Withdraw${NC}"
forge test --match-test test_vaultEmergencyWithdraw -vv

if [ $? -eq 0 ]; then
    echo -e "${GREEN}PASS: Vault emergency withdraw test passed${NC}"
else
    echo -e "${RED}FAIL: Vault emergency withdraw test failed${NC}"
    exit 1
fi

# Test manual processing candidates
echo -e "\n${YELLOW}8. Testing Manual Processing Candidates${NC}"
forge test --match-test test_getManualProcessingCandidates -vv

if [ $? -eq 0 ]; then
    echo -e "${GREEN}PASS: Manual processing candidates test passed${NC}"
else
    echo -e "${RED}FAIL: Manual processing candidates test failed${NC}"
    exit 1
fi

# Test manual processing options
echo -e "\n${YELLOW}9. Testing Manual Processing Options${NC}"
forge test --match-test test_getManualProcessingOptions -vv

if [ $? -eq 0 ]; then
    echo -e "${GREEN}PASS: Manual processing options test passed${NC}"
else
    echo -e "${RED}FAIL: Manual processing options test failed${NC}"
    exit 1
fi

# Test unauthorized access protection
echo -e "\n${YELLOW}10. Testing Unauthorized Access Protection${NC}"
forge test --match-test test_unauthorizedAccessProtection -vv

if [ $? -eq 0 ]; then
    echo -e "${GREEN}PASS: Unauthorized access protection test passed${NC}"
else
    echo -e "${RED}FAIL: Unauthorized access protection test failed${NC}"
    exit 1
fi

# Test circuit breaker functionality
echo -e "\n${YELLOW}11. Testing Circuit Breaker Functionality${NC}"
forge test --match-test test_circuitBreakerFunctionality -vv

if [ $? -eq 0 ]; then
    echo -e "${GREEN}PASS: Circuit breaker functionality test passed${NC}"
else
    echo -e "${RED}FAIL: Circuit breaker functionality test failed${NC}"
    exit 1
fi

# Test AI response parsing
echo -e "\n${YELLOW}12. Testing AI Response Parsing${NC}"
forge test --match-test test_aiResponseParsing -vv

if [ $? -eq 0 ]; then
    echo -e "${GREEN}PASS: AI response parsing test passed${NC}"
else
    echo -e "${RED}FAIL: AI response parsing test failed${NC}"
    exit 1
fi

# Run all tests together for final verification
echo -e "\n${YELLOW}Running All V2 Tests Together${NC}"
forge test --match-contract AIControllerV2Test -vv

if [ $? -eq 0 ]; then
    echo -e "\n${GREEN}SUCCESS: ALL TESTS PASSED!${NC}"
    echo -e "${GREEN}PASS: The improved callback system is ready for deployment${NC}"
    echo -e "${GREEN}PASS: Manual processing functionality works correctly${NC}"
    echo -e "${GREEN}PASS: Emergency withdrawal mechanisms are functional${NC}"
    echo -e "${GREEN}PASS: Security controls are in place${NC}"
else
    echo -e "\n${RED}FAIL: Some tests failed. Please review and fix before deployment.${NC}"
    exit 1
fi

echo -e "\n${YELLOW}Test Summary:${NC}"
echo "- Normal ORA callback flow: PASS"
echo "- Manual processing request: PASS"
echo "- Off-chain AI processing: PASS"
echo "- Force default mint: PASS"
echo "- Emergency withdrawal (processor): PASS"
echo "- Emergency withdrawal (user): PASS"
echo "- Emergency withdrawal (vault): PASS"
echo "- Manual processing candidates: PASS"
echo "- Manual processing options: PASS"
echo "- Unauthorized access protection: PASS"
echo "- Circuit breaker functionality: PASS"
echo "- AI response parsing: PASS"

echo -e "\n${GREEN}Ready for deployment!${NC}" 