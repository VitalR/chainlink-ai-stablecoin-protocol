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
    if (!withdrawAmount || parseFloat(withdrawAmount) <= 0) return 0;
    const amount = parseFloat(withdrawAmount);
    const minted = parseFloat(formatTokenAmount(aiusdMinted));
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
            className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
            step="any"
            max={formatTokenAmount(maxWithdrawable)}
          />
          <button
            onClick={() =>
              setWithdrawAmount(formatTokenAmount(maxWithdrawable))
            }
            className="absolute right-2 top-2 text-xs bg-blue-100 text-blue-600 px-2 py-1 rounded hover:bg-blue-200"
          >
            MAX
          </button>
        </div>
        <div className="flex justify-between text-xs text-gray-500 mt-1">
          <span>Available: {formatTokenAmount(aiusdBalance)} AIUSD</span>
          <span>Max: {formatTokenAmount(maxWithdrawable)} AIUSD</span>
        </div>
      </div>

      {/* Withdrawal Preview */}
      {withdrawAmount && parseFloat(withdrawAmount) > 0 && (
        <div className="bg-gray-50 rounded-lg p-3">
          <div className="text-sm text-gray-600 mb-2">Withdrawal Preview:</div>
          <div className="space-y-1 text-sm">
            <div className="flex justify-between">
              <span>AIUSD to burn:</span>
              <span className="font-medium">{withdrawAmount} AIUSD</span>
            </div>
            <div className="flex justify-between">
              <span>Collateral ratio:</span>
              <span className="font-medium">
                {calculateWithdrawRatio().toFixed(1)}%
              </span>
            </div>
            <div className="text-xs text-gray-500 mt-2">
              You will receive proportional amounts of all deposited tokens
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
