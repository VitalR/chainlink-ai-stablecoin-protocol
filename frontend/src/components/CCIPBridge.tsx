'use client';

import { useState, useMemo, useEffect } from 'react';
import {
  useAccount,
  useWriteContract,
  useReadContract,
  useChainId,
  useSwitchChain,
  useWaitForTransactionReceipt,
} from 'wagmi';
import {
  AI_STABLECOIN_ABI,
  CCIP_BRIDGE_ABI,
  ERC20_ABI,
  formatTokenAmount,
  parseTokenAmount,
  getChainContracts,
  getChainName,
  getChainSelector,
  PayFeesIn,
} from '@/lib/web3';

// Use infinite approval for best UX
const MAX_UINT256 = BigInt(
  '0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff'
);

export function CCIPBridge() {
  const { address } = useAccount();
  const chainId = useChainId();
  const { switchChain } = useSwitchChain();
  const contracts = getChainContracts(chainId);
  const { writeContract, isPending, data: hash } = useWriteContract();

  const [bridgeAmount, setBridgeAmount] = useState('');
  const [payFeesIn, setPayFeesIn] = useState<PayFeesIn>(PayFeesIn.Native);
  const [recipient, setRecipient] = useState('');
  const [transactionStep, setTransactionStep] = useState<
    'idle' | 'approving' | 'bridging'
  >('idle');

  // Wait for transaction confirmation
  const {
    isLoading: isConfirming,
    isSuccess: isConfirmed,
    error: confirmError,
  } = useWaitForTransactionReceipt({
    hash,
  });

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

  // Determine destination chain
  const destinationChainId = chainId === 11155111 ? 43113 : 11155111; // Sepolia <-> Fuji
  const destinationChainName = getChainName(destinationChainId);
  const destinationChainSelector = getChainSelector(destinationChainId);

  // Read AIUSD balance on current chain
  const { data: aiusdBalance } = useReadContract({
    address: contracts.AIUSD,
    abi: AI_STABLECOIN_ABI,
    functionName: 'balanceOf',
    args: address ? [address] : undefined,
  }) as { data: bigint | undefined };

  // Read AIUSD allowance for bridge contract
  const { data: allowance, refetch: refetchAllowance } = useReadContract({
    address: contracts.AIUSD,
    abi: ERC20_ABI,
    functionName: 'allowance',
    args:
      address && contracts.CCIP_BRIDGE
        ? [address, contracts.CCIP_BRIDGE]
        : undefined,
  }) as { data: bigint | undefined; refetch: () => void };

  // Calculate bridge fee using calculateBridgeFees
  const amount = useMemo(
    () => parseTokenAmount(bridgeAmount || '0', 18),
    [bridgeAmount]
  );
  const { data: estimatedFee, isLoading: isFeeLoading } = useReadContract({
    address: contracts.CCIP_BRIDGE,
    abi: CCIP_BRIDGE_ABI,
    functionName: 'calculateBridgeFees',
    args:
      bridgeAmount && parseFloat(bridgeAmount) > 0
        ? [destinationChainSelector, amount, payFeesIn]
        : undefined,
    query: {
      enabled:
        !!contracts.CCIP_BRIDGE &&
        !!bridgeAmount &&
        parseFloat(bridgeAmount) > 0,
      staleTime: 30 * 1000, // 30 seconds
    },
  });

  // Handle transaction confirmation properly (moved after all hooks are declared)
  useEffect(() => {
    if (isConfirmed && transactionStep !== 'idle') {
      console.log('Transaction confirmed, step:', transactionStep);

      if (transactionStep === 'approving') {
        console.log('Approval confirmed, refetching allowance...');
        // Refetch allowance after approval
        refetchAllowance();
        // Reset state after a short delay to allow allowance to update
        setTimeout(() => {
          setTransactionStep('idle');
        }, 1000);
      } else if (transactionStep === 'bridging') {
        console.log('Bridge confirmed, resetting form...');
        setTransactionStep('idle');
        setBridgeAmount('');
        setRecipient('');
      }
    }
  }, [isConfirmed, transactionStep, refetchAllowance]);

  const needsApproval = () => {
    if (!bridgeAmount || !allowance) return false;
    const amount = parseTokenAmount(bridgeAmount, 18);
    return amount > allowance;
  };

  const handleApprove = async () => {
    if (!address || !bridgeAmount || !contracts.CCIP_BRIDGE) return;

    try {
      setTransactionStep('approving');
      // Infinite approval for best UX
      await writeContract({
        address: contracts.AIUSD,
        abi: ERC20_ABI,
        functionName: 'approve',
        args: [contracts.CCIP_BRIDGE, MAX_UINT256],
      });
    } catch (error) {
      console.error('Approval failed:', error);
      setTransactionStep('idle');

      if (error instanceof Error) {
        if (error.message.includes('User rejected')) {
          // User cancelled, no need to show error
        } else {
          alert(`Approval failed: ${error.message}`);
        }
      }
    }
  };

  const handleBridge = async () => {
    if (!address || !bridgeAmount || !contracts.CCIP_BRIDGE) return;

    const bridgeRecipient = recipient || address;
    const amount = parseTokenAmount(bridgeAmount, 18);

    // Validation to prevent InvalidAmount error
    if (amount <= 0) {
      alert('Please enter a valid amount greater than 0');
      return;
    }

    // Double-check allowance before bridging to prevent race conditions
    if (!allowance || amount > allowance) {
      alert('Insufficient allowance. Please approve tokens first.');
      console.error('Bridge blocked: Insufficient allowance', {
        amount: amount.toString(),
        allowance: allowance?.toString() || '0',
      });
      return;
    }

    // Check if we have the estimated fee for native payment
    if (payFeesIn === PayFeesIn.Native && !estimatedFee) {
      alert('Unable to calculate bridge fee. Please try again.');
      return;
    }

    try {
      setTransactionStep('bridging');
      console.log('Bridge transaction details:', {
        destinationChainSelector: destinationChainSelector.toString(),
        recipient: bridgeRecipient,
        amount: amount.toString(),
        allowance: allowance.toString(),
        payFeesIn,
        estimatedFee: estimatedFee?.toString(),
      });

      await writeContract({
        address: contracts.CCIP_BRIDGE,
        abi: CCIP_BRIDGE_ABI,
        functionName: 'bridgeTokens',
        args: [
          destinationChainSelector,
          bridgeRecipient as `0x${string}`,
          amount,
          payFeesIn,
        ],
        // Use the actual calculated fee instead of hardcoded 0.01 ETH
        value:
          payFeesIn === PayFeesIn.Native && estimatedFee
            ? estimatedFee
            : undefined,
      });
    } catch (error) {
      console.error('Bridge failed:', error);
      setTransactionStep('idle');

      // Better error handling
      if (error instanceof Error) {
        if (error.message.includes('InvalidAmount')) {
          alert(
            `Invalid amount error. Amount: ${amount.toString()}, Allowance: ${
              allowance?.toString() || '0'
            }`
          );
        } else if (error.message.includes('User rejected')) {
          // User cancelled, no need to show error
        } else {
          alert(`Bridge failed: ${error.message}`);
        }
      }
    }
  };

  const handleSwitchChain = () => {
    switchChain({ chainId: destinationChainId });
  };

  // Check if bridge is available on current chain
  const isBridgeAvailable =
    contracts.CCIP_BRIDGE && contracts.CCIP_BRIDGE !== '0x';

  if (!isBridgeAvailable) {
    return (
      <div className="bg-yellow-50 border border-yellow-200 rounded-lg p-6">
        <div className="flex items-center space-x-2 mb-2">
          <span className="text-yellow-600">⚠️</span>
          <span className="font-medium text-yellow-800">
            Bridge Not Available
          </span>
        </div>
        <p className="text-sm text-yellow-700 mb-4">
          CCIP Bridge is not deployed on this network. Switch to Sepolia or
          Avalanche Fuji to use the bridge.
        </p>
        <button
          onClick={handleSwitchChain}
          className="bg-yellow-600 text-white px-4 py-2 rounded-lg font-medium hover:bg-yellow-700 transition-colors"
        >
          Switch to {destinationChainName}
        </button>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      {/* Bridge Header */}
      <div className="bg-gradient-to-r from-indigo-50 to-purple-50 rounded-lg p-4 border border-indigo-200">
        <div className="flex items-center space-x-2 mb-2">
          <span className="text-2xl">🌉</span>
          <h3 className="text-lg font-bold text-gray-900">
            Cross-Chain Bridge
          </h3>
        </div>
        <p className="text-sm text-gray-600">
          Bridge your AIUSD tokens between Ethereum Sepolia and Avalanche Fuji
          using Chainlink CCIP
        </p>
      </div>

      {/* Current Chain Info */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        <div className="bg-white rounded-lg border p-4">
          <div className="text-sm text-gray-600 mb-1">From (Current)</div>
          <div className="flex items-center space-x-2">
            <span className="text-lg">{chainId === 43113 ? '❄️' : '🌐'}</span>
            <span className="font-semibold text-gray-900">
              {getChainName(chainId)}
            </span>
          </div>
          <div className="text-sm text-gray-700 mt-2">
            Balance:{' '}
            <span className="font-semibold text-blue-600">
              {aiusdBalance ? formatTokenAmount(aiusdBalance, 18, 4) : '0'}{' '}
              AIUSD
            </span>
          </div>
        </div>

        <div className="bg-blue-50 rounded-lg border border-blue-200 p-4">
          <div className="text-sm text-gray-600 mb-1">To (Destination)</div>
          <div className="flex items-center space-x-2">
            <span className="text-lg">
              {destinationChainId === 43113 ? '❄️' : '🌐'}
            </span>
            <span className="font-semibold text-gray-900">
              {destinationChainName}
            </span>
          </div>
          <button
            onClick={handleSwitchChain}
            className="text-sm text-blue-600 hover:text-blue-700 font-medium mt-2"
          >
            Switch Network →
          </button>
        </div>
      </div>

      {/* Bridge Form */}
      <div className="space-y-4">
        {/* Amount Input */}
        <div>
          <label className="block text-sm font-medium text-gray-700 mb-2">
            Amount to Bridge
          </label>
          <div className="relative">
            <input
              type="number"
              placeholder="0.0"
              value={bridgeAmount}
              onChange={(e) => {
                const value = e.target.value;
                // Prevent negative values and ensure reasonable precision
                if (
                  value === '' ||
                  (!isNaN(Number(value)) && Number(value) >= 0)
                ) {
                  setBridgeAmount(value);
                }
              }}
              className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500 text-gray-900 font-medium"
              step="any"
              min="0"
              max={aiusdBalance ? formatTokenAmount(aiusdBalance, 18) : '0'}
            />
            <div className="absolute inset-y-0 right-0 flex items-center">
              <button
                onClick={() =>
                  setBridgeAmount(
                    aiusdBalance ? formatTokenAmount(aiusdBalance, 18) : '0'
                  )
                }
                className="mr-3 text-xs bg-indigo-600 text-white px-2 py-1 rounded hover:bg-indigo-700 font-medium"
              >
                MAX
              </button>
              <div className="pr-3 text-sm font-medium text-gray-500">
                AIUSD
              </div>
            </div>
          </div>
          <div className="text-sm text-gray-600 mt-1">
            Available:{' '}
            <span className="font-semibold text-gray-900">
              {aiusdBalance ? formatTokenAmount(aiusdBalance, 18, 4) : '0'}{' '}
              AIUSD
            </span>
          </div>
          {/* Debug info for amount validation */}
          {bridgeAmount && parseFloat(bridgeAmount) > 0 && (
            <div className="text-xs text-gray-500 mt-1 space-y-1">
              <div>
                Parsed amount: {parseTokenAmount(bridgeAmount, 18).toString()}
              </div>
              <div>Current allowance: {allowance?.toString() || '0'}</div>
              <div>Needs approval: {needsApproval() ? 'Yes' : 'No'}</div>
              <div>Transaction step: {transactionStep}</div>
            </div>
          )}
        </div>

        {/* Recipient Address (Optional) */}
        <div>
          <label className="block text-sm font-medium text-gray-700 mb-2">
            Recipient Address (Optional)
          </label>
          <input
            type="text"
            placeholder={address || '0x...'}
            value={recipient}
            onChange={(e) => setRecipient(e.target.value)}
            className="w-full px-3 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500"
          />
          <div className="text-sm text-gray-500 mt-1">
            Leave empty to send to your own address
          </div>
        </div>

        {/* Fee Payment Method */}
        <div>
          <label className="block text-sm font-medium text-gray-700 mb-2">
            Pay Bridge Fees With
          </label>
          <div className="grid grid-cols-2 gap-2">
            <button
              onClick={() => setPayFeesIn(PayFeesIn.Native)}
              className={`px-4 py-2 rounded-lg font-medium transition-colors ${
                payFeesIn === PayFeesIn.Native
                  ? 'bg-indigo-600 text-white'
                  : 'bg-gray-100 text-gray-700 hover:bg-gray-200'
              }`}
            >
              {chainId === 43113 ? 'AVAX' : 'ETH'}
            </button>
            <button
              onClick={() => setPayFeesIn(PayFeesIn.LINK)}
              className={`px-4 py-2 rounded-lg font-medium transition-colors ${
                payFeesIn === PayFeesIn.LINK
                  ? 'bg-indigo-600 text-white'
                  : 'bg-gray-100 text-gray-700 hover:bg-gray-200'
              }`}
            >
              LINK
            </button>
          </div>
        </div>
      </div>

      {/* Bridge Summary */}
      {bridgeAmount && parseFloat(bridgeAmount) > 0 && (
        <div className="bg-indigo-50 border border-indigo-200 rounded-lg p-4">
          <div className="text-sm font-medium text-indigo-800 mb-3">
            Bridge Transaction Summary:
          </div>
          <div className="space-y-2 text-sm">
            <div className="flex justify-between items-center">
              <span className="text-gray-700">Amount:</span>
              <span className="text-gray-900 font-semibold">
                {parseFloat(bridgeAmount).toFixed(4)} AIUSD
              </span>
            </div>
            <div className="flex justify-between items-center">
              <span className="text-gray-700">From:</span>
              <span className="text-gray-900 font-semibold">
                {getChainName(chainId)}
              </span>
            </div>
            <div className="flex justify-between items-center">
              <span className="text-gray-700">To:</span>
              <span className="text-gray-900 font-semibold">
                {destinationChainName}
              </span>
            </div>
            <div className="flex justify-between items-center">
              <span className="text-gray-700">Recipient:</span>
              <span className="text-gray-900 font-mono text-xs font-semibold">
                {(recipient || address)?.slice(0, 6)}...
                {(recipient || address)?.slice(-4)}
              </span>
            </div>
            <div className="flex justify-between items-center">
              <span className="text-gray-700">Fee Payment:</span>
              <span className="text-gray-900 font-semibold">
                {payFeesIn === PayFeesIn.Native
                  ? chainId === 43113
                    ? 'AVAX'
                    : 'ETH'
                  : 'LINK'}
              </span>
            </div>
            <div className="flex justify-between items-center">
              <span className="text-gray-700">Estimated Bridge Fee:</span>
              <span
                className={`font-semibold ${
                  isFeeLoading
                    ? 'text-yellow-600'
                    : estimatedFee
                    ? 'text-gray-900'
                    : 'text-red-600'
                }`}
              >
                {isFeeLoading
                  ? 'Calculating...'
                  : estimatedFee
                  ? payFeesIn === PayFeesIn.Native
                    ? `${parseFloat(
                        (Number(estimatedFee) / 1e18).toFixed(6)
                      )} ${chainId === 43113 ? 'AVAX' : 'ETH'}`
                    : `${parseFloat(
                        (Number(estimatedFee) / 1e18).toFixed(6)
                      )} LINK`
                  : 'Failed to calculate'}
              </span>
            </div>
          </div>

          {/* Fee calculation warning */}
          {payFeesIn === PayFeesIn.Native && !isFeeLoading && !estimatedFee && (
            <div className="mt-3 p-2 bg-yellow-100 border border-yellow-300 rounded text-xs text-yellow-800">
              ⚠️ Unable to calculate bridge fee. The transaction may fail or use
              incorrect fee amount.
            </div>
          )}
        </div>
      )}

      {/* Bridge Actions */}
      <div className="space-y-2">
        {needsApproval() ? (
          <button
            onClick={handleApprove}
            disabled={
              isPending ||
              isConfirming ||
              transactionStep === 'approving' ||
              !bridgeAmount ||
              parseFloat(bridgeAmount) <= 0
            }
            className="w-full bg-blue-600 text-white py-3 px-4 rounded-lg font-medium hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
          >
            {transactionStep === 'approving'
              ? 'Approving...'
              : isPending
              ? 'Confirm...'
              : 'Approve AIUSD'}
          </button>
        ) : (
          <button
            onClick={handleBridge}
            disabled={
              isPending ||
              isConfirming ||
              transactionStep === 'bridging' ||
              !bridgeAmount ||
              parseFloat(bridgeAmount) <= 0 ||
              (payFeesIn === PayFeesIn.Native && !estimatedFee && !isFeeLoading)
            }
            className="w-full bg-gradient-to-r from-indigo-600 to-purple-600 text-white py-3 px-4 rounded-lg font-medium hover:from-indigo-700 hover:to-purple-700 disabled:opacity-50 disabled:cursor-not-allowed transition-all"
          >
            {transactionStep === 'bridging'
              ? 'Bridging...'
              : isPending
              ? 'Confirm...'
              : isConfirming
              ? 'Confirming...'
              : isFeeLoading
              ? 'Calculating Fee...'
              : payFeesIn === PayFeesIn.Native && !estimatedFee
              ? 'Fee Calculation Failed'
              : `Bridge to ${destinationChainName}`}
          </button>
        )}
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
                ? transactionStep === 'approving'
                  ? '✅ Approval Confirmed'
                  : '✅ Bridge Transaction Confirmed'
                : confirmError
                ? '❌ Transaction Failed'
                : isConfirming
                ? '⏳ Confirming Transaction...'
                : transactionStep === 'approving'
                ? '🔐 Approving AIUSD...'
                : transactionStep === 'bridging'
                ? '🌉 Processing Bridge...'
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

              {isConfirmed && transactionStep === 'bridging' && (
                <div className="text-sm text-green-600 bg-green-50 p-2 rounded">
                  🎉 Bridge transaction successful! Your AIUSD is being
                  transferred to {destinationChainName}.
                  <br />
                  <span className="text-xs text-green-700">
                    Note: Cross-chain transfers may take a few minutes to
                    complete.
                  </span>
                </div>
              )}

              {isConfirmed && transactionStep === 'approving' && (
                <div className="text-sm text-blue-600 bg-blue-50 p-2 rounded">
                  ✅ Approval successful! You can now proceed with the bridge.
                </div>
              )}
            </div>
          )}
        </div>
      )}

      {/* Bridge Info */}
      <div className="text-xs text-gray-500 text-center space-y-1">
        <p>🔒 Powered by Chainlink CCIP for secure cross-chain transfers</p>
        <p>
          ⚡ Tokens are burned on source chain and minted on destination chain
        </p>
        <p>🌐 Bridge transactions can be tracked on CCIP Explorer</p>
      </div>
    </div>
  );
}
