'use client';

import { useState } from 'react';
import { useAccount, useReadContract } from 'wagmi';
import {
  CONTRACTS,
  COLLATERAL_VAULT_ABI,
  AI_STABLECOIN_ABI,
  TOKENS,
  formatTokenAmount,
} from '@/lib/web3';
import { ManualProcessing } from './ManualProcessing';
import { WithdrawForm } from './WithdrawForm';

export function UserPosition() {
  const { address } = useAccount();
  const [showWithdraw, setShowWithdraw] = useState(false);

  // Read user position
  const {
    data: position,
    isLoading,
    error,
    refetch: refetchPosition,
  } = useReadContract({
    address: CONTRACTS.COLLATERAL_VAULT,
    abi: COLLATERAL_VAULT_ABI,
    functionName: 'getPosition',
    args: address ? [address] : undefined,
  }) as {
    data:
      | [`0x${string}`[], bigint[], bigint, bigint, bigint, bigint, boolean]
      | undefined;
    isLoading: boolean;
    error: Error | null;
    refetch: () => void;
  };

  // Read AIUSD balance
  const { data: aiusdBalance, refetch: refetchAiusdBalance } = useReadContract({
    address: CONTRACTS.AIUSD,
    abi: AI_STABLECOIN_ABI,
    functionName: 'balanceOf',
    args: address ? [address] : undefined,
  }) as { data: bigint | undefined; refetch: () => void };

  // Function to refresh all data
  const refreshData = async () => {
    await Promise.all([refetchPosition(), refetchAiusdBalance()]);
  };

  // Debug logging
  console.log('UserPosition Debug:', {
    address,
    position,
    aiusdBalance,
    isLoading,
    error,
    vaultContract: CONTRACTS.COLLATERAL_VAULT,
  });

  if (isLoading) {
    return (
      <div className="animate-pulse space-y-4">
        <div className="h-4 bg-gray-200 rounded w-3/4"></div>
        <div className="h-4 bg-gray-200 rounded w-1/2"></div>
        <div className="h-4 bg-gray-200 rounded w-2/3"></div>
      </div>
    );
  }

  if (error) {
    console.error('Position reading error:', error);
    return (
      <div className="text-center py-8">
        <div className="w-16 h-16 bg-red-100 rounded-full flex items-center justify-center mx-auto mb-4">
          <span className="text-2xl">⚠️</span>
        </div>
        <h4 className="text-lg font-medium text-red-900 mb-2">
          Error Loading Position
        </h4>
        <p className="text-red-600 text-sm">
          {error.message || 'Failed to load position data'}
        </p>
      </div>
    );
  }

  if (!position || !address) {
    return (
      <div className="text-center py-8">
        <div className="w-16 h-16 bg-gray-100 rounded-full flex items-center justify-center mx-auto mb-4">
          <span className="text-2xl">📊</span>
        </div>
        <h4 className="text-lg font-medium text-gray-900 mb-2">
          No Position Yet
        </h4>
        <p className="text-gray-600">
          Deposit collateral to create your first position
        </p>
        <div className="mt-4 text-xs text-gray-500">
          Connected:{' '}
          {address ? `${address.slice(0, 6)}...${address.slice(-4)}` : 'None'}
        </div>
      </div>
    );
  }

  const [
    tokens,
    amounts,
    totalValue,
    aiusdMinted,
    collateralRatio,
    requestId,
    hasPendingRequest,
  ] = position as [string[], bigint[], bigint, bigint, bigint, bigint, boolean];

  // More debug logging
  console.log('Position data:', {
    tokens,
    amounts,
    totalValue: totalValue?.toString(),
    aiusdMinted: aiusdMinted?.toString(),
    collateralRatio: collateralRatio?.toString(),
    requestId: requestId?.toString(),
    hasPendingRequest,
  });

  // Find token symbols for display
  const getTokenSymbol = (tokenAddress: string) => {
    const entry = Object.entries(TOKENS).find(
      ([, config]) =>
        config.address.toLowerCase() === tokenAddress.toLowerCase()
    );
    if (entry) return entry[0];

    // Fallback: try to extract symbol from address (last 4 characters for debugging)
    console.log('Unknown token address:', tokenAddress);
    return `Token (${tokenAddress.slice(-4)})`;
  };

  const formatCollateralRatio = (ratio: bigint) => {
    // Ratio is in basis points (10000 = 100%)
    return (Number(ratio) / 100).toFixed(1);
  };

  return (
    <div className="space-y-6">
      {/* Position Summary */}
      <div className="bg-gradient-to-r from-green-50 to-blue-50 rounded-lg p-4">
        <div className="grid grid-cols-2 gap-4">
          <div>
            <div className="text-sm text-gray-600">Total Collateral</div>
            <div className="text-2xl font-bold text-gray-900">
              ${(Number(totalValue) / 1e18).toLocaleString()}
            </div>
          </div>
          <div>
            <div className="text-sm text-gray-600">AIUSD Minted</div>
            <div className="text-2xl font-bold text-blue-600">
              {formatTokenAmount(aiusdMinted, 18, 4)} AIUSD
            </div>
          </div>
        </div>
      </div>

      {/* AI Request Status */}
      {hasPendingRequest ? (
        <div className="space-y-4">
          <div className="bg-yellow-50 border border-yellow-200 rounded-lg p-4">
            <div className="flex items-center space-x-2 mb-2">
              <div className="w-3 h-3 bg-yellow-400 rounded-full animate-pulse"></div>
              <span className="font-medium text-yellow-800">AI Processing</span>
            </div>
            <p className="text-sm text-yellow-700">
              Request ID: {requestId.toString()}
            </p>
            <p className="text-sm text-yellow-700">
              AI is analyzing your collateral to determine optimal minting
              ratio...
            </p>
          </div>
          <ManualProcessing requestId={requestId} onSuccess={refreshData} />
        </div>
      ) : (
        <div className="bg-green-50 border border-green-200 rounded-lg p-4">
          <div className="flex items-center space-x-2 mb-2">
            <div className="w-3 h-3 bg-green-400 rounded-full"></div>
            <span className="font-medium text-green-800">Position Active</span>
          </div>
          <p className="text-sm text-green-700">
            Collateral Ratio: {formatCollateralRatio(collateralRatio)}%
          </p>
        </div>
      )}

      {/* Deposited Tokens */}
      {tokens.length > 0 && (
        <div>
          <h4 className="font-medium text-gray-900 mb-3">
            Deposited Collateral
          </h4>
          <div className="space-y-2">
            {tokens.map((tokenAddress, index) => {
              const symbol = getTokenSymbol(tokenAddress);
              const amount = amounts[index];
              const tokenConfig = TOKENS[symbol as keyof typeof TOKENS];

              return (
                <div
                  key={index}
                  className="flex justify-between items-center py-2 px-3 bg-gray-50 rounded"
                >
                  <span className="font-medium">{symbol}</span>
                  <div className="text-right">
                    <div className="font-medium">
                      {formatTokenAmount(amount, tokenConfig?.decimals || 18)}
                    </div>
                    {tokenConfig && (
                      <div className="text-sm text-gray-600">
                        $
                        {(
                          parseFloat(
                            formatTokenAmount(amount, tokenConfig.decimals)
                          ) * tokenConfig.price
                        ).toLocaleString()}
                      </div>
                    )}
                  </div>
                </div>
              );
            })}
          </div>
        </div>
      )}

      {/* AIUSD Balance */}
      <div className="border-t pt-4">
        <div className="flex justify-between items-center">
          <span className="text-gray-600">Your AIUSD Balance:</span>
          <span className="font-bold text-lg text-blue-600">
            {aiusdBalance ? formatTokenAmount(aiusdBalance, 18, 4) : '0'} AIUSD
          </span>
        </div>
      </div>

      {/* Actions */}
      {!hasPendingRequest && Number(aiusdMinted) > 0 && (
        <div className="pt-4 border-t space-y-4">
          {!showWithdraw ? (
            <button
              onClick={() => setShowWithdraw(true)}
              className="w-full bg-red-600 text-white py-2 px-4 rounded-lg font-medium hover:bg-red-700 transition-colors"
            >
              Withdraw Collateral
            </button>
          ) : (
            <div className="space-y-4">
              <div className="flex justify-between items-center">
                <h4 className="font-medium text-gray-900">
                  Withdraw Collateral
                </h4>
                <button
                  onClick={() => setShowWithdraw(false)}
                  className="text-gray-500 hover:text-gray-700"
                >
                  ✕
                </button>
              </div>
              <WithdrawForm
                aiusdMinted={aiusdMinted}
                aiusdBalance={aiusdBalance || BigInt(0)}
                onSuccess={() => {
                  setShowWithdraw(false);
                  refreshData();
                }}
              />
            </div>
          )}
          <p className="text-xs text-gray-500 text-center">
            Burn AIUSD to withdraw your collateral
          </p>
        </div>
      )}
    </div>
  );
}
