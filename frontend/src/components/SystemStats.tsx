'use client';

import { useReadContract, useChainId } from 'wagmi';
import {
  AI_STABLECOIN_ABI,
  formatTokenAmount,
  getChainContracts,
  getChainName,
} from '@/lib/web3';

export function SystemStats() {
  const chainId = useChainId();
  const contracts = getChainContracts(chainId);
  const currentChainName = getChainName(chainId);

  // Read total supply
  const { data: totalSupply } = useReadContract({
    address: contracts.AIUSD,
    abi: AI_STABLECOIN_ABI,
    functionName: 'totalSupply',
  }) as { data: bigint | undefined };

  const stats = [
    {
      label: 'Total AIUSD Supply',
      value: totalSupply
        ? `${formatTokenAmount(totalSupply, 18, 4)} AIUSD`
        : '0 AIUSD',
      icon: '💰',
      color: 'text-green-600',
    },
    {
      label: 'AI Engine',
      value: 'Amazon Bedrock + Chainlink',
      icon: '🤖',
      color: 'text-blue-600',
    },
    {
      label: 'Current Network',
      value: currentChainName,
      icon: chainId === 43113 ? '❄️' : '🌐',
      color: chainId === 43113 ? 'text-blue-600' : 'text-purple-600',
    },
    {
      label: 'Cross-Chain Status',
      value: 'CCIP Bridge Active',
      icon: '🌉',
      color: 'text-indigo-600',
    },
  ];

  return (
    <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
      {stats.map((stat, index) => (
        <div
          key={index}
          className="bg-white rounded-xl shadow-lg p-6 border border-gray-100 hover:shadow-xl transition-shadow"
        >
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-medium text-gray-600">{stat.label}</p>
              <p className={`text-lg font-bold ${stat.color}`}>{stat.value}</p>
              {stat.label === 'Current Network' && chainId === 11155111 && (
                <p className="text-xs text-gray-500 mt-1">AI Analysis Chain</p>
              )}
              {stat.label === 'Current Network' && chainId === 43113 && (
                <p className="text-xs text-gray-500 mt-1">Execution Chain</p>
              )}
            </div>
            <div className="text-2xl">{stat.icon}</div>
          </div>
        </div>
      ))}
    </div>
  );
}
