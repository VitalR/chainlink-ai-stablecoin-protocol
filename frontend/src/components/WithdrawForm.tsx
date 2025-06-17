'use client';

import { useState } from 'react';
import { useAccount, useWriteContract, useReadContract } from 'wagmi';
import { parseEther } from 'viem';
import {
  CONTRACTS,
  AI_VAULT_ABI,
  AI_STABLECOIN_ABI,
  formatTokenAmount,
} from '@/lib/web3';

interface WithdrawFormProps {
  aiusdMinted: bigint;
  aiusdBalance: bigint;
  onSuccess?: () => void;
}

export function WithdrawForm({
  aiusdMinted,
  aiusdBalance,
  onSuccess,
}: WithdrawFormProps) {
  const { address } = useAccount();
  const { writeContract, isPending } = useWriteContract();
  const [withdrawAmount, setWithdrawAmount] = useState('');

  const maxWithdrawable =
    aiusdMinted < aiusdBalance ? aiusdMinted : aiusdBalance;

  // Check current allowance
  const { data: allowance } = useReadContract({
    address: CONTRACTS.AI_STABLECOIN,
    abi: AI_STABLECOIN_ABI,
    functionName: 'allowance',
    args: address ? [address, CONTRACTS.AI_VAULT] : undefined,
  }) as { data: bigint | undefined };

  const needsApproval = () => {
    if (!withdrawAmount || !allowance) return false;
    const amount = parseEther(withdrawAmount);
    return amount > allowance;
  };

  const handleApprove = async () => {
    if (!address || !withdrawAmount) return;

    try {
      const amount = parseEther(withdrawAmount);

      await writeContract({
        address: CONTRACTS.AI_STABLECOIN,
        abi: AI_STABLECOIN_ABI,
        functionName: 'approve',
        args: [CONTRACTS.AI_VAULT, amount],
      });
    } catch (error) {
      console.error('Approval failed:', error);
    }
  };

  const handleWithdraw = async () => {
    if (!address || !withdrawAmount || parseFloat(withdrawAmount) <= 0) return;

    try {
      const amount = parseEther(withdrawAmount);

      if (amount > maxWithdrawable) {
        alert('Amount exceeds maximum withdrawable');
        return;
      }

      await writeContract({
        address: CONTRACTS.AI_VAULT,
        abi: AI_VAULT_ABI,
        functionName: 'withdrawCollateral',
        args: [amount],
      });

      onSuccess?.();
      setWithdrawAmount('');
    } catch (error) {
      console.error('Withdraw failed:', error);
    }
  };

  const calculateWithdrawRatio = () => {
    if (!withdrawAmount || parseFloat(withdrawAmount) <= 0 || !aiusdMinted)
      return 0;
    const amount = parseFloat(withdrawAmount);
    const minted = parseFloat(formatTokenAmount(aiusdMinted, 18, 4));
    if (minted === 0) return 0;
    return (amount / minted) * 100;
  };

  return (
    <div className="space-y-4">
      {/* Withdraw Input */}
      <div>
        <label className="block text-sm font-medium text-gray-700 mb-2">
          AIUSD Amount to Burn
        </label>
        <div className="relative">
          <input
            type="number"
            placeholder="0.0"
            value={withdrawAmount}
            onChange={(e) => setWithdrawAmount(e.target.value)}
            className="w-full px-3 py-3 border-2 border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500 text-lg font-medium bg-white shadow-sm text-gray-900 placeholder-gray-400"
            step="any"
            max={formatTokenAmount(maxWithdrawable)}
          />
          <button
            onClick={() =>
              setWithdrawAmount(formatTokenAmount(maxWithdrawable))
            }
            className="absolute right-3 top-3 text-sm bg-blue-600 text-white px-3 py-1 rounded-md hover:bg-blue-700 font-medium"
          >
            MAX
          </button>
        </div>
        <div className="flex justify-between text-sm text-gray-600 mt-2">
          <span>
            Available:{' '}
            <span className="font-medium">
              {formatTokenAmount(aiusdBalance, 18, 4)} AIUSD
            </span>
          </span>
          <span>
            Max:{' '}
            <span className="font-medium">
              {formatTokenAmount(maxWithdrawable, 18, 4)} AIUSD
            </span>
          </span>
        </div>
      </div>

      {/* Withdrawal Preview */}
      {withdrawAmount && parseFloat(withdrawAmount) > 0 && (
        <div className="bg-blue-50 border border-blue-200 rounded-lg p-4">
          <div className="text-sm font-medium text-blue-800 mb-3">
            Withdrawal Preview:
          </div>
          <div className="space-y-2 text-sm">
            <div className="flex justify-between">
              <span className="text-gray-700">AIUSD to burn:</span>
              <span className="font-semibold text-gray-900">
                {parseFloat(withdrawAmount).toFixed(4)} AIUSD
              </span>
            </div>
            <div className="flex justify-between">
              <span className="text-gray-700">Withdrawal ratio:</span>
              <span className="font-semibold text-blue-600">
                {calculateWithdrawRatio().toFixed(2)}%
              </span>
            </div>
            <div className="text-xs text-blue-700 mt-3 p-2 bg-blue-100 rounded">
              💡 You will receive proportional amounts of all deposited tokens
            </div>
          </div>
        </div>
      )}

      {/* Action Buttons */}
      <div className="space-y-2">
        {needsApproval() ? (
          <button
            onClick={handleApprove}
            disabled={
              isPending || !withdrawAmount || parseFloat(withdrawAmount) <= 0
            }
            className="w-full bg-blue-600 text-white py-3 px-4 rounded-lg font-medium hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
          >
            {isPending ? 'Approving...' : 'Approve AIUSD'}
          </button>
        ) : (
          <button
            onClick={handleWithdraw}
            disabled={
              isPending || !withdrawAmount || parseFloat(withdrawAmount) <= 0
            }
            className="w-full bg-red-600 text-white py-3 px-4 rounded-lg font-medium hover:bg-red-700 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
          >
            {isPending
              ? 'Processing Withdrawal...'
              : 'Burn AIUSD & Withdraw Collateral'}
          </button>
        )}
      </div>

      <div className="text-xs text-gray-500 text-center">
        {needsApproval()
          ? 'First approve AIUSD spending, then withdraw'
          : 'Burning AIUSD will return proportional collateral to your wallet'}
      </div>
    </div>
  );
}
 