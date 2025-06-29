'use client';

import { useState, useEffect } from 'react';
import {
  useAccount,
  useWriteContract,
  useReadContract,
  useChainId,
  useWaitForTransactionReceipt,
} from 'wagmi';
import { parseEther } from 'viem';
import {
  COLLATERAL_VAULT_ABI,
  ERC20_ABI,
  formatTokenAmount,
  getChainContracts,
  getChainName,
} from '@/lib/web3';

interface WithdrawFormProps {
  positionIndex: number;
  aiusdMinted: bigint;
  aiusdBalance: bigint;
  onSuccess?: () => void;
}

export function WithdrawForm({
  positionIndex,
  aiusdMinted,
  aiusdBalance,
  onSuccess,
}: WithdrawFormProps) {
  const { address } = useAccount();
  const chainId = useChainId();
  const contracts = getChainContracts(chainId);
  const { writeContract, isPending, data: hash } = useWriteContract();
  const [transactionStep, setTransactionStep] = useState<
    'idle' | 'approving' | 'withdrawing'
  >('idle');
  const [withdrawAmount, setWithdrawAmount] = useState('');
  const [maxAmount, setMaxAmount] = useState<bigint | null>(null);

  // Read AIUSD allowance with refetch capability - moved before usage
  const {
    data: allowance,
    refetch: refetchAllowance,
    isLoading: isLoadingAllowance,
  } = useReadContract({
    address: contracts.AIUSD,
    abi: ERC20_ABI,
    functionName: 'allowance',
    args:
      address && 'COLLATERAL_VAULT' in contracts && contracts.COLLATERAL_VAULT
        ? [address, contracts.COLLATERAL_VAULT]
        : undefined,
    query: {
      enabled: !!address && 'COLLATERAL_VAULT' in contracts,
      refetchInterval: 3000, // Refetch every 3 seconds to catch approval updates
      staleTime: 1000, // Consider data stale after 1 second
    },
  }) as {
    data: bigint | undefined;
    refetch: () => void;
    isLoading: boolean;
  };

  // Wait for transaction confirmation
  const {
    isLoading: isConfirming,
    isSuccess: isConfirmed,
    error: confirmError,
  } = useWaitForTransactionReceipt({
    hash,
  });

  // Handle transaction confirmation with useEffect to avoid hoisting issues
  useEffect(() => {
    if (isConfirmed && transactionStep !== 'idle') {
      console.log('Transaction confirmed, resetting state...');
      if (transactionStep === 'approving') {
        console.log('Approval confirmed, refetching allowance...');
        refetchAllowance(); // Safe to use here since it's defined above
      }
      setTransactionStep('idle');
      setWithdrawAmount('');
      setMaxAmount(null);
      onSuccess?.();
    }
  }, [isConfirmed, transactionStep, refetchAllowance, onSuccess]);

  const maxWithdrawable =
    aiusdMinted < aiusdBalance ? aiusdMinted : aiusdBalance;

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

  // Debug logging for allowance changes
  console.log('=== ALLOWANCE DEBUG ===');
  console.log('Current allowance:', allowance?.toString() || 'undefined');
  console.log('Is loading allowance:', isLoadingAllowance);
  console.log('Withdrawal amount:', withdrawAmount);
  if (maxAmount) {
    console.log('Max amount (BigInt):', maxAmount.toString());
  }
  console.log('=== END ALLOWANCE DEBUG ===');

  // Read actual position data from contract to validate state
  const { data: actualPositionData, error: positionError } = useReadContract({
    address:
      'COLLATERAL_VAULT' in contracts ? contracts.COLLATERAL_VAULT : undefined,
    abi: COLLATERAL_VAULT_ABI,
    functionName: 'getUserDepositInfo',
    args:
      address && 'COLLATERAL_VAULT' in contracts
        ? [address, BigInt(positionIndex)]
        : undefined,
    query: {
      enabled: !!address && 'COLLATERAL_VAULT' in contracts,
    },
  });

  const needsApproval = () => {
    if (!withdrawAmount) return false;

    // Use exact amount if MAX was clicked, otherwise parse the input
    const amount = maxAmount !== null ? maxAmount : parseEther(withdrawAmount);

    // If allowance is still loading, assume we need approval for safety
    if (allowance === undefined || isLoadingAllowance) {
      console.log('Allowance loading, assuming approval needed');
      return true;
    }

    console.log('Checking approval:', {
      amount: amount.toString(),
      allowance: allowance.toString(),
      needsApproval: amount > allowance,
    });

    // If allowance is loaded, check if amount exceeds allowance
    return amount > allowance;
  };

  // Validate contract state (position validity, balances, etc.) - excludes approval
  const validateContractState = () => {
    const issues = [];

    if (!actualPositionData) {
      issues.push('❌ Position not found on contract');
      return { isValid: false, issues };
    }

    if (!withdrawAmount) {
      issues.push('❌ No withdrawal amount specified');
      return { isValid: false, issues };
    }

    const amount = maxAmount !== null ? maxAmount : parseEther(withdrawAmount);

    // Check if position has pending request
    if (actualPositionData.hasPendingRequest) {
      issues.push('❌ Position has pending AI request - cannot withdraw yet');
    }

    // Check if position has sufficient minted AIUSD
    if (actualPositionData.aiusdMinted === BigInt(0)) {
      issues.push('❌ Position has no minted AIUSD to withdraw');
    } else if (amount > actualPositionData.aiusdMinted) {
      issues.push(
        `❌ Trying to withdraw ${formatTokenAmount(
          amount,
          18,
          4
        )} but position only has ${formatTokenAmount(
          actualPositionData.aiusdMinted,
          18,
          4
        )} minted`
      );
    }

    // Check user's actual AIUSD balance
    if (amount > aiusdBalance) {
      issues.push(
        `❌ Insufficient AIUSD balance: need ${formatTokenAmount(
          amount,
          18,
          4
        )} but have ${formatTokenAmount(aiusdBalance, 18, 4)}`
      );
    }

    return {
      isValid: issues.length === 0,
      issues,
      actualData: actualPositionData,
    };
  };

  // Validate full withdrawal readiness (includes approval check)
  const validateWithdrawalReadiness = () => {
    const contractValidation = validateContractState();
    const issues = [...contractValidation.issues];

    if (!contractValidation.isValid) {
      return {
        isValid: false,
        issues,
        actualData: contractValidation.actualData,
      };
    }

    const amount = maxAmount !== null ? maxAmount : parseEther(withdrawAmount);

    // Check allowance only for final withdrawal validation
    if (allowance !== undefined && amount > allowance) {
      issues.push(
        `❌ Insufficient approval: need ${formatTokenAmount(
          amount,
          18,
          4
        )} but approved ${formatTokenAmount(allowance, 18, 4)}`
      );
    }

    return {
      isValid: issues.length === 0,
      issues,
      actualData: contractValidation.actualData,
    };
  };

  const handleApprove = async () => {
    if (
      !address ||
      !withdrawAmount ||
      !('COLLATERAL_VAULT' in contracts) ||
      !contracts.COLLATERAL_VAULT
    )
      return;

    try {
      // Use exact amount if MAX was clicked, otherwise parse the input
      const amount =
        maxAmount !== null ? maxAmount : parseEther(withdrawAmount);
      setTransactionStep('approving');

      console.log('Submitting approval for amount:', amount.toString());

      await writeContract({
        address: contracts.AIUSD,
        abi: ERC20_ABI,
        functionName: 'approve',
        args: [contracts.COLLATERAL_VAULT, amount],
      });

      // Immediately try to refetch allowance after submission
      console.log('Approval submitted, refetching allowance...');
      setTimeout(() => {
        refetchAllowance();
      }, 2000); // Wait 2 seconds then refetch
    } catch (error) {
      console.error('Approval failed:', error);
      setTransactionStep('idle');
    }
  };

  const handleWithdraw = async () => {
    if (
      !address ||
      !withdrawAmount ||
      parseFloat(withdrawAmount) <= 0 ||
      !('COLLATERAL_VAULT' in contracts) ||
      !contracts.COLLATERAL_VAULT
    )
      return;

    // Validate contract state first
    const validation = validateWithdrawalReadiness();
    if (!validation.isValid) {
      const errorMessage = `Cannot withdraw due to the following issues:\n\n${validation.issues.join(
        '\n'
      )}\n\nPlease resolve these issues before withdrawing.`;
      alert(errorMessage);
      console.error('Withdrawal validation failed:', validation.issues);
      return;
    }

    try {
      // Use exact BigInt amount if MAX was clicked, otherwise parse the input
      const amount =
        maxAmount !== null ? maxAmount : parseEther(withdrawAmount);

      if (amount > maxWithdrawable) {
        alert('Amount exceeds maximum withdrawable');
        return;
      }

      // Enhanced debug logging
      console.log('=== WITHDRAWAL DEBUG ===');
      console.log('Position Index:', positionIndex);
      console.log('Withdrawal Amount:', amount.toString());
      console.log('Max Withdrawable:', maxWithdrawable.toString());
      console.log('AIUSD Balance:', aiusdBalance.toString());
      console.log('AIUSD Minted:', aiusdMinted.toString());
      console.log('Current Allowance:', allowance?.toString() || 'undefined');
      console.log('Using MAX amount:', maxAmount !== null);
      console.log('Validation passed:', validation.isValid);

      // Log actual position data from contract
      if (validation.actualData) {
        console.log('=== ACTUAL POSITION DATA ===');
        console.log(
          'Position Minted AIUSD:',
          validation.actualData.aiusdMinted.toString()
        );
        console.log(
          'Position Has Pending:',
          validation.actualData.hasPendingRequest
        );
        console.log('Position Index:', validation.actualData.index);
        console.log(
          'Position Timestamp:',
          validation.actualData.timestamp.toString()
        );
        console.log('=== END POSITION DATA ===');
      }
      console.log('=== END DEBUG ===');

      setTransactionStep('withdrawing');

      await writeContract({
        address: contracts.COLLATERAL_VAULT,
        abi: COLLATERAL_VAULT_ABI,
        functionName: 'withdrawFromPosition',
        args: [BigInt(positionIndex), amount],
      });
    } catch (error) {
      console.error('Withdraw failed:', error);
      setTransactionStep('idle');

      // More detailed error handling
      if (error instanceof Error) {
        if (error.message.includes('execution reverted')) {
          // Run validation again to show current state
          const currentValidation = validateWithdrawalReadiness();
          const validationInfo = currentValidation.isValid
            ? 'All validations passed, but contract still reverted. This may be a gas issue or internal contract error.'
            : `Validation failed: ${currentValidation.issues.join(', ')}`;

          alert(
            `Transaction failed with execution revert.\n\n${validationInfo}\n\nCheck console for full debug info.`
          );
        } else if (error.message.includes('User rejected')) {
          // User cancelled in wallet, no need to show error
        } else {
          alert(`Withdrawal failed: ${error.message}`);
        }
      }
    }
  };

  const calculateWithdrawRatio = () => {
    if (!withdrawAmount || parseFloat(withdrawAmount) <= 0 || !aiusdMinted)
      return 0;

    // Use exact amount if MAX was clicked, otherwise parse the input
    const amount = maxAmount !== null ? maxAmount : parseEther(withdrawAmount);
    const minted = aiusdMinted;

    if (minted === BigInt(0)) return 0;

    // Calculate ratio as percentage
    const ratio = Number(amount * BigInt(10000)) / Number(minted) / 100;
    return ratio;
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
            onChange={(e) => {
              setWithdrawAmount(e.target.value);
              setMaxAmount(null); // Clear max amount when user manually types
            }}
            className="w-full px-3 py-3 border-2 border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500 text-lg font-medium bg-white shadow-sm text-gray-900 placeholder-gray-400"
            step="any"
            max={formatTokenAmount(maxWithdrawable)}
          />
          <button
            onClick={() => {
              setWithdrawAmount(formatTokenAmount(maxWithdrawable));
              setMaxAmount(maxWithdrawable);
            }}
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
                {maxAmount !== null && (
                  <span className="text-xs text-green-600 ml-1">
                    (Exact MAX)
                  </span>
                )}
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
              {maxAmount !== null && (
                <span className="block mt-1 text-green-700">
                  ✨ Using exact maximum amount for complete withdrawal
                </span>
              )}
            </div>
          </div>
        </div>
      )}

      {/* Debug/Validation Info */}
      {withdrawAmount && parseFloat(withdrawAmount) > 0 && (
        <div className="bg-gray-50 border border-gray-200 rounded-lg p-3">
          <div className="text-sm font-medium text-gray-800 mb-2">
            🔍 Withdrawal Validation
          </div>
          <div className="space-y-1 text-xs">
            <div className="flex justify-between">
              <span className="text-gray-600">Position Index:</span>
              <span className="font-mono">{positionIndex}</span>
            </div>
            <div className="flex justify-between">
              <span className="text-gray-600">AIUSD Minted in Position:</span>
              <span className="font-mono">
                {formatTokenAmount(aiusdMinted, 18, 4)}
              </span>
            </div>
            <div className="flex justify-between">
              <span className="text-gray-600">Your AIUSD Balance:</span>
              <span className="font-mono">
                {formatTokenAmount(aiusdBalance, 18, 4)}
              </span>
            </div>
            <div className="flex justify-between">
              <span className="text-gray-600">Current Allowance:</span>
              <div className="flex items-center space-x-2">
                <span className="font-mono">
                  {allowance !== undefined
                    ? formatTokenAmount(allowance, 18, 4)
                    : 'Loading...'}{' '}
                  AIUSD
                </span>
                <button
                  onClick={() => {
                    console.log('Manual allowance refresh requested');
                    refetchAllowance();
                  }}
                  className="text-xs text-blue-600 hover:text-blue-800 underline"
                  title="Refresh allowance from blockchain"
                >
                  🔄
                </button>
              </div>
            </div>
            {maxAmount && (
              <div className="flex justify-between">
                <span className="text-gray-600">Exact Amount (Wei):</span>
                <span className="font-mono text-xs break-all">
                  {maxAmount.toString()}
                </span>
              </div>
            )}

            {/* Validation warnings */}
            {allowance !== undefined ? (
              <div className="mt-2 pt-2 border-t border-gray-200">
                {needsApproval() ? (
                  <div className="space-y-1">
                    <div className="text-amber-600 flex items-center">
                      <span className="mr-1">⚠️</span>
                      <span>Approval needed before withdrawal</span>
                    </div>
                    <div className="text-xs space-y-1">
                      <div className="flex justify-between">
                        <span className="text-gray-600">
                          Required approval:
                        </span>
                        <span className="font-mono text-amber-700">
                          {maxAmount !== null
                            ? formatTokenAmount(maxAmount, 18, 6)
                            : parseFloat(withdrawAmount).toFixed(6)}{' '}
                          AIUSD
                        </span>
                      </div>
                      <div className="flex justify-between">
                        <span className="text-gray-600">Current approval:</span>
                        <span className="font-mono text-gray-600">
                          {formatTokenAmount(allowance, 18, 6)} AIUSD
                        </span>
                      </div>
                    </div>
                  </div>
                ) : (
                  <div className="text-green-600 flex items-center">
                    <span className="mr-1">✅</span>
                    <span>
                      Sufficient approval ({formatTokenAmount(allowance, 18, 4)}{' '}
                      AIUSD)
                    </span>
                  </div>
                )}
              </div>
            ) : (
              <div className="mt-2 pt-2 border-t border-gray-200">
                <div className="text-blue-600 flex items-center">
                  <span className="mr-1">⏳</span>
                  <span>Loading approval status...</span>
                </div>
              </div>
            )}
          </div>
        </div>
      )}

      {/* Contract Validation Status */}
      {withdrawAmount && parseFloat(withdrawAmount) > 0 && (
        <div className="bg-slate-50 border border-slate-200 rounded-lg p-3">
          <div className="text-sm font-medium text-slate-800 mb-2 flex items-center">
            <span className="mr-2">🔍</span>
            Contract State Validation
          </div>

          {!!positionError ? (
            <div className="text-red-600 flex items-center text-sm">
              <span className="mr-1">❌</span>
              <span>Failed to load position data: {positionError.message}</span>
            </div>
          ) : !actualPositionData ? (
            <div className="text-amber-600 flex items-center text-sm">
              <span className="mr-1">⏳</span>
              <span>Loading position data from contract...</span>
            </div>
          ) : (
            (() => {
              const validation = validateContractState();
              return (
                <div className="space-y-2">
                  {validation.isValid ? (
                    <div className="text-green-600 flex items-center text-sm">
                      <span className="mr-1">✅</span>
                      <span>All contract validations passed</span>
                    </div>
                  ) : (
                    <div className="space-y-1">
                      <div className="text-red-600 flex items-center text-sm font-medium">
                        <span className="mr-1">❌</span>
                        <span>Contract validation failed</span>
                      </div>
                      <div className="space-y-1">
                        {validation.issues.map((issue, index) => (
                          <div
                            key={index}
                            className="text-xs text-red-600 pl-4"
                          >
                            {issue}
                          </div>
                        ))}
                      </div>
                    </div>
                  )}

                  {/* Position details */}
                  <div className="mt-3 pt-2 border-t border-slate-200 space-y-1 text-xs">
                    <div className="flex justify-between">
                      <span className="text-slate-600">Position Status:</span>
                      <span
                        className={`font-mono ${
                          actualPositionData.hasPendingRequest
                            ? 'text-amber-600'
                            : 'text-green-600'
                        }`}
                      >
                        {actualPositionData.hasPendingRequest
                          ? 'Pending AI'
                          : 'Active'}
                      </span>
                    </div>
                    <div className="flex justify-between">
                      <span className="text-slate-600">Position AIUSD:</span>
                      <span className="font-mono">
                        {formatTokenAmount(
                          actualPositionData.aiusdMinted,
                          18,
                          4
                        )}
                      </span>
                    </div>
                    <div className="flex justify-between">
                      <span className="text-slate-600">Position Index:</span>
                      <span className="font-mono">
                        {actualPositionData.index}
                      </span>
                    </div>
                  </div>
                </div>
              );
            })()
          )}
        </div>
      )}

      {/* Two-Step Process UI */}
      {withdrawAmount && parseFloat(withdrawAmount) > 0 && (
        <div className="bg-gradient-to-r from-amber-50 to-blue-50 border border-amber-200 rounded-lg p-4">
          <div className="text-sm font-medium text-amber-800 mb-3 flex items-center">
            <span className="mr-2">🔐</span>
            Withdrawal Process (2 Steps Required)
          </div>

          {/* Debug info for troubleshooting */}
          <div className="mb-3 text-xs text-gray-600 bg-gray-100 p-2 rounded">
            <strong>Debug Info:</strong>
            <br />
            Allowance: {allowance?.toString() || 'undefined'}
            <br />
            Needs Approval: {needsApproval().toString()}
            <br />
            Contract Valid: {validateContractState().isValid.toString()}
            <br />
            Loading Allowance: {isLoadingAllowance.toString()}
          </div>

          <div className="space-y-3">
            {/* Step 1: Approval */}
            <div
              className={`flex items-center space-x-3 p-3 rounded-lg ${
                needsApproval()
                  ? 'bg-amber-100 border border-amber-300'
                  : 'bg-green-100 border border-green-300'
              }`}
            >
              <div
                className={`w-8 h-8 rounded-full flex items-center justify-center text-sm font-bold ${
                  needsApproval()
                    ? 'bg-amber-500 text-white'
                    : 'bg-green-500 text-white'
                }`}
              >
                {needsApproval() ? '1' : '✓'}
              </div>
              <div className="flex-1">
                <div className="font-medium text-gray-800">
                  {needsApproval()
                    ? 'Approve AIUSD Spending'
                    : 'AIUSD Approved ✓'}
                </div>
                <div className="text-sm text-gray-600">
                  {needsApproval()
                    ? `Allow CollateralVault to burn ${
                        maxAmount !== null
                          ? formatTokenAmount(maxAmount, 18, 4)
                          : parseFloat(withdrawAmount).toFixed(4)
                      } AIUSD`
                    : 'Sufficient approval granted'}
                </div>
              </div>
              {needsApproval() && (
                <button
                  onClick={handleApprove}
                  disabled={
                    isPending || isConfirming || transactionStep === 'approving'
                  }
                  className="bg-amber-600 text-white px-4 py-2 rounded-lg font-medium hover:bg-amber-700 disabled:opacity-50 disabled:cursor-not-allowed transition-colors text-sm"
                >
                  {transactionStep === 'approving'
                    ? 'Approving...'
                    : isPending
                    ? 'Confirm...'
                    : 'Approve'}
                </button>
              )}
            </div>

            {/* Step 2: Withdrawal */}
            <div
              className={`flex items-center space-x-3 p-3 rounded-lg ${
                !needsApproval() && validateContractState().isValid
                  ? 'bg-blue-100 border border-blue-300'
                  : 'bg-gray-100 border border-gray-300 opacity-60'
              }`}
            >
              <div
                className={`w-8 h-8 rounded-full flex items-center justify-center text-sm font-bold ${
                  !needsApproval() && validateContractState().isValid
                    ? 'bg-blue-500 text-white'
                    : 'bg-gray-400 text-white'
                }`}
              >
                2
              </div>
              <div className="flex-1">
                <div className="font-medium text-gray-800">
                  Execute Withdrawal
                </div>
                <div className="text-sm text-gray-600">
                  Burn AIUSD and receive proportional collateral
                </div>
              </div>
              <button
                onClick={handleWithdraw}
                disabled={
                  isPending ||
                  isConfirming ||
                  needsApproval() ||
                  transactionStep === 'withdrawing' ||
                  !validateContractState().isValid ||
                  !actualPositionData ||
                  !!positionError
                }
                className="bg-red-600 text-white px-4 py-2 rounded-lg font-medium hover:bg-red-700 disabled:opacity-50 disabled:cursor-not-allowed transition-colors text-sm"
              >
                {transactionStep === 'withdrawing'
                  ? 'Withdrawing...'
                  : isPending
                  ? 'Confirm...'
                  : isConfirming
                  ? 'Confirming...'
                  : positionError
                  ? 'Position Error'
                  : !actualPositionData
                  ? 'Loading...'
                  : !validateContractState().isValid
                  ? 'Invalid Position'
                  : needsApproval()
                  ? 'Need Approval'
                  : 'Withdraw'}
              </button>
            </div>
          </div>

          {needsApproval() && (
            <div className="mt-3 text-xs text-amber-700 bg-amber-100 p-2 rounded">
              ℹ️ <strong>Why approval is needed:</strong> The CollateralVault
              contract needs permission to burn your AIUSD tokens during
              withdrawal. This is a one-time approval for this amount.
            </div>
          )}
        </div>
      )}

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
                ? '🔐 Approving AIUSD...'
                : transactionStep === 'withdrawing'
                ? '💸 Processing Withdrawal...'
                : '📤 Transaction Submitted'}
            </span>
          </div>

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

              {isConfirmed && (
                <div className="text-sm text-green-600 bg-green-50 p-2 rounded">
                  🎉 Withdrawal successful! Your collateral has been returned.
                </div>
              )}
            </div>
          )}
        </div>
      )}

      <div className="text-xs text-gray-500 text-center">
        {isConfirming
          ? 'Transaction submitted, waiting for confirmation...'
          : needsApproval()
          ? '👆 Complete Step 1 (Approve) before you can withdraw'
          : !validateContractState().isValid
          ? '❌ Position validation failed - check contract state above'
          : '✅ Ready for withdrawal - Execute Step 2 above'}
      </div>
    </div>
  );
}
