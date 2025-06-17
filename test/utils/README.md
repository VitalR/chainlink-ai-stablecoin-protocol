# Test Utilities

This directory contains test scripts and utilities for the AI Stablecoin project.

## Test Scripts

### `run_tests.sh`

Runs the comprehensive End-to-End (E2E) test suite that covers the complete user journey:

**Features Tested:**

- **Deposit Flow**: Single token deposits, diversified baskets, fee handling, error cases
- **Withdraw Flow**: Partial/full withdrawals, ratio maintenance, DeFi approvals
- **Multi-user scenarios**: Concurrent deposits and withdrawals

**Usage:**

```bash
chmod +x test/utils/run_tests.sh
./test/utils/run_tests.sh
```

### `run_improved_tests.sh`

Runs the Chainlink Functions integration tests for the RiskOracleController:

**Features Tested:**

- Chainlink Functions fee estimation and request submission
- Callback processing and failure handling
- Manual processing workflows and emergency withdrawals
- Circuit breaker functionality and system status
- Authorization and security controls

**Usage:**

```bash
chmod +x test/utils/run_improved_tests.sh
./test/utils/run_improved_tests.sh
```

## Test Organization

### Mock Contracts

Located in `test/mocks/`:

- `MockDAI.sol` - Mock DAI token (18 decimals)
- `MockWETH.sol` - Mock Wrapped Ethereum (18 decimals)
- `MockWBTC.sol` - Mock Wrapped Bitcoin (8 decimals, Bitcoin-accurate)
- `MockChainlinkFunctionsRouter.sol` - Mock Chainlink Functions router for testing
- `MockERC20.sol` - Generic mock ERC20 for testing

### Naming Convention

- **Contracts**: `Mock*` prefix (e.g., `MockDAI`)
- **Config Constants**: `MOCK_*` prefix (e.g., `MOCK_DAI`)
- **Test Files**: `*.t.sol` suffix
- **Scripts**: Descriptive names in `test/utils/`

## Running All Tests

### Quick Test

```bash
forge test
```

### Verbose E2E Tests

```bash
./test/utils/run_tests.sh
```

### Chainlink Integration Tests

```bash
./test/utils/run_improved_tests.sh
```

### Specific Test Contract

```bash
forge test --match-contract RiskOracleControllerTest -vv
forge test --match-contract AIStablecoinE2E -vv
```

## Test Categories

1. **Unit Tests**: Individual contract functionality
2. **Integration Tests**: Contract interactions and Chainlink services
3. **E2E Tests**: Complete user workflows from deposit to withdrawal
4. **Security Tests**: Authorization, circuit breakers, emergency functions
