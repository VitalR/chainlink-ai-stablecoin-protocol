'use client';

import { useState } from 'react';
import {
  useAccount,
  useWriteContract,
  useReadContract,
  useChainId,
  useSwitchChain,
  useWaitForTransactionReceipt,
} from 'wagmi';
import {
  TOKENS,
  COLLATERAL_VAULT_ABI,
  ERC20_ABI,
  formatTokenAmount,
  parseTokenAmount,
  getChainContracts,
  getChainName,
  AIEngine,
  useRealTimePrices,
  RISK_ORACLE_CONTROLLER_ABI,
} from '@/lib/web3';

export function DepositForm() {
  const { address } = useAccount();
  const chainId = useChainId();
  const contracts = getChainContracts(chainId);
  const { writeContract, isPending, data: hash } = useWriteContract();
  const { switchChain } = useSwitchChain();
  const [transactionStep, setTransactionStep] = useState<
    'idle' | 'approving' | 'depositing'
  >('idle');
  const [currentApprovalIndex, setCurrentApprovalIndex] = useState<number>(-1);

  // Get real-time prices from Chainlink Data Feeds
  const { tokens: tokensWithRealPrices, priceStatus } =
    useRealTimePrices(chainId);

  // Wait for transaction confirmation
  const {
    isLoading: isConfirming,
    isSuccess: isConfirmed,
    error: confirmError,
  } = useWaitForTransactionReceipt({
    hash,
  });

  // State must be declared before any conditional usage
  const [selectedTokens, setSelectedTokens] = useState<{
    [key: string]: string;
  }>({
    // Stablecoins first
    DAI: '',
    USDC: '',
    // Crypto assets
    WETH: '',
    WBTC: '',
    LINK: '',
    // RWA last
    OUSG: '',
  });

  // Reset transaction step when confirmed
  if (isConfirmed && transactionStep !== 'idle') {
    setTransactionStep('idle');
    setCurrentApprovalIndex(-1);
    setSelectedTokens({
      DAI: '',
      USDC: '',
      WETH: '',
      WBTC: '',
      LINK: '',
      OUSG: '',
    });
  }

  const [selectedEngine, setSelectedEngine] = useState<AIEngine>(
    AIEngine.ALGORITHMIC
  );

  // Check if vault is available on current chain (only available on Sepolia)
  const isVaultAvailable =
    'COLLATERAL_VAULT' in contracts &&
    contracts.COLLATERAL_VAULT &&
    contracts.COLLATERAL_VAULT !== '0x';

  // Get AI fee from the contract instead of hardcoding it
  const { data: contractAiFee } = useReadContract({
    address:
      isVaultAvailable && 'RISK_ORACLE_CONTROLLER' in contracts
        ? (contracts as { RISK_ORACLE_CONTROLLER: `0x${string}` })
            .RISK_ORACLE_CONTROLLER
        : undefined,
    abi: RISK_ORACLE_CONTROLLER_ABI,
    functionName: 'estimateTotalFee',
    query: {
      enabled: !!isVaultAvailable && 'RISK_ORACLE_CONTROLLER' in contracts,
      staleTime: 60 * 1000, // Cache for 1 minute
    },
  });

  // Use contract fee if available, otherwise fallback to 0 (subscription model)
  const aiFee = contractAiFee || BigInt(0);

  // Read token balances for all supported tokens individually (only if vault is available)
  const { data: daiBalance } = useReadContract({
    address: TOKENS.DAI.address,
    abi: ERC20_ABI,
    functionName: 'balanceOf',
    args: address && isVaultAvailable ? [address] : undefined,
  }) as { data: bigint | undefined };

  const { data: wethBalance } = useReadContract({
    address: TOKENS.WETH.address,
    abi: ERC20_ABI,
    functionName: 'balanceOf',
    args: address && isVaultAvailable ? [address] : undefined,
  }) as { data: bigint | undefined };

  const { data: wbtcBalance } = useReadContract({
    address: TOKENS.WBTC.address,
    abi: ERC20_ABI,
    functionName: 'balanceOf',
    args: address && isVaultAvailable ? [address] : undefined,
  }) as { data: bigint | undefined };

  const { data: usdcBalance } = useReadContract({
    address: TOKENS.USDC.address,
    abi: ERC20_ABI,
    functionName: 'balanceOf',
    args: address && isVaultAvailable ? [address] : undefined,
  }) as { data: bigint | undefined };

  const { data: ousgBalance } = useReadContract({
    address: TOKENS.OUSG.address,
    abi: ERC20_ABI,
    functionName: 'balanceOf',
    args: address && isVaultAvailable ? [address] : undefined,
  }) as { data: bigint | undefined };

  const { data: linkBalance } = useReadContract({
    address: TOKENS.LINK.address,
    abi: ERC20_ABI,
    functionName: 'balanceOf',
    args: address && isVaultAvailable ? [address] : undefined,
  }) as { data: bigint | undefined };

  // Create balance mapping
  const tokenBalances = {
    // Stablecoins first
    DAI: daiBalance,
    USDC: usdcBalance,
    // Crypto assets
    WETH: wethBalance,
    WBTC: wbtcBalance,
    LINK: linkBalance,
    // RWA last
    OUSG: ousgBalance,
  };

  const handleTokenChange = (token: string, value: string) => {
    setSelectedTokens((prev) => ({ ...prev, [token]: value }));
  };

  const calculateTotalValue = () => {
    let total = 0;
    Object.entries(selectedTokens).forEach(([token, amount]) => {
      if (amount && parseFloat(amount) > 0) {
        // Use real-time prices from Chainlink Data Feeds
        const tokenConfig =
          tokensWithRealPrices[token as keyof typeof tokensWithRealPrices];
        total += parseFloat(amount) * tokenConfig.price;
      }
    });
    return total;
  };

  // Check allowances for selected tokens
  const checkTokenAllowances = async (
    tokensToDeposit: {
      address: `0x${string}`;
      amount: bigint;
      symbol: string;
    }[]
  ) => {
    const needsApproval: typeof tokensToDeposit = [];

    for (const token of tokensToDeposit) {
      try {
        // This would need to be implemented with proper contract reads
        // For now, assume all tokens need approval for simplicity
        needsApproval.push(token);
      } catch (error) {
        console.error(`Error checking allowance for ${token.symbol}:`, error);
        needsApproval.push(token); // Assume needs approval on error
      }
    }

    return needsApproval;
  };

  const handleDeposit = async () => {
    if (!address || !isVaultAvailable) return;

    // Prepare tokens and amounts arrays
    const tokensToDeposit: {
      address: `0x${string}`;
      amount: bigint;
      symbol: string;
    }[] = [];

    Object.entries(selectedTokens).forEach(([symbol, amount]) => {
      if (amount && parseFloat(amount) > 0) {
        const tokenConfig =
          tokensWithRealPrices[symbol as keyof typeof tokensWithRealPrices];
        tokensToDeposit.push({
          address: tokenConfig.address as `0x${string}`,
          amount: parseTokenAmount(amount, tokenConfig.decimals),
          symbol,
        });
      }
    });

    if (tokensToDeposit.length === 0) {
      alert('Please select at least one token to deposit');
      return;
    }

    try {
      // Step 1: Check which tokens need approval
      const needsApproval = await checkTokenAllowances(tokensToDeposit);

      // Step 2: Handle approvals one by one
      if (needsApproval.length > 0) {
        setTransactionStep('approving');

        for (let i = 0; i < needsApproval.length; i++) {
          setCurrentApprovalIndex(i);
          const token = needsApproval[i];

          console.log(
            `Approving ${token.symbol} for amount ${token.amount.toString()}`
          );

          await writeContract({
            address: token.address,
            abi: ERC20_ABI,
            functionName: 'approve',
            args: [contracts.COLLATERAL_VAULT!, token.amount],
          });

          // Wait for this approval to be confirmed before moving to next
          // In a real implementation, you'd want to use useWaitForTransactionReceipt
          await new Promise((resolve) => setTimeout(resolve, 3000));
        }
      }

      // Step 3: Deposit tokens after all approvals
      setTransactionStep('depositing');
      setCurrentApprovalIndex(-1);

      const tokens = tokensToDeposit.map((t) => t.address);
      const amounts = tokensToDeposit.map((t) => t.amount);

      await writeContract({
        address: contracts.COLLATERAL_VAULT!,
        abi: COLLATERAL_VAULT_ABI,
        functionName: 'depositBasket',
        args: [tokens, amounts, selectedEngine],
        value: aiFee,
      });
    } catch (error) {
      console.error('Deposit process failed:', error);
      setTransactionStep('idle');
      setCurrentApprovalIndex(-1);

      if (error instanceof Error) {
        if (error.message.includes('User rejected')) {
          // User cancelled, no need to show error
        } else if (error.message.includes('insufficient allowance')) {
          alert(
            'Token approval failed. Please try again and ensure you approve the spending of tokens.'
          );
        } else {
          alert(`Deposit failed: ${error.message}`);
        }
      }
    }
  };

  const handleSwitchToSepolia = () => {
    switchChain({ chainId: 11155111 }); // Sepolia
  };

  const totalValue = calculateTotalValue();

  const getEngineDescription = (engine: AIEngine) => {
    switch (engine) {
      case AIEngine.ALGORITHMIC:
        return 'Algorithmic AI - Fast, reliable, and fully decentralized analysis';
      case AIEngine.BEDROCK:
        return 'Amazon Bedrock (Claude 3 Sonnet) - Most sophisticated enterprise analysis';
      case AIEngine.MANUAL:
        return 'Manual Processing - Fallback option for edge cases';
      default:
        return 'Unknown engine';
    }
  };

  const getTokenCategory = (category: string) => {
    switch (category) {
      case 'stablecoin':
        return { color: 'bg-green-100 text-green-800', icon: '💰' };
      case 'crypto':
        return { color: 'bg-blue-100 text-blue-800', icon: '₿' };
      case 'rwa':
        return { color: 'bg-purple-100 text-purple-800', icon: '🏢' };
      default:
        return { color: 'bg-gray-100 text-gray-800', icon: '🪙' };
    }
  };

  // Get block explorer URL
  const getBlockExplorerUrl = (txHash: string) => {
    switch (chainId) {
      case 11155111: // Sepolia
        return `https://sepolia.etherscan.io/tx/${txHash}`;
      case 43113: // Fuji
        return `https://testnet.snowtrace.io/tx/${txHash}`;
      default:
        return `https://sepolia.etherscan.io/tx/${txHash}`;
    }
  };

  // Show network switch prompt if vault is not available
  if (!isVaultAvailable) {
    return (
      <div className="bg-yellow-50 border border-yellow-200 rounded-lg p-6">
        <div className="flex items-center space-x-2 mb-2">
          <span className="text-yellow-600">⚠️</span>
          <span className="font-medium text-yellow-800">
            Deposits Only Available on Sepolia
          </span>
        </div>
        <p className="text-sm text-yellow-700 mb-4">
          AI-powered collateral analysis and deposits are only available on
          Ethereum Sepolia where the CollateralVault is deployed.
        </p>
        <button
          onClick={handleSwitchToSepolia}
          className="bg-yellow-600 text-white px-4 py-2 rounded-lg font-medium hover:bg-yellow-700 transition-colors"
        >
          Switch to Sepolia Testnet
        </button>
        <div className="mt-3 text-xs text-yellow-600">
          💡 After depositing on Sepolia, you can bridge your AIUSD to Avalanche
          Fuji for fast execution
        </div>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      {/* AI Engine Selection */}
      <div className="border rounded-lg p-4 bg-gradient-to-r from-blue-50 to-purple-50">
        <label className="font-semibold text-gray-800 mb-3 block">
          🤖 AI Processing Engine
        </label>
        <select
          value={selectedEngine}
          onChange={(e) =>
            setSelectedEngine(Number(e.target.value) as AIEngine)
          }
          className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500 bg-white text-gray-900 font-medium shadow-sm"
        >
          <option value={AIEngine.ALGORITHMIC}>
            Algorithmic AI - Fast & Reliable (Default)
          </option>
          <option value={AIEngine.BEDROCK}>
            Amazon Bedrock (Claude 3 Sonnet) - Enterprise AI
          </option>
          <option value={AIEngine.MANUAL}>Manual Processing - Fallback</option>
        </select>
        <p className="text-sm text-gray-600 mt-2">
          {getEngineDescription(selectedEngine)}
        </p>
      </div>

      {/* Price Feed Status */}
      <div
        className={`border rounded-lg p-4 ${
          priceStatus.hasRealPrices
            ? 'bg-gradient-to-r from-green-50 to-blue-50 border-green-200'
            : 'bg-gradient-to-r from-yellow-50 to-orange-50 border-yellow-200'
        }`}
      >
        <div className="flex items-center space-x-2 mb-2">
          <span className="text-lg">
            {priceStatus.hasRealPrices ? '✅' : '⚠️'}
          </span>
          <span
            className={`font-semibold ${
              priceStatus.hasRealPrices ? 'text-green-800' : 'text-yellow-800'
            }`}
          >
            {priceStatus.hasRealPrices
              ? 'Live Chainlink Prices'
              : 'Using Fallback Prices'}
          </span>
        </div>
        <p
          className={`text-sm ${
            priceStatus.hasRealPrices ? 'text-green-700' : 'text-yellow-700'
          }`}
        >
          {priceStatus.hasRealPrices
            ? 'Real-time prices are being fetched from Chainlink Data Feeds for accurate collateral valuation.'
            : 'Unable to fetch real-time prices. Using fallback prices - switch to Sepolia for live Chainlink Data Feeds.'}
        </p>
        {priceStatus.hasRealPrices && (
          <div className="text-xs text-green-600 mt-1">
            💡 Prices update every 30 seconds for optimal accuracy
          </div>
        )}
      </div>

      {/* Token Inputs */}
      <div className="space-y-4">
        {Object.entries(tokensWithRealPrices).map(([symbol, config]) => {
          const balance = tokenBalances[symbol as keyof typeof tokenBalances];
          const category = getTokenCategory(config.category);

          return (
            <div
              key={symbol}
              className="border rounded-lg p-4 bg-white shadow-sm"
            >
              <div className="flex justify-between items-center mb-2">
                <div className="flex items-center space-x-2">
                  <label className="font-semibold text-gray-800">
                    {symbol}
                  </label>
                  <span
                    className={`text-xs px-2 py-1 rounded-full ${category.color} font-medium flex items-center`}
                  >
                    <span className="mr-1">{category.icon}</span>
                    {config.category.toUpperCase()}
                  </span>
                </div>
                <span className="text-sm font-medium text-blue-600">
                  Balance:{' '}
                  <span className="font-bold">
                    {balance
                      ? formatTokenAmount(balance, config.decimals)
                      : '0'}
                  </span>
                </span>
              </div>
              <div className="flex items-center space-x-2">
                <input
                  type="number"
                  placeholder="0.0"
                  value={selectedTokens[symbol]}
                  onChange={(e) => handleTokenChange(symbol, e.target.value)}
                  className="flex-1 px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500 font-medium bg-white text-gray-900 placeholder-gray-400"
                  step="any"
                  autoComplete="off"
                />
                <div className="text-sm min-w-[120px] text-right">
                  <span
                    className={`font-bold px-2 py-1 rounded ${
                      priceStatus.hasRealPrices
                        ? 'bg-green-100 text-green-800'
                        : 'bg-gray-100 text-gray-800'
                    }`}
                  >
                    ${config.price.toLocaleString()}
                  </span>
                  {priceStatus.hasRealPrices && symbol !== 'OUSG' && (
                    <div className="text-xs text-green-600 mt-1">
                      📡 Live Price
                    </div>
                  )}
                </div>
              </div>
              {selectedTokens[symbol] &&
                parseFloat(selectedTokens[symbol]) > 0 && (
                  <div className="mt-2 text-sm">
                    <span className="text-gray-600">Value: </span>
                    <span className="font-bold text-green-600">
                      $
                      {(
                        parseFloat(selectedTokens[symbol]) * config.price
                      ).toLocaleString()}
                    </span>
                  </div>
                )}
            </div>
          );
        })}
      </div>

      {/* Diversity Incentive Info */}
      {totalValue > 0 && (
        <div className="bg-gradient-to-r from-green-50 to-blue-50 rounded-lg p-4 border border-green-200">
          <div className="flex items-center space-x-2 mb-2">
            <span className="text-green-600">🎯</span>
            <span className="font-semibold text-green-800">
              Diversification Bonus
            </span>
          </div>
          <p className="text-sm text-green-700">
            Deposit multiple asset types to potentially receive lower collateral
            ratios (125-135% vs 170-200%)
          </p>
          <div className="mt-2 text-sm">
            <span className="font-medium text-green-700">
              Current basket diversity:{' '}
            </span>
            <span className="font-semibold text-green-700">
              {
                Object.values(selectedTokens).filter(
                  (amount) => parseFloat(amount || '0') > 0
                ).length
              }{' '}
              assets
            </span>
          </div>
        </div>
      )}

      {/* Summary */}
      <div className="bg-gradient-to-r from-blue-50 to-purple-50 rounded-lg p-4 border border-blue-200">
        <div className="flex justify-between items-center mb-2">
          <span className="font-semibold text-gray-800">
            Total Collateral Value:
          </span>
          <span className="text-xl font-bold text-green-600">
            ${totalValue.toLocaleString()}
          </span>
        </div>
        <div className="flex justify-between items-center text-sm">
          <span className="text-gray-700 font-medium">AI Processing Fee:</span>
          <span className="font-bold text-blue-600">
            {aiFee === BigInt(0)
              ? 'Included (Subscription)'
              : `${aiFee.toString()} ETH`}
          </span>
        </div>
      </div>

      {/* Transaction Monitor */}
      {(hash || transactionStep !== 'idle') && (
        <div className="bg-gray-50 border border-gray-200 rounded-lg p-4">
          <div className="flex items-center space-x-2 mb-3">
            <div
              className={`w-3 h-3 rounded-full ${
                isConfirmed
                  ? 'bg-green-400'
                  : confirmError
                  ? 'bg-red-400'
                  : 'bg-blue-400 animate-pulse'
              }`}
            ></div>
            <span className="font-medium text-gray-800">
              {isConfirmed
                ? '✅ Transaction Confirmed'
                : confirmError
                ? '❌ Transaction Failed'
                : isConfirming
                ? '⏳ Confirming Transaction...'
                : transactionStep === 'approving'
                ? `🔐 Approving Token ${currentApprovalIndex + 1}...`
                : transactionStep === 'depositing'
                ? '💰 Processing Deposit...'
                : '📤 Transaction Submitted'}
            </span>
          </div>

          {/* Approval Progress */}
          {transactionStep === 'approving' && currentApprovalIndex >= 0 && (
            <div className="mb-3 text-sm text-blue-700 bg-blue-50 p-2 rounded">
              🔐 Approving tokens for vault to spend. This allows the vault to
              transfer your tokens during deposit.
              <div className="mt-1 text-xs text-blue-600">
                Step {currentApprovalIndex + 1}: Approve spending permissions
              </div>
            </div>
          )}

          {hash && (
            <div className="space-y-2">
              <div className="flex items-center justify-between">
                <span className="text-sm text-gray-600">Transaction Hash:</span>
                <div className="flex items-center space-x-2">
                  <span className="text-sm font-mono text-gray-800">
                    {hash.slice(0, 10)}...{hash.slice(-8)}
                  </span>
                  <a
                    href={getBlockExplorerUrl(hash)}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="text-blue-600 hover:text-blue-800 text-sm font-medium"
                  >
                    View on {getChainName(chainId)} Explorer ↗
                  </a>
                </div>
              </div>

              {confirmError && (
                <div className="text-sm text-red-600 bg-red-50 p-2 rounded">
                  ❌ {confirmError.message}
                </div>
              )}

              {isConfirmed && transactionStep === 'depositing' && (
                <div className="text-sm text-green-600 bg-green-50 p-2 rounded">
                  🎉 Deposit successful! AI is now analyzing your collateral for
                  optimal minting ratio.
                </div>
              )}
            </div>
          )}
        </div>
      )}

      {/* Deposit Button */}
      <button
        onClick={handleDeposit}
        disabled={
          isPending ||
          isConfirming ||
          totalValue === 0 ||
          transactionStep !== 'idle'
        }
        className="w-full bg-gradient-to-r from-blue-600 to-purple-600 text-white py-3 px-4 rounded-lg font-medium hover:from-blue-700 hover:to-purple-700 disabled:opacity-50 disabled:cursor-not-allowed transition-all"
      >
        {transactionStep === 'approving'
          ? `Approving Token ${currentApprovalIndex + 1}...`
          : transactionStep === 'depositing'
          ? 'Processing Deposit...'
          : isPending
          ? 'Confirm in Wallet...'
          : isConfirming
          ? 'Confirming Transaction...'
          : `Deposit Collateral ($${totalValue.toLocaleString()})`}
      </button>

      {totalValue > 0 && (
        <div className="text-sm text-gray-700 text-center font-medium">
          {transactionStep === 'approving'
            ? 'Please approve each token in your wallet to allow the vault to spend them during deposit.'
            : isConfirming
            ? 'Transaction submitted, waiting for confirmation...'
            : selectedEngine === AIEngine.ALGORITHMIC
            ? 'Algorithmic AI will quickly analyze your collateral and determine the optimal minting ratio'
            : selectedEngine === AIEngine.BEDROCK
            ? 'Amazon Bedrock AI will provide enterprise-grade analysis of your collateral portfolio'
            : 'Your deposit will be processed manually with standard ratios'}
        </div>
      )}
    </div>
  );
}
