'use client';

import { useState } from 'react';
import { ConnectButton } from '@rainbow-me/rainbowkit';
import { useAccount, useChainId } from 'wagmi';
import { DepositForm } from '@/components/DepositForm';
import { UserPosition } from '@/components/UserPosition';
import { SystemStats } from '@/components/SystemStats';
import { CCIPBridge } from '@/components/CCIPBridge';
import { getChainName } from '@/lib/web3';

type TabType = 'deposit' | 'bridge' | 'position';

export default function Home() {
  const { isConnected } = useAccount();
  const chainId = useChainId();
  const [activeTab, setActiveTab] = useState<TabType>('deposit');

  const tabs = [
    { id: 'deposit' as TabType, label: 'Deposit & Mint', icon: '💰' },
    { id: 'bridge' as TabType, label: 'Cross-Chain Bridge', icon: '🌉' },
    { id: 'position' as TabType, label: 'Your Positions', icon: '📊' },
  ];

  const renderTabContent = () => {
    switch (activeTab) {
      case 'deposit':
        return (
          <div className="bg-white rounded-2xl shadow-xl p-6">
            <h3 className="text-2xl font-bold text-gray-900 mb-6 flex items-center">
              <span className="mr-3">💰</span>
              Deposit Collateral & Mint AIUSD
            </h3>
            <DepositForm />
          </div>
        );
      case 'bridge':
        return (
          <div className="bg-white rounded-2xl shadow-xl p-6">
            <h3 className="text-2xl font-bold text-gray-900 mb-6 flex items-center">
              <span className="mr-3">🌉</span>
              Cross-Chain Bridge
            </h3>
            <CCIPBridge />
          </div>
        );
      case 'position':
        return (
          <div className="bg-white rounded-2xl shadow-xl p-6">
            <h3 className="text-2xl font-bold text-gray-900 mb-6 flex items-center">
              <span className="mr-3">📊</span>
              Your Positions
            </h3>
            <UserPosition />
          </div>
        );
      default:
        return null;
    }
  };

  return (
    <div className="min-h-screen bg-gradient-to-br from-blue-50 via-white to-purple-50">
      {/* Header */}
      <header className="border-b bg-white/80 backdrop-blur-sm sticky top-0 z-10">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex justify-between items-center h-16">
            <div className="flex items-center space-x-3">
              <div className="w-8 h-8 bg-gradient-to-r from-blue-600 to-purple-600 rounded-lg flex items-center justify-center">
                <span className="text-white font-bold text-sm">AI</span>
              </div>
              <h1 className="text-xl font-bold text-gray-900">AI Stablecoin</h1>
              {isConnected && (
                <div className="hidden sm:flex items-center space-x-2 ml-4">
                  <span className="text-sm text-gray-500">Network:</span>
                  <span className="text-sm font-medium text-blue-600 bg-blue-50 px-2 py-1 rounded-full">
                    {chainId === 43113 ? '❄️' : '🌐'} {getChainName(chainId)}
                  </span>
                </div>
              )}
            </div>
            <ConnectButton />
          </div>
        </div>
      </header>

      {/* Main Content */}
      <main className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        {/* Hero Section */}
        <div className="text-center mb-12">
          <h2 className="text-4xl font-bold text-gray-900 mb-4">
            AI-Powered Cross-Chain Stablecoin
          </h2>
          <p className="text-xl text-gray-600 max-w-4xl mx-auto">
            Deposit diversified collateral on Sepolia, leverage Amazon Bedrock
            AI for optimal minting ratios, and bridge your AIUSD to Avalanche
            Fuji for fast, low-cost DeFi execution.
          </p>
        </div>

        {/* System Stats */}
        <div className="mb-8">
          <SystemStats />
        </div>

        {isConnected ? (
          <div className="space-y-8">
            {/* Tab Navigation */}
            <div className="bg-white rounded-2xl shadow-xl p-2">
              <div className="flex space-x-1">
                {tabs.map((tab) => (
                  <button
                    key={tab.id}
                    onClick={() => setActiveTab(tab.id)}
                    className={`flex-1 flex items-center justify-center space-x-2 py-3 px-4 rounded-xl font-medium transition-all ${
                      activeTab === tab.id
                        ? 'bg-gradient-to-r from-blue-600 to-purple-600 text-white shadow-lg'
                        : 'text-gray-600 hover:text-gray-900 hover:bg-gray-50'
                    }`}
                  >
                    <span className="text-lg">{tab.icon}</span>
                    <span className="hidden sm:block">{tab.label}</span>
                  </button>
                ))}
              </div>
            </div>

            {/* Tab Content */}
            <div className="min-h-[600px]">{renderTabContent()}</div>

            {/* Network-specific Info */}
            <div className="bg-gradient-to-r from-gray-50 to-blue-50 rounded-2xl p-6 border border-gray-200">
              <h4 className="text-lg font-semibold text-gray-900 mb-3">
                {chainId === 43113
                  ? '❄️ Avalanche Fuji Features'
                  : '🌐 Ethereum Sepolia Features'}
              </h4>
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                {chainId === 43113 ? (
                  <>
                    <div className="flex items-start space-x-3">
                      <span className="text-xl mt-1">⚡</span>
                      <div>
                        <div className="font-medium text-gray-900">
                          Fast Execution
                        </div>
                        <div className="text-sm text-gray-600">
                          ~2 second block times for quick DeFi operations
                        </div>
                      </div>
                    </div>
                    <div className="flex items-start space-x-3">
                      <span className="text-xl mt-1">💸</span>
                      <div>
                        <div className="font-medium text-gray-900">
                          Low Fees
                        </div>
                        <div className="text-sm text-gray-600">
                          Minimal transaction costs with AVAX
                        </div>
                      </div>
                    </div>
                  </>
                ) : (
                  <>
                    <div className="flex items-start space-x-3">
                      <span className="text-xl mt-1">🤖</span>
                      <div>
                        <div className="font-medium text-gray-900">
                          AI Analysis
                        </div>
                        <div className="text-sm text-gray-600">
                          Amazon Bedrock AI determines optimal collateral ratios
                        </div>
                      </div>
                    </div>
                    <div className="flex items-start space-x-3">
                      <span className="text-xl mt-1">🔗</span>
                      <div>
                        <div className="font-medium text-gray-900">
                          Chainlink Integration
                        </div>
                        <div className="text-sm text-gray-600">
                          Functions, Data Feeds, CCIP, and Automation
                        </div>
                      </div>
                    </div>
                  </>
                )}
              </div>
            </div>
          </div>
        ) : (
          <div className="flex items-center justify-center min-h-[60vh]">
            <div className="text-center py-12">
              <div className="bg-white rounded-2xl shadow-xl p-12 max-w-lg mx-auto">
                <div className="w-20 h-20 bg-gradient-to-r from-blue-600 to-purple-600 rounded-full flex items-center justify-center mx-auto mb-6">
                  <span className="text-white text-3xl">🔗</span>
                </div>
                <h3 className="text-2xl font-bold text-gray-900 mb-3">
                  Connect Your Wallet
                </h3>
                <p className="text-gray-600 mb-8 text-lg">
                  Connect your wallet to start using AI Stablecoin and
                  experience intelligent cross-chain collateral management
                </p>
                <div className="flex justify-center">
                  <ConnectButton />
                </div>
                <div className="mt-6 text-sm text-gray-500">
                  Supports Ethereum Sepolia and Avalanche Fuji testnets
                </div>
              </div>
            </div>
          </div>
        )}

        {/* Features */}
        <div className="mt-16 grid grid-cols-1 md:grid-cols-4 gap-8">
          <div className="text-center p-6">
            <div className="w-12 h-12 bg-blue-100 rounded-lg flex items-center justify-center mx-auto mb-4">
              <span className="text-2xl">🤖</span>
            </div>
            <h4 className="text-lg font-semibold text-gray-900 mb-2">
              AI-Powered
            </h4>
            <p className="text-gray-600">
              Amazon Bedrock AI analyzes your portfolio for optimal collateral
              ratios (125-200%)
            </p>
          </div>

          <div className="text-center p-6">
            <div className="w-12 h-12 bg-purple-100 rounded-lg flex items-center justify-center mx-auto mb-4">
              <span className="text-2xl">🌉</span>
            </div>
            <h4 className="text-lg font-semibold text-gray-900 mb-2">
              Cross-Chain
            </h4>
            <p className="text-gray-600">
              Seamless AIUSD transfers between Sepolia and Fuji via Chainlink
              CCIP
            </p>
          </div>

          <div className="text-center p-6">
            <div className="w-12 h-12 bg-green-100 rounded-lg flex items-center justify-center mx-auto mb-4">
              <span className="text-2xl">🏢</span>
            </div>
            <h4 className="text-lg font-semibold text-gray-900 mb-2">
              RWA Support
            </h4>
            <p className="text-gray-600">
              Deposit real-world assets like OUSG alongside crypto collateral
            </p>
          </div>

          <div className="text-center p-6">
            <div className="w-12 h-12 bg-indigo-100 rounded-lg flex items-center justify-center mx-auto mb-4">
              <span className="text-2xl">⚡</span>
            </div>
            <h4 className="text-lg font-semibold text-gray-900 mb-2">
              Efficient
            </h4>
            <p className="text-gray-600">
              Reward portfolio diversification with lower collateral
              requirements
            </p>
          </div>
        </div>
      </main>
    </div>
  );
}
