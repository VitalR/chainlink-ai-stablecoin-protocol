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

  // Read AI fee
  const { data: aiFee } = useReadContract({
    address: CONTRACTS.AI_CONTROLLER,
    abi: AI_CONTROLLER_ABI,
    functionName: 'estimateTotalFee',
  });

  // Read token balances
  const { data: daiBalance } = useReadContract({
    address: CONTRACTS.MOCK_DAI,
    abi: ERC20_ABI,
    functionName: 'balanceOf',
    args: address ? [address] : undefined,
  });

  const { data: wethBalance } = useReadContract({
    address: CONTRACTS.MOCK_WETH,
    abi: ERC20_ABI,
    functionName: 'balanceOf',
    args: address ? [address] : undefined,
  });

  const { data: wbtcBalance } = useReadContract({
    address: CONTRACTS.MOCK_WBTC,
    abi: ERC20_ABI,
    functionName: 'balanceOf',
    args: address ? [address] : undefined,
  });

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
    const tokens: string[] = [];
    const amounts: bigint[] = [];

    Object.entries(selectedTokens).forEach(([token, amount]) => {
      if (amount && parseFloat(amount) > 0) {
        const tokenConfig = TOKENS[token as keyof typeof TOKENS];
        tokens.push(tokenConfig.address);
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
        value: aiFee || parseEther('0.015'),
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
            <div key={symbol} className="border rounded-lg p-4">
              <div className="flex justify-between items-center mb-2">
                <label className="font-medium text-gray-700">{symbol}</label>
                <span className="text-sm text-gray-500">
                  Balance:{' '}
                  {balance ? formatTokenAmount(balance, config.decimals) : '0'}
                </span>
              </div>
              <div className="flex items-center space-x-2">
                <input
                  type="number"
                  placeholder="0.0"
                  value={selectedTokens[symbol]}
                  onChange={(e) => handleTokenChange(symbol, e.target.value)}
                  className="flex-1 px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                  step="any"
                />
                <span className="text-sm text-gray-500 min-w-[80px]">
                  ${config.price.toLocaleString()}
                </span>
              </div>
              {selectedTokens[symbol] &&
                parseFloat(selectedTokens[symbol]) > 0 && (
                  <div className="mt-1 text-sm text-gray-600">
                    Value: $
                    {(
                      parseFloat(selectedTokens[symbol]) * config.price
                    ).toLocaleString()}
                  </div>
                )}
            </div>
          );
        })}
      </div>

      {/* Summary */}
      <div className="bg-gray-50 rounded-lg p-4">
        <div className="flex justify-between items-center mb-2">
          <span className="font-medium">Total Collateral Value:</span>
          <span className="text-lg font-bold text-green-600">
            ${totalValue.toLocaleString()}
          </span>
        </div>
        <div className="flex justify-between items-center text-sm text-gray-600">
          <span>AI Processing Fee:</span>
          <span>{aiFee ? formatEther(aiFee) : '0.015'} ETH</span>
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
        <div className="text-sm text-gray-600 text-center">
          AI will analyze your collateral and determine the optimal minting
          ratio
        </div>
      )}
    </div>
  );
}
