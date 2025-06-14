'use client';

import { ConnectButton } from '@rainbow-me/rainbowkit';
import { useAccount } from 'wagmi';
import { DepositForm } from '@/components/DepositForm';
import { UserPosition } from '@/components/UserPosition';
import { SystemStats } from '@/components/SystemStats';

export default function Home() {
  const { isConnected } = useAccount();

  return (
    <div className="min-h-screen bg-gradient-to-br from-blue-50 via-white to-purple-50">
      {/* Header */}
      <header className="border-b bg-white/80 backdrop-blur-sm">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex justify-between items-center h-16">
            <div className="flex items-center space-x-3">
              <div className="w-8 h-8 bg-gradient-to-r from-blue-600 to-purple-600 rounded-lg flex items-center justify-center">
                <span className="text-white font-bold text-sm">AI</span>
              </div>
              <h1 className="text-xl font-bold text-gray-900">AI Stablecoin</h1>
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
            AI-Powered Stablecoin
          </h2>
          <p className="text-xl text-gray-600 max-w-3xl mx-auto">
            Deposit collateral and let AI determine optimal minting ratios.
            Experience the future of decentralized finance with intelligent
            automation.
          </p>
        </div>

        {/* System Stats */}
        <div className="mb-8">
          <SystemStats />
        </div>

        {isConnected ? (
          <div className="grid grid-cols-1 lg:grid-cols-2 gap-8">
            {/* Deposit Form */}
            <div className="bg-white rounded-2xl shadow-xl p-6">
              <h3 className="text-2xl font-bold text-gray-900 mb-6">
                Deposit Collateral
              </h3>
              <DepositForm />
            </div>

            {/* User Position */}
            <div className="bg-white rounded-2xl shadow-xl p-6">
              <h3 className="text-2xl font-bold text-gray-900 mb-6">
                Your Position
              </h3>
              <UserPosition />
            </div>
          </div>
        ) : (
          <div className="text-center py-12">
            <div className="bg-white rounded-2xl shadow-xl p-8 max-w-md mx-auto">
              <div className="w-16 h-16 bg-gradient-to-r from-blue-600 to-purple-600 rounded-full flex items-center justify-center mx-auto mb-4">
                <span className="text-white text-2xl">🔗</span>
              </div>
              <h3 className="text-xl font-semibold text-gray-900 mb-2">
                Connect Your Wallet
              </h3>
              <p className="text-gray-600 mb-6">
                Connect your wallet to start using AI Stablecoin
              </p>
              <ConnectButton />
            </div>
          </div>
        )}

        {/* Features */}
        <div className="mt-16 grid grid-cols-1 md:grid-cols-3 gap-8">
          <div className="text-center p-6">
            <div className="w-12 h-12 bg-blue-100 rounded-lg flex items-center justify-center mx-auto mb-4">
              <span className="text-2xl">🤖</span>
            </div>
            <h4 className="text-lg font-semibold text-gray-900 mb-2">
              AI-Powered
            </h4>
            <p className="text-gray-600">
              Advanced AI algorithms determine optimal collateral ratios for
              maximum efficiency
            </p>
          </div>

          <div className="text-center p-6">
            <div className="w-12 h-12 bg-purple-100 rounded-lg flex items-center justify-center mx-auto mb-4">
              <span className="text-2xl">🔒</span>
            </div>
            <h4 className="text-lg font-semibold text-gray-900 mb-2">Secure</h4>
            <p className="text-gray-600">
              Multi-token collateral support with emergency withdrawal
              mechanisms
            </p>
          </div>

          <div className="text-center p-6">
            <div className="w-12 h-12 bg-green-100 rounded-lg flex items-center justify-center mx-auto mb-4">
              <span className="text-2xl">⚡</span>
            </div>
            <h4 className="text-lg font-semibold text-gray-900 mb-2">
              Efficient
            </h4>
            <p className="text-gray-600">
              Dynamic pricing and automated processing for optimal user
              experience
            </p>
          </div>
        </div>
      </main>
    </div>
  );
}
