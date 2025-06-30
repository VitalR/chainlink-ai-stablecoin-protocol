'use client';

import { useState } from 'react';
import { useAccount, useWriteContract, useReadContract } from 'wagmi';
import { CONTRACTS } from '@/lib/web3';

interface ManualProcessingProps {
  requestId: bigint;
  onSuccess?: () => void;
}

export function ManualProcessing({
  requestId,
  onSuccess,
}: ManualProcessingProps) {
  const { address } = useAccount();
  const { writeContract, isPending } = useWriteContract();
  const [processing, setProcessing] = useState(false);

  // Check manual processing options
  const { data: manualOptions } = useReadContract({
    address: CONTRACTS.RISK_ORACLE_CONTROLLER,
    abi: [
      {
        inputs: [
          { internalType: 'uint256', name: 'requestId', type: 'uint256' },
        ],
        name: 'getManualProcessingOptions',
        outputs: [
          { internalType: 'bool', name: 'canProcess', type: 'bool' },
          { internalType: 'uint256', name: 'timeRemaining', type: 'uint256' },
          {
            internalType: 'uint8[]',
            name: 'availableStrategies',
            type: 'uint8[]',
          },
        ],
        stateMutability: 'view',
        type: 'function',
      },
    ],
    functionName: 'getManualProcessingOptions',
    args: [requestId],
  }) as { data: [boolean, bigint, number[]] | undefined };

  const requestManualProcessing = async () => {
    if (!address || !requestId) return;

    try {
      setProcessing(true);
      await writeContract({
        address: CONTRACTS.RISK_ORACLE_CONTROLLER,
        abi: [
          {
            inputs: [
              {
                internalType: 'uint256',
                name: 'internalRequestId',
                type: 'uint256',
              },
            ],
            name: 'requestManualProcessing',
            outputs: [],
            stateMutability: 'nonpayable',
            type: 'function',
          },
        ],
        functionName: 'requestManualProcessing',
        args: [requestId],
      });
      onSuccess?.();
    } catch (error) {
      console.error('Manual processing request failed:', error);
    } finally {
      setProcessing(false);
    }
  };

  if (!manualOptions) {
    return (
      <div className="bg-gray-50 rounded-lg p-4">
        <div className="text-sm text-gray-600">
          Loading manual processing options...
        </div>
      </div>
    );
  }

  const [canProcess, timeRemaining] = manualOptions;

  if (!canProcess) {
    const minutes = Math.ceil(Number(timeRemaining) / 60);
    return (
      <div className="bg-yellow-50 border border-yellow-200 rounded-lg p-4">
        <div className="flex items-center space-x-2 mb-2">
          <div className="w-3 h-3 bg-yellow-400 rounded-full"></div>
          <span className="font-medium text-yellow-800">Waiting for AI</span>
        </div>
        <p className="text-sm text-yellow-700 mb-2">
          AI request is still processing. Manual processing will be available in{' '}
          <strong>{minutes} minutes</strong>.
        </p>
        <div className="text-xs text-yellow-600">
          Request ID: {requestId.toString()}
        </div>
      </div>
    );
  }

  return (
    <div className="bg-orange-50 border border-orange-200 rounded-lg p-4">
      <div className="flex items-center space-x-2 mb-2">
        <div className="w-3 h-3 bg-orange-400 rounded-full"></div>
        <span className="font-medium text-orange-800">
          Manual Processing Available
        </span>
      </div>
      <p className="text-sm text-orange-700 mb-3">
        AI request has been stuck for over 30 minutes. You can request manual
        processing from community validators.
      </p>
      <button
        onClick={requestManualProcessing}
        disabled={isPending || processing}
        className="w-full bg-orange-600 text-white py-2 px-4 rounded-lg font-medium hover:bg-orange-700 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
      >
        {isPending || processing
          ? 'Requesting Manual Processing...'
          : 'Request Manual Processing'}
      </button>
      <div className="text-xs text-orange-600 mt-2">
        Request ID: {requestId.toString()}
      </div>
    </div>
  );
}
