'use client';

import { useReadContract } from 'wagmi';
import { CONTRACTS, AI_STABLECOIN_ABI, formatTokenAmount } from '@/lib/web3';

export function SystemStats() {
  // Read total supply
  const { data: totalSupply } = useReadContract({
    address: CONTRACTS.AI_STABLECOIN,
    abi: AI_STABLECOIN_ABI,
    functionName: 'totalSupply',
  }) as { data: bigint | undefined };

  const stats = [
    {
      label: 'Total AIUSD Supply',
      value: totalSupply
        ? `${formatTokenAmount(totalSupply)} AIUSD`
        : '0 AIUSD',
      icon: '💰',
      color: 'text-green-600',
    },
    {
      label: 'AI Oracle',
      value: 'ORA Network',
      icon: '🤖',
      color: 'text-blue-600',
    },
    {
      label: 'Network',
      value: 'Sepolia Testnet',
      icon: '🌐',
      color: 'text-purple-600',
    },
    {
      label: 'Status',
      value: 'Active',
      icon: '✅',
      color: 'text-green-600',
    },
  ];

  return (
    <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
      {stats.map((stat, index) => (
        <div
          key={index}
          className="bg-white rounded-xl shadow-lg p-6 border border-gray-100"
        >
          <div className="flex items-center justify-between">
            <div>
              <p className="text-sm font-medium text-gray-600">{stat.label}</p>
              <p className={`text-lg font-bold ${stat.color}`}>{stat.value}</p>
            </div>
            <div className="text-2xl">{stat.icon}</div>
          </div>
        </div>
      ))}
    </div>
  );
}
