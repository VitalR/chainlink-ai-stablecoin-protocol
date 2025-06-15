'use client';

import { useState } from 'react';
import { useAccount, useWriteContract, useReadContract } from 'wagmi';
import { parseEther, formatEther } from 'viem';
import {
  CONTRACTS,
  TOKENS,
  AI_VAULT_ABI,
  ERC20_ABI,
  AI_CONTROLLER_ABI,
  formatTokenAmount,
  parseTokenAmount,
} from '@/lib/web3';

export function DepositForm() {
  const { address } = useAccount();
  const { writeContract, isPending } = useWriteContract();

  const [selectedTokens, setSelectedTokens] = useState<{
    [key: string]: string;
  }>({
    DAI: '',
    WETH: '',
    WBTC: '',
  });

  // Use fixed fee for demo (0.001 ETH)
  const aiFee = parseEther('0.001');

  // Read token balances
  const { data: daiBalance } = useReadContract({
    address: CONTRACTS.MOCK_DAI,
    abi: ERC20_ABI,
    functionName: 'balanceOf',
    args: address ? [address] : undefined,
  }) as { data: bigint | undefined };

  const { data: wethBalance } = useReadContract({
    address: CONTRACTS.MOCK_WETH,
    abi: ERC20_ABI,
    functionName: 'balanceOf',
    args: address ? [address] : undefined,
  }) as { data: bigint | undefined };

  const { data: wbtcBalance } = useReadContract({
    address: CONTRACTS.MOCK_WBTC,
    abi: ERC20_ABI,
    functionName: 'balanceOf',
    args: address ? [address] : undefined,
  }) as { data: bigint | undefined };

  const handleTokenChange = (token: string, value: string) => {
    setSelectedTokens((prev) => ({ ...prev, [token]: value }));
  };

  const calculateTotalValue = () => {
    let total = 0;
    Object.entries(selectedTokens).forEach(([token, amount]) => {
      if (amount && parseFloat(amount) > 0) {
        const tokenConfig = TOKENS[token as keyof typeof TOKENS];
        total += parseFloat(amount) * tokenConfig.price;
      }
    });
    return total;
  };

  const handleDeposit = async () => {
    if (!address) return;

    // Prepare tokens and amounts arrays
    const tokens: `0x${string}`[] = [];
    const amounts: bigint[] = [];

    Object.entries(selectedTokens).forEach(([token, amount]) => {
      if (amount && parseFloat(amount) > 0) {
        const tokenConfig = TOKENS[token as keyof typeof TOKENS];
        tokens.push(tokenConfig.address as `0x${string}`);
        amounts.push(parseTokenAmount(amount, tokenConfig.decimals));
      }
    });

    if (tokens.length === 0) {
      alert('Please select at least one token to deposit');
      return;
    }

    try {
      await writeContract({
        address: CONTRACTS.AI_VAULT,
        abi: AI_VAULT_ABI,
        functionName: 'depositBasket',
        args: [tokens, amounts],
        value: aiFee,
      });
    } catch (error) {
      console.error('Deposit failed:', error);
    }
  };

  const totalValue = calculateTotalValue();

  return (
    <div className="space-y-6">
      {/* Token Inputs */}
      <div className="space-y-4">
        {Object.entries(TOKENS).map(([symbol, config]) => {
          const balance =
            symbol === 'DAI'
              ? daiBalance
              : symbol === 'WETH'
              ? wethBalance
              : wbtcBalance;

          return (
            <div
              key={symbol}
              className="border rounded-lg p-4 bg-white shadow-sm"
            >
              <div className="flex justify-between items-center mb-2">
                <label className="font-semibold text-gray-800">{symbol}</label>
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
                  className="flex-1 px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500 font-medium bg-white text-gray-900 placeholder-gray-400 autofill:bg-white autofill:text-gray-900"
                  step="any"
                  autoComplete="off"
                />
                <span className="text-sm font-bold text-gray-800 min-w-[80px] bg-gray-100 px-2 py-1 rounded">
                  ${config.price.toLocaleString()}
                </span>
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
            {formatEther(aiFee)} ETH
          </span>
        </div>
      </div>

      {/* Deposit Button */}
      <button
        onClick={handleDeposit}
        disabled={isPending || totalValue === 0}
        className="w-full bg-gradient-to-r from-blue-600 to-purple-600 text-white py-3 px-4 rounded-lg font-medium hover:from-blue-700 hover:to-purple-700 disabled:opacity-50 disabled:cursor-not-allowed transition-all"
      >
        {isPending
          ? 'Processing...'
          : `Deposit Collateral ($${totalValue.toLocaleString()})`}
      </button>

      {totalValue > 0 && (
        <div className="text-sm text-gray-700 text-center font-medium">
          AI will analyze your collateral and determine the optimal minting
          ratio
        </div>
      )}
    </div>
  );
}
