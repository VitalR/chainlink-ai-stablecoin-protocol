'use client';

import { useState } from 'react';
import {
  useAccount,
  useWriteContract,
  useReadContract,
  useChainId,
} from 'wagmi';
import { getChainContracts } from '@/lib/web3';

interface ManualProcessingProps {
  requestId: bigint;
  onSuccess?: () => void;
}

export function ManualProcessing({
  requestId,
  onSuccess,
}: ManualProcessingProps) {
  const { address } = useAccount();
  const chainId = useChainId();
  const contracts = getChainContracts(chainId);
  const { writeContract, isPending } = useWriteContract();
  const [processing, setProcessing] = useState(false);

  // Check if risk oracle controller is available on current chain
  const isControllerAvailable =
    'RISK_ORACLE_CONTROLLER' in contracts &&
    contracts.RISK_ORACLE_CONTROLLER &&
    contracts.RISK_ORACLE_CONTROLLER !== '0x';

  // Check manual processing options
  const { data: manualOptions } = useReadContract({
    address: isControllerAvailable
      ? contracts.RISK_ORACLE_CONTROLLER
      : undefined,
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
    args: isControllerAvailable ? [requestId] : undefined,
  }) as { data: [boolean, bigint, number[]] | undefined };

  const requestManualProcessing = async () => {
    if (!address || !requestId || !isControllerAvailable) return;

    try {
      setProcessing(true);
      await writeContract({
        address: contracts.RISK_ORACLE_CONTROLLER!,
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

  // Show message if controller is not available
  if (!isControllerAvailable) {
    return (
      <div className="bg-yellow-50 border border-yellow-200 rounded-lg p-4">
        <div className="flex items-center space-x-2 mb-2">
          <span className="text-yellow-600">⚠️</span>
          <span className="font-medium text-yellow-800">
            Manual Processing Not Available
          </span>
        </div>
        <p className="text-sm text-yellow-700">
          Manual processing is only available on Ethereum Sepolia where the Risk
          Oracle Controller is deployed.
        </p>
      </div>
    );
  }

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

  // Always show manual processing option, but with different messaging
  const minutes = Math.ceil(Number(timeRemaining) / 60);
  const isRecommendedTime = canProcess; // After 30+ minutes

  return (
    <div
      className={`border rounded-lg p-4 ${
        isRecommendedTime
          ? 'bg-orange-50 border-orange-200'
          : 'bg-blue-50 border-blue-200'
      }`}
    >
      <div className="flex items-center space-x-2 mb-2">
        <div
          className={`w-3 h-3 rounded-full ${
            isRecommendedTime ? 'bg-orange-400' : 'bg-blue-400 animate-pulse'
          }`}
        ></div>
        <span
          className={`font-medium ${
            isRecommendedTime ? 'text-orange-800' : 'text-blue-800'
          }`}
        >
          Manual Processing {isRecommendedTime ? 'Recommended' : 'Available'}
        </span>
      </div>

      {isRecommendedTime ? (
        <p className="text-sm text-orange-700 mb-3">
          AI request has been processing for over 30 minutes. Manual processing
          by community validators is now recommended.
        </p>
      ) : (
        <p className="text-sm text-blue-700 mb-3">
          AI is still processing (⏱️ {minutes} min remaining). You can skip the
          wait and request immediate manual processing by community validators.
        </p>
      )}

      <button
        onClick={requestManualProcessing}
        disabled={isPending || processing}
        className={`w-full text-white py-2 px-4 rounded-lg font-medium disabled:opacity-50 disabled:cursor-not-allowed transition-colors ${
          isRecommendedTime
            ? 'bg-orange-600 hover:bg-orange-700'
            : 'bg-blue-600 hover:bg-blue-700'
        }`}
      >
        {isPending || processing
          ? 'Requesting Manual Processing...'
          : isRecommendedTime
          ? 'Request Manual Processing (Recommended)'
          : 'Skip AI Wait - Manual Process Now'}
      </button>

      <div
        className={`text-xs mt-2 ${
          isRecommendedTime ? 'text-orange-600' : 'text-blue-600'
        }`}
      >
        Request ID: {requestId.toString()}
        {!isRecommendedTime && (
          <div className="mt-1 text-gray-500">
            💡 Manual processing ensures your deposit is never stuck
          </div>
        )}
      </div>
    </div>
  );
}
