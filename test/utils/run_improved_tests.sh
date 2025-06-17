#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Running RiskOracleController Tests${NC}"
echo "=================================================="

# Check if forge is installed
if ! command -v forge &> /dev/null; then
    echo -e "${RED}ERROR: Forge not found. Please install Foundry first.${NC}"
    exit 1
fi

# Run the Chainlink Functions system tests
echo -e "${YELLOW}Running Chainlink Functions Integration Tests...${NC}"

# Test Chainlink Functions fee estimation
echo -e "\n${YELLOW}1. Testing Chainlink Functions Fee Estimation${NC}"
forge test --match-test test_chainlinkFunctionsFeeEstimation -vv

if [ $? -eq 0 ]; then
    echo -e "${GREEN}PASS: Chainlink Functions fee estimation test passed${NC}"
else
    echo -e "${RED}FAIL: Chainlink Functions fee estimation test failed${NC}"
    exit 1
fi

# Test Chainlink Functions request submission
echo -e "\n${YELLOW}2. Testing Chainlink Functions Request Submission${NC}"
forge test --match-test test_submitChainlinkFunctionsRequest -vv

if [ $? -eq 0 ]; then
    echo -e "${GREEN}PASS: Chainlink Functions request submission test passed${NC}"
else
    echo -e "${RED}FAIL: Chainlink Functions request submission test failed${NC}"
    exit 1
fi

# Test Chainlink Functions callback processing
echo -e "\n${YELLOW}3. Testing Chainlink Functions Callback Processing${NC}"
forge test --match-test test_chainlinkFunctionsCallback -vv

if [ $? -eq 0 ]; then
    echo -e "${GREEN}PASS: Chainlink Functions callback processing test passed${NC}"
else
    echo -e "${RED}FAIL: Chainlink Functions callback processing test failed${NC}"
    exit 1
fi

# Test Chainlink Functions callback failure handling
echo -e "\n${YELLOW}4. Testing Chainlink Functions Callback Failure Handling${NC}"
forge test --match-test test_chainlinkFunctionsCallbackFailure -vv

if [ $? -eq 0 ]; then
    echo -e "${GREEN}PASS: Chainlink Functions callback failure handling test passed${NC}"
else
    echo -e "${RED}FAIL: Chainlink Functions callback failure handling test failed${NC}"
    exit 1
fi

# Test manual processing after timeout
echo -e "\n${YELLOW}5. Testing Manual Processing After Timeout${NC}"
forge test --match-test test_manualProcessingAfterTimeout -vv

if [ $? -eq 0 ]; then
    echo -e "${GREEN}PASS: Manual processing after timeout test passed${NC}"
else
    echo -e "${RED}FAIL: Manual processing after timeout test failed${NC}"
    exit 1
fi

# Test emergency withdrawal functionality
echo -e "\n${YELLOW}6. Testing Emergency Withdrawal Functionality${NC}"
forge test --match-test test_emergencyWithdrawal -vv

if [ $? -eq 0 ]; then
    echo -e "${GREEN}PASS: Emergency withdrawal functionality test passed${NC}"
else
    echo -e "${RED}FAIL: Emergency withdrawal functionality test failed${NC}"
    exit 1
fi

# Test force default mint strategy
echo -e "\n${YELLOW}7. Testing Force Default Mint Strategy${NC}"
forge test --match-test test_forceDefaultMint -vv

if [ $? -eq 0 ]; then
    echo -e "${GREEN}PASS: Force default mint strategy test passed${NC}"
else
    echo -e "${RED}FAIL: Force default mint strategy test failed${NC}"
    exit 1
fi

# Test unauthorized access protection
echo -e "\n${YELLOW}8. Testing Unauthorized Access Protection${NC}"
forge test --match-test test_unauthorizedAccess -vv

if [ $? -eq 0 ]; then
    echo -e "${GREEN}PASS: Unauthorized access protection test passed${NC}"
else
    echo -e "${RED}FAIL: Unauthorized access protection test failed${NC}"
    exit 1
fi

# Test circuit breaker functionality
echo -e "\n${YELLOW}9. Testing Circuit Breaker Functionality${NC}"
forge test --match-test test_circuitBreaker -vv

if [ $? -eq 0 ]; then
    echo -e "${GREEN}PASS: Circuit breaker functionality test passed${NC}"
else
    echo -e "${RED}FAIL: Circuit breaker functionality test failed${NC}"
    exit 1
fi

# Test AI response parsing
echo -e "\n${YELLOW}10. Testing AI Response Parsing${NC}"
forge test --match-test test_aiResponseParsing -vv

if [ $? -eq 0 ]; then
    echo -e "${GREEN}PASS: AI response parsing test passed${NC}"
else
    echo -e "${RED}FAIL: AI response parsing test failed${NC}"
    exit 1
fi

# Test system status queries
echo -e "\n${YELLOW}11. Testing System Status Queries${NC}"
forge test --match-test test_systemStatusQueries -vv

if [ $? -eq 0 ]; then
    echo -e "${GREEN}PASS: System status queries test passed${NC}"
else
    echo -e "${RED}FAIL: System status queries test failed${NC}"
    exit 1
fi

# Run all tests together for final verification
echo -e "\n${YELLOW}Running All RiskOracleController Tests Together${NC}"
forge test --match-contract RiskOracleControllerTest -vv

if [ $? -eq 0 ]; then
    echo -e "\n${GREEN}SUCCESS: ALL TESTS PASSED!${NC}"
    echo -e "${GREEN}PASS: The Chainlink Functions integration is ready for deployment${NC}"
    echo -e "${GREEN}PASS: Manual processing functionality works correctly${NC}"
    echo -e "${GREEN}PASS: Emergency withdrawal mechanisms are functional${NC}"
    echo -e "${GREEN}PASS: Security controls are in place${NC}"
else
    echo -e "\n${RED}FAIL: Some tests failed. Please review and fix before deployment.${NC}"
    exit 1
fi

echo -e "\n${YELLOW}Test Summary:${NC}"
echo "- Chainlink Functions fee estimation: PASS"
echo "- Chainlink Functions request submission: PASS"
echo "- Chainlink Functions callback processing: PASS"
echo "- Chainlink Functions callback failure handling: PASS"
echo "- Manual processing after timeout: PASS"
echo "- Emergency withdrawal functionality: PASS"
echo "- Force default mint strategy: PASS"
echo "- Unauthorized access protection: PASS"
echo "- Circuit breaker functionality: PASS"
echo "- AI response parsing: PASS"
echo "- System status queries: PASS"

echo -e "\n${GREEN}Ready for Chainlink Hackathon deployment!${NC}" 