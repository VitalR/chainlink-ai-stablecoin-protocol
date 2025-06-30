'use client';

import { useState, useEffect, useMemo } from 'react';
import { useAccount, useReadContract, useChainId, useSwitchChain } from 'wagmi';
import {
  COLLATERAL_VAULT_ABI,
  AI_STABLECOIN_ABI,
  TOKENS,
  formatTokenAmount,
  getChainContracts,
} from '@/lib/web3';
import { ManualProcessing } from './ManualProcessing';
import { WithdrawForm } from './WithdrawForm';

export function UserPosition() {
  const { address } = useAccount();
  const chainId = useChainId();
  const { switchChain } = useSwitchChain();
  const contracts = getChainContracts(chainId);
  const [showWithdraw, setShowWithdraw] = useState(false);
  const [selectedPositionIndex, setSelectedPositionIndex] = useState(0);

  // Utility functions - moved to top to fix hoisting issue
  const getTokenInfo = (tokenAddress: string) => {
    const entry = Object.entries(TOKENS).find(
      ([, config]) =>
        config.address.toLowerCase() === tokenAddress.toLowerCase()
    );
    if (entry) {
      const [symbol, config] = entry;
      return { symbol, decimals: config.decimals };
    }

    // Fallback: try to extract symbol from address (last 4 characters for debugging)
    console.log('Unknown token address:', tokenAddress);
    return { symbol: `Token (${tokenAddress.slice(-4)})`, decimals: 18 };
  };

  const formatCollateralRatio = (ratio: bigint) => {
    // Ratio is in basis points (10000 = 100%)
    return (Number(ratio) / 10000).toFixed(2);
  };

  const getPositionHealthColor = (ratio: bigint) => {
    const ratioPercent = Number(ratio) / 10000;
    if (!ratio || ratioPercent === 0) return 'text-gray-600'; // Handle 0 or undefined ratios
    if (ratioPercent <= 1.35) return 'text-green-600'; // 135% = 1.35
    if (ratioPercent <= 1.6) return 'text-yellow-600'; // 160% = 1.60
    return 'text-red-600';
  };

  // Check if vault is available on current chain
  const isVaultAvailable = useMemo(
    () =>
      'COLLATERAL_VAULT' in contracts &&
      contracts.COLLATERAL_VAULT &&
      contracts.COLLATERAL_VAULT !== '0x',
    [contracts]
  );

  // Read total position count
  const {
    data: positionCount,
    isLoading: isLoadingCount,
    refetch: refetchCount,
  } = useReadContract({
    address: isVaultAvailable
      ? (contracts as { COLLATERAL_VAULT: `0x${string}` }).COLLATERAL_VAULT
      : undefined,
    abi: COLLATERAL_VAULT_ABI,
    functionName: 'userPositionCount',
    args: address && isVaultAvailable ? [address] : undefined,
    query: {
      enabled: !!address && isVaultAvailable,
    },
  });

  const totalPositionCount = positionCount ? Number(positionCount) : 0;

  // Fixed set of position hooks (0-29) - conditionally enabled based on totalPositionCount
  const { data: position0 } = useReadContract({
    address: isVaultAvailable
      ? (contracts as { COLLATERAL_VAULT: `0x${string}` }).COLLATERAL_VAULT
      : undefined,
    abi: COLLATERAL_VAULT_ABI,
    functionName: 'getUserDepositInfo',
    args: [address || '0x', BigInt(0)],
    query: {
      enabled: !!address && !!isVaultAvailable && 0 < totalPositionCount,
    },
  });

  const { data: position1 } = useReadContract({
    address: isVaultAvailable
      ? (contracts as { COLLATERAL_VAULT: `0x${string}` }).COLLATERAL_VAULT
      : undefined,
    abi: COLLATERAL_VAULT_ABI,
    functionName: 'getUserDepositInfo',
    args: [address || '0x', BigInt(1)],
    query: {
      enabled: !!address && !!isVaultAvailable && 1 < totalPositionCount,
    },
  });

  const { data: position2 } = useReadContract({
    address: isVaultAvailable
      ? (contracts as { COLLATERAL_VAULT: `0x${string}` }).COLLATERAL_VAULT
      : undefined,
    abi: COLLATERAL_VAULT_ABI,
    functionName: 'getUserDepositInfo',
    args: [address || '0x', BigInt(2)],
    query: {
      enabled: !!address && !!isVaultAvailable && 2 < totalPositionCount,
    },
  });

  const { data: position3 } = useReadContract({
    address: isVaultAvailable
      ? (contracts as { COLLATERAL_VAULT: `0x${string}` }).COLLATERAL_VAULT
      : undefined,
    abi: COLLATERAL_VAULT_ABI,
    functionName: 'getUserDepositInfo',
    args: [address || '0x', BigInt(3)],
    query: {
      enabled: !!address && !!isVaultAvailable && 3 < totalPositionCount,
    },
  });

  const { data: position4 } = useReadContract({
    address: isVaultAvailable
      ? (contracts as { COLLATERAL_VAULT: `0x${string}` }).COLLATERAL_VAULT
      : undefined,
    abi: COLLATERAL_VAULT_ABI,
    functionName: 'getUserDepositInfo',
    args: [address || '0x', BigInt(4)],
    query: {
      enabled: !!address && !!isVaultAvailable && 4 < totalPositionCount,
    },
  });

  const { data: position5 } = useReadContract({
    address: isVaultAvailable
      ? (contracts as { COLLATERAL_VAULT: `0x${string}` }).COLLATERAL_VAULT
      : undefined,
    abi: COLLATERAL_VAULT_ABI,
    functionName: 'getUserDepositInfo',
    args: [address || '0x', BigInt(5)],
    query: {
      enabled: !!address && !!isVaultAvailable && 5 < totalPositionCount,
    },
  });

  const { data: position6 } = useReadContract({
    address: isVaultAvailable
      ? (contracts as { COLLATERAL_VAULT: `0x${string}` }).COLLATERAL_VAULT
      : undefined,
    abi: COLLATERAL_VAULT_ABI,
    functionName: 'getUserDepositInfo',
    args: [address || '0x', BigInt(6)],
    query: {
      enabled: !!address && !!isVaultAvailable && 6 < totalPositionCount,
    },
  });

  const { data: position7 } = useReadContract({
    address: isVaultAvailable
      ? (contracts as { COLLATERAL_VAULT: `0x${string}` }).COLLATERAL_VAULT
      : undefined,
    abi: COLLATERAL_VAULT_ABI,
    functionName: 'getUserDepositInfo',
    args: [address || '0x', BigInt(7)],
    query: {
      enabled: !!address && !!isVaultAvailable && 7 < totalPositionCount,
    },
  });

  const { data: position8 } = useReadContract({
    address: isVaultAvailable
      ? (contracts as { COLLATERAL_VAULT: `0x${string}` }).COLLATERAL_VAULT
      : undefined,
    abi: COLLATERAL_VAULT_ABI,
    functionName: 'getUserDepositInfo',
    args: [address || '0x', BigInt(8)],
    query: {
      enabled: !!address && !!isVaultAvailable && 8 < totalPositionCount,
    },
  });

  const { data: position9 } = useReadContract({
    address: isVaultAvailable
      ? (contracts as { COLLATERAL_VAULT: `0x${string}` }).COLLATERAL_VAULT
      : undefined,
    abi: COLLATERAL_VAULT_ABI,
    functionName: 'getUserDepositInfo',
    args: [address || '0x', BigInt(9)],
    query: {
      enabled: !!address && !!isVaultAvailable && 9 < totalPositionCount,
    },
  });

  const { data: position10 } = useReadContract({
    address: isVaultAvailable
      ? (contracts as { COLLATERAL_VAULT: `0x${string}` }).COLLATERAL_VAULT
      : undefined,
    abi: COLLATERAL_VAULT_ABI,
    functionName: 'getUserDepositInfo',
    args: [address || '0x', BigInt(10)],
    query: {
      enabled: !!address && !!isVaultAvailable && 10 < totalPositionCount,
    },
  });

  const { data: position11 } = useReadContract({
    address: isVaultAvailable
      ? (contracts as { COLLATERAL_VAULT: `0x${string}` }).COLLATERAL_VAULT
      : undefined,
    abi: COLLATERAL_VAULT_ABI,
    functionName: 'getUserDepositInfo',
    args: [address || '0x', BigInt(11)],
    query: {
      enabled: !!address && !!isVaultAvailable && 11 < totalPositionCount,
    },
  });

  const { data: position12 } = useReadContract({
    address: isVaultAvailable
      ? (contracts as { COLLATERAL_VAULT: `0x${string}` }).COLLATERAL_VAULT
      : undefined,
    abi: COLLATERAL_VAULT_ABI,
    functionName: 'getUserDepositInfo',
    args: [address || '0x', BigInt(12)],
    query: {
      enabled: !!address && !!isVaultAvailable && 12 < totalPositionCount,
    },
  });

  const { data: position13 } = useReadContract({
    address: isVaultAvailable
      ? (contracts as { COLLATERAL_VAULT: `0x${string}` }).COLLATERAL_VAULT
      : undefined,
    abi: COLLATERAL_VAULT_ABI,
    functionName: 'getUserDepositInfo',
    args: [address || '0x', BigInt(13)],
    query: {
      enabled: !!address && !!isVaultAvailable && 13 < totalPositionCount,
    },
  });

  const { data: position14 } = useReadContract({
    address: isVaultAvailable
      ? (contracts as { COLLATERAL_VAULT: `0x${string}` }).COLLATERAL_VAULT
      : undefined,
    abi: COLLATERAL_VAULT_ABI,
    functionName: 'getUserDepositInfo',
    args: [address || '0x', BigInt(14)],
    query: {
      enabled: !!address && !!isVaultAvailable && 14 < totalPositionCount,
    },
  });

  const { data: position15 } = useReadContract({
    address: isVaultAvailable
      ? (contracts as { COLLATERAL_VAULT: `0x${string}` }).COLLATERAL_VAULT
      : undefined,
    abi: COLLATERAL_VAULT_ABI,
    functionName: 'getUserDepositInfo',
    args: [address || '0x', BigInt(15)],
    query: {
      enabled: !!address && !!isVaultAvailable && 15 < totalPositionCount,
    },
  });

  const { data: position16 } = useReadContract({
    address: isVaultAvailable
      ? (contracts as { COLLATERAL_VAULT: `0x${string}` }).COLLATERAL_VAULT
      : undefined,
    abi: COLLATERAL_VAULT_ABI,
    functionName: 'getUserDepositInfo',
    args: [address || '0x', BigInt(16)],
    query: {
      enabled: !!address && !!isVaultAvailable && 16 < totalPositionCount,
    },
  });

  const { data: position17 } = useReadContract({
    address: isVaultAvailable
      ? (contracts as { COLLATERAL_VAULT: `0x${string}` }).COLLATERAL_VAULT
      : undefined,
    abi: COLLATERAL_VAULT_ABI,
    functionName: 'getUserDepositInfo',
    args: [address || '0x', BigInt(17)],
    query: {
      enabled: !!address && !!isVaultAvailable && 17 < totalPositionCount,
    },
  });

  const { data: position18 } = useReadContract({
    address: isVaultAvailable
      ? (contracts as { COLLATERAL_VAULT: `0x${string}` }).COLLATERAL_VAULT
      : undefined,
    abi: COLLATERAL_VAULT_ABI,
    functionName: 'getUserDepositInfo',
    args: [address || '0x', BigInt(18)],
    query: {
      enabled: !!address && !!isVaultAvailable && 18 < totalPositionCount,
    },
  });

  const { data: position19 } = useReadContract({
    address: isVaultAvailable
      ? (contracts as { COLLATERAL_VAULT: `0x${string}` }).COLLATERAL_VAULT
      : undefined,
    abi: COLLATERAL_VAULT_ABI,
    functionName: 'getUserDepositInfo',
    args: [address || '0x', BigInt(19)],
    query: {
      enabled: !!address && !!isVaultAvailable && 19 < totalPositionCount,
    },
  });

  const { data: position20 } = useReadContract({
    address: isVaultAvailable
      ? (contracts as { COLLATERAL_VAULT: `0x${string}` }).COLLATERAL_VAULT
      : undefined,
    abi: COLLATERAL_VAULT_ABI,
    functionName: 'getUserDepositInfo',
    args: [address || '0x', BigInt(20)],
    query: {
      enabled: !!address && !!isVaultAvailable && 20 < totalPositionCount,
    },
  });

  const { data: position21 } = useReadContract({
    address: isVaultAvailable
      ? (contracts as { COLLATERAL_VAULT: `0x${string}` }).COLLATERAL_VAULT
      : undefined,
    abi: COLLATERAL_VAULT_ABI,
    functionName: 'getUserDepositInfo',
    args: [address || '0x', BigInt(21)],
    query: {
      enabled: !!address && !!isVaultAvailable && 21 < totalPositionCount,
    },
  });

  const { data: position22 } = useReadContract({
    address: isVaultAvailable
      ? (contracts as { COLLATERAL_VAULT: `0x${string}` }).COLLATERAL_VAULT
      : undefined,
    abi: COLLATERAL_VAULT_ABI,
    functionName: 'getUserDepositInfo',
    args: [address || '0x', BigInt(22)],
    query: {
      enabled: !!address && !!isVaultAvailable && 22 < totalPositionCount,
    },
  });

  const { data: position23 } = useReadContract({
    address: isVaultAvailable
      ? (contracts as { COLLATERAL_VAULT: `0x${string}` }).COLLATERAL_VAULT
      : undefined,
    abi: COLLATERAL_VAULT_ABI,
    functionName: 'getUserDepositInfo',
    args: [address || '0x', BigInt(23)],
    query: {
      enabled: !!address && !!isVaultAvailable && 23 < totalPositionCount,
    },
  });

  const { data: position24 } = useReadContract({
    address: isVaultAvailable
      ? (contracts as { COLLATERAL_VAULT: `0x${string}` }).COLLATERAL_VAULT
      : undefined,
    abi: COLLATERAL_VAULT_ABI,
    functionName: 'getUserDepositInfo',
    args: [address || '0x', BigInt(24)],
    query: {
      enabled: !!address && !!isVaultAvailable && 24 < totalPositionCount,
    },
  });

  const { data: position25 } = useReadContract({
    address: isVaultAvailable
      ? (contracts as { COLLATERAL_VAULT: `0x${string}` }).COLLATERAL_VAULT
      : undefined,
    abi: COLLATERAL_VAULT_ABI,
    functionName: 'getUserDepositInfo',
    args: [address || '0x', BigInt(25)],
    query: {
      enabled: !!address && !!isVaultAvailable && 25 < totalPositionCount,
    },
  });

  const { data: position26 } = useReadContract({
    address: isVaultAvailable
      ? (contracts as { COLLATERAL_VAULT: `0x${string}` }).COLLATERAL_VAULT
      : undefined,
    abi: COLLATERAL_VAULT_ABI,
    functionName: 'getUserDepositInfo',
    args: [address || '0x', BigInt(26)],
    query: {
      enabled: !!address && !!isVaultAvailable && 26 < totalPositionCount,
    },
  });

  const { data: position27 } = useReadContract({
    address: isVaultAvailable
      ? (contracts as { COLLATERAL_VAULT: `0x${string}` }).COLLATERAL_VAULT
      : undefined,
    abi: COLLATERAL_VAULT_ABI,
    functionName: 'getUserDepositInfo',
    args: [address || '0x', BigInt(27)],
    query: {
      enabled: !!address && !!isVaultAvailable && 27 < totalPositionCount,
    },
  });

  const { data: position28 } = useReadContract({
    address: isVaultAvailable
      ? (contracts as { COLLATERAL_VAULT: `0x${string}` }).COLLATERAL_VAULT
      : undefined,
    abi: COLLATERAL_VAULT_ABI,
    functionName: 'getUserDepositInfo',
    args: [address || '0x', BigInt(28)],
    query: {
      enabled: !!address && !!isVaultAvailable && 28 < totalPositionCount,
    },
  });

  const { data: position29 } = useReadContract({
    address: isVaultAvailable
      ? (contracts as { COLLATERAL_VAULT: `0x${string}` }).COLLATERAL_VAULT
      : undefined,
    abi: COLLATERAL_VAULT_ABI,
    functionName: 'getUserDepositInfo',
    args: [address || '0x', BigInt(29)],
    query: {
      enabled: !!address && !!isVaultAvailable && 29 < totalPositionCount,
    },
  });

  // Collect all valid positions from the 30 static hooks we have (0-29)
  const userPositions = useMemo(() => {
    const allPositionData = [
      position0,
      position1,
      position2,
      position3,
      position4,
      position5,
      position6,
      position7,
      position8,
      position9,
      position10,
      position11,
      position12,
      position13,
      position14,
      position15,
      position16,
      position17,
      position18,
      position19,
      position20,
      position21,
      position22,
      position23,
      position24,
      position25,
      position26,
      position27,
      position28,
      position29,
    ];

    const positions: Array<{
      totalValueUSD: bigint;
      aiusdMinted: bigint;
      collateralRatio: bigint;
      hasPendingRequest: boolean;
      requestId: bigint;
      timestamp: bigint;
      index: number;
      tokens: readonly `0x${string}`[];
      amounts: readonly bigint[];
      arrayIndex: number;
    }> = [];

    console.log(`=== DYNAMIC POSITION DISCOVERY ===`);
    console.log(`Total position count from contract: ${totalPositionCount}`);
    console.log(
      `Checking positions 0 to ${Math.min(totalPositionCount - 1, 29)}:`
    );

    // Warn if user has more positions than we can handle with static hooks
    if (totalPositionCount > 30) {
      console.warn(
        `⚠️ User has ${totalPositionCount} positions but we only check the first 30. Consider expanding position hooks or implementing batch fetching.`
      );
    }

    for (let i = 0; i < totalPositionCount && i < allPositionData.length; i++) {
      const positionData = allPositionData[i];

      // Include positions that have collateral (even if AIUSD not minted yet)
      if (
        positionData &&
        (positionData.totalValueUSD > 0 || positionData.tokens?.length > 0)
      ) {
        console.log(
          `✅ Position ${i}: Contract Index: ${
            positionData.index
          }, AIUSD: ${formatTokenAmount(
            positionData.aiusdMinted,
            18,
            4
          )}, Value: ${formatTokenAmount(
            positionData.totalValueUSD,
            18,
            4
          )}, Tokens: ${positionData.tokens?.length || 0}`
        );
        positions.push({ ...positionData, arrayIndex: i });
      } else if (positionData) {
        console.log(`⚪ Position ${i}: Empty (no collateral)`);
      } else {
        console.log(`❌ Position ${i}: No data loaded yet`);
      }
    }

    console.log(
      `Found ${positions.length} active positions out of ${totalPositionCount} total`
    );
    if (totalPositionCount > 30) {
      console.log(
        `📝 Note: Only checked first 30 positions. ${
          totalPositionCount - 30
        } positions not checked.`
      );
    }
    console.log(`=== END DYNAMIC DISCOVERY ===`);

    return positions;
  }, [
    totalPositionCount,
    position0,
    position1,
    position2,
    position3,
    position4,
    position5,
    position6,
    position7,
    position8,
    position9,
    position10,
    position11,
    position12,
    position13,
    position14,
    position15,
    position16,
    position17,
    position18,
    position19,
    position20,
    position21,
    position22,
    position23,
    position24,
    position25,
    position26,
    position27,
    position28,
    position29,
  ]);

  // Get the current selected position
  const currentPosition = userPositions[selectedPositionIndex];

  // Get position summary for the user
  const {
    data: positionSummary,
    refetch: refetchPositionSummary,
    error: summaryError,
  } = useReadContract({
    address: isVaultAvailable
      ? (contracts as { COLLATERAL_VAULT: `0x${string}` }).COLLATERAL_VAULT
      : undefined,
    abi: COLLATERAL_VAULT_ABI,
    functionName: 'getPositionSummary',
    args: address && isVaultAvailable ? [address] : undefined,
    query: {
      enabled: !!address && isVaultAvailable,
      staleTime: 1000 * 30, // 30 seconds
    },
  });

  // Get user's AIUSD balance
  const { data: aiusdBalance, refetch: refetchBalance } = useReadContract({
    address: contracts.AIUSD,
    abi: AI_STABLECOIN_ABI,
    functionName: 'balanceOf',
    args: [address || '0x'],
    query: { enabled: !!address },
  });

  const isLoading = isLoadingCount;

  // Calculate average collateral ratio from individual positions
  const calculateAverageRatio = useMemo(() => {
    if (userPositions.length === 0) return BigInt(0);

    let totalWeightedRatio = BigInt(0);
    let totalMinted = BigInt(0);

    userPositions.forEach((position) => {
      // Include positions that have been processed (have collateralRatio > 0)
      if (position.aiusdMinted > 0 && position.collateralRatio > 0) {
        // Ensure both values are BigInt for proper arithmetic
        const ratio = BigInt(position.collateralRatio);
        const minted = BigInt(position.aiusdMinted);
        totalWeightedRatio += ratio * minted;
        totalMinted += minted;
      }
    });

    return totalMinted > 0 ? totalWeightedRatio / totalMinted : BigInt(0);
  }, [userPositions]);

  // Debug logging with better error handling
  useEffect(() => {
    if (address && isVaultAvailable) {
      console.log('=== USER POSITION DEBUG ===');
      console.log('Address:', address.slice(0, 8) + '...');
      console.log('Chain ID:', chainId);
      console.log(
        'Vault Address:',
        (contracts as { COLLATERAL_VAULT: `0x${string}` }).COLLATERAL_VAULT
      );
      console.log('Position Count from Contract:', totalPositionCount);
      console.log('User Positions Length:', userPositions.length);
      console.log('Selected Position Index (UI):', selectedPositionIndex);
      console.log(
        'Current Position:',
        currentPosition
          ? `Contract Index ${currentPosition.index} (UI Index ${selectedPositionIndex})`
          : 'None'
      );
      console.log('Position Index Mapping:');
      userPositions.forEach((pos, uiIndex) => {
        console.log(`  UI Index ${uiIndex} → Contract Index ${pos.index}`);
      });
      console.log(
        'Average Collateral Ratio:',
        formatCollateralRatio(calculateAverageRatio)
      );

      // Debug position hook enabling conditions
      console.log('🔧 Position Hook Enabling Debug:');
      console.log(`- Raw positionCount data:`, positionCount);
      console.log(`- positionCount isLoading:`, isLoadingCount);
      console.log(`- totalPositionCount: ${totalPositionCount}`);
      console.log(`- isVaultAvailable: ${isVaultAvailable}`);
      console.log(`- address: ${!!address}`);
      for (let i = 0; i < Math.min(5, 50); i++) {
        const enabled =
          !!address && !!isVaultAvailable && i < totalPositionCount;
        console.log(
          `- Position ${i} hook enabled: ${enabled} (${i} < ${totalPositionCount})`
        );
      }

      // Enhanced position summary logging
      if (positionSummary) {
        console.log('Position Summary Data:', {
          totalPositions: positionSummary[0].toString(),
          activePositions: positionSummary[1].toString(),
          totalValueUSD: formatTokenAmount(positionSummary[2], 18, 4),
          totalAIUSDMinted: formatTokenAmount(positionSummary[3], 18, 4),
        });
      }

      console.log(
        'AIUSD Balance:',
        aiusdBalance ? formatTokenAmount(aiusdBalance, 18, 4) : 'loading'
      );
      console.log('=== END DEBUG ===');
    }
  }, [
    address,
    chainId,
    contracts,
    totalPositionCount,
    userPositions,
    positionSummary,
    aiusdBalance,
    summaryError,
    isVaultAvailable,
    calculateAverageRatio,
    selectedPositionIndex,
    currentPosition,
    isLoadingCount,
    positionCount,
  ]);

  // Function to refresh all data
  const refreshData = async () => {
    if (isVaultAvailable) {
      await Promise.all([
        refetchCount(),
        refetchBalance(),
        refetchPositionSummary(),
      ]);
    } else {
      await refetchBalance();
    }
  };

  // Reset to position 0 when address changes or when there are no positions
  useEffect(() => {
    if (userPositions.length === 0) {
      setSelectedPositionIndex(0);
    } else if (selectedPositionIndex >= userPositions.length) {
      setSelectedPositionIndex(Math.max(0, userPositions.length - 1));
    }
  }, [userPositions.length, selectedPositionIndex]);

  const handleSwitchToSepolia = () => {
    switchChain({ chainId: 11155111 }); // Sepolia
  };

  // Improved loading guard: wait for all critical data before making decisions
  const isFullyLoading =
    isLoadingCount ||
    typeof positionCount === 'undefined' ||
    typeof positionSummary === 'undefined' ||
    typeof aiusdBalance === 'undefined';

  // Add a flag to track if we're still in the initial loading phase
  const isInitialPositionLoading = useMemo(() => {
    if (!positionSummary || isFullyLoading) return true;

    // If summary shows positions but we haven't had enough time to load individual positions
    const hasPositionsInSummary =
      positionSummary && Number(positionSummary[1]) > 0;
    const hasLoadedIndividualPositions = userPositions.length > 0;

    // Give it time to load individual positions before showing debug screen
    return hasPositionsInSummary && !hasLoadedIndividualPositions;
  }, [positionSummary, userPositions.length, isFullyLoading]);

  if (isFullyLoading || isInitialPositionLoading) {
    return (
      <div className="animate-pulse space-y-4">
        <div className="h-4 bg-gray-200 rounded w-3/4"></div>
        <div className="h-4 bg-gray-200 rounded w-1/2"></div>
        <div className="h-4 bg-gray-200 rounded w-2/3"></div>
        <div className="text-center text-sm text-gray-500 mt-4">
          Loading your positions...
        </div>
      </div>
    );
  }

  // Show network switch prompt if vault is not available
  if (!isVaultAvailable) {
    return (
      <div className="space-y-6">
        <div className="bg-yellow-50 border border-yellow-200 rounded-lg p-6">
          <div className="flex items-center space-x-2 mb-2">
            <span className="text-yellow-600">⚠️</span>
            <span className="font-medium text-yellow-800">
              Positions Only Available on Sepolia
            </span>
          </div>
          <p className="text-sm text-yellow-700 mb-4">
            Collateral positions and vault functionality are only available on
            Ethereum Sepolia where the CollateralVault is deployed.
          </p>
          <button
            onClick={handleSwitchToSepolia}
            className="bg-yellow-600 text-white px-4 py-2 rounded-lg font-medium hover:bg-yellow-700 transition-colors"
          >
            Switch to Sepolia Testnet
          </button>
        </div>

        {/* Show AIUSD balance even on other chains */}
        <div className="border-t pt-4">
          <div className="flex justify-between items-center">
            <span className="text-gray-600">Your AIUSD Balance:</span>
            <span className="font-bold text-lg text-blue-600">
              {aiusdBalance ? formatTokenAmount(aiusdBalance, 18, 4) : '0'}{' '}
              AIUSD
            </span>
          </div>
          {aiusdBalance && Number(aiusdBalance) > 0 && (
            <div className="mt-2 text-sm text-gray-500">
              💡 Use the Bridge tab to transfer AIUSD between networks
            </div>
          )}
        </div>
      </div>
    );
  }

  // Show loading while position count is loading OR while we have AIUSD but haven't loaded positions yet
  const hasAIUSD = aiusdBalance && Number(aiusdBalance) > 0;
  if (isLoading || (hasAIUSD && positionSummary === undefined)) {
    return (
      <div className="animate-pulse space-y-4">
        <div className="h-4 bg-gray-200 rounded w-3/4"></div>
        <div className="h-4 bg-gray-200 rounded w-1/2"></div>
        <div className="h-4 bg-gray-200 rounded w-2/3"></div>
        <div className="text-center text-sm text-gray-500 mt-4">
          {hasAIUSD ? 'Loading your positions...' : 'Loading...'}
        </div>
      </div>
    );
  }

  // Check if user has any positions - simplified logic
  const hasPositions = positionSummary && Number(positionSummary[1]) > 0; // activePositions
  // const hasMintedAIUSD = positionSummary && Number(positionSummary[3]) > 0; // totalAIUSDMinted (unused)

  // MODIFIED: Only show debug screen in development or after significant delay with persistent error
  // This prevents the debug screen from flashing during normal loading transitions
  if (
    hasPositions &&
    userPositions.length === 0 &&
    process.env.NODE_ENV === 'development'
  ) {
    return (
      <div className="text-center py-8">
        <div className="w-16 h-16 bg-yellow-100 rounded-full flex items-center justify-center mx-auto mb-4">
          <span className="text-2xl">🔍</span>
        </div>
        <h4 className="text-lg font-medium text-yellow-900 mb-2">
          Position Discovery Issue (Dev Mode)
        </h4>
        <p className="text-yellow-700 mb-4">
          Found position data in summary but can&apos;t locate individual
          positions.
        </p>

        {/* Show summary data */}
        <div className="bg-yellow-50 border border-yellow-200 rounded-lg p-4 mb-4">
          <h5 className="font-medium text-yellow-800 mb-2">
            ✅ Summary Data (Working):
          </h5>
          <div className="text-sm text-yellow-700 space-y-1">
            <div>
              • Total Collateral:{' '}
              <strong>${formatTokenAmount(positionSummary[2], 18, 2)}</strong>
            </div>
            <div>
              • Total AIUSD Minted:{' '}
              <strong>
                {formatTokenAmount(positionSummary[3], 18, 4)} AIUSD
              </strong>
            </div>
            <div>
              • Active Positions:{' '}
              <strong>{positionSummary[1].toString()}</strong>
            </div>
          </div>
        </div>

        <div className="bg-red-50 border border-red-200 rounded-lg p-4 mb-4">
          <h5 className="font-medium text-red-800 mb-2">
            ❌ Position Discovery (Failed):
          </h5>
          <div className="text-sm text-red-700 space-y-1">
            <div>
              • Contract reports: <strong>{totalPositionCount}</strong>{' '}
              positions
            </div>
            <div>
              • Successfully loaded: <strong>{userPositions.length}</strong>{' '}
              positions
            </div>
            <div>• This suggests a data loading or network issue</div>
          </div>
        </div>

        <div className="space-y-3">
          <p className="text-sm text-gray-600 font-medium">Debug Actions:</p>
          <div className="flex flex-col space-y-2">
            <button
              onClick={() => {
                console.log('=== MANUAL POSITION DEBUG ===');
                console.log('Position Summary:', {
                  totalPositions: positionSummary[0].toString(),
                  activePositions: positionSummary[1].toString(),
                  totalValueUSD: formatTokenAmount(positionSummary[2], 18, 4),
                  totalAIUSDMinted: formatTokenAmount(
                    positionSummary[3],
                    18,
                    4
                  ),
                });
                console.log(`Contract position count: ${totalPositionCount}`);
                console.log(`Loaded positions: ${userPositions.length}`);
                console.log('=== Check console for details ===');
                refreshData();
              }}
              className="bg-blue-600 text-white px-4 py-2 rounded-lg font-medium hover:bg-blue-700 transition-colors"
            >
              🔍 Debug & Refresh
            </button>
            <button
              onClick={() => window.location.reload()}
              className="bg-yellow-600 text-white px-4 py-2 rounded-lg font-medium hover:bg-yellow-700 transition-colors"
            >
              🔄 Reload Page
            </button>
          </div>
        </div>

        <div className="mt-4 text-xs text-gray-500">
          Connected:{' '}
          {address ? `${address.slice(0, 6)}...${address.slice(-4)}` : 'None'}
        </div>

        <div className="mt-4 p-3 bg-blue-50 border border-blue-200 rounded-lg">
          <p className="text-sm text-blue-700">
            💡 <strong>Development Note:</strong> Your positions exist (summary
            shows data), but they&apos;re at different indices than we&apos;re
            checking. Check browser console for debug info.
          </p>
        </div>
      </div>
    );
  }

  // If no positions and no AIUSD, show welcome message
  if (!hasPositions && !hasAIUSD) {
    return (
      <div className="text-center py-8">
        <div className="w-16 h-16 bg-gray-100 rounded-full flex items-center justify-center mx-auto mb-4">
          <span className="text-2xl">📊</span>
        </div>
        <h4 className="text-lg font-medium text-gray-900 mb-2">No Positions</h4>
        <p className="text-gray-600">
          Deposit collateral to create your position
        </p>
        <div className="mt-4 text-xs text-gray-500">
          Connected:{' '}
          {address ? `${address.slice(0, 6)}...${address.slice(-4)}` : 'None'}
        </div>
      </div>
    );
  }

  // If user has AIUSD but no positions (bridge/transfer case)
  if (hasAIUSD && !hasPositions) {
    return (
      <div className="text-center py-8">
        <div className="w-16 h-16 bg-blue-100 rounded-full flex items-center justify-center mx-auto mb-4">
          <span className="text-2xl">💰</span>
        </div>
        <h4 className="text-lg font-medium text-blue-900 mb-2">
          AIUSD Balance Found
        </h4>
        <p className="text-blue-700 mb-4">
          You have {formatTokenAmount(aiusdBalance!, 18, 4)} AIUSD but no
          collateral positions.
        </p>
        <div className="bg-blue-50 border border-blue-200 rounded-lg p-4 mb-4">
          <p className="text-sm text-blue-700">This could mean:</p>
          <ul className="text-sm text-blue-600 mt-2 space-y-1">
            <li>• 💸 You received AIUSD via bridge or transfer</li>
            <li>• 🔄 You withdrew all collateral and kept the AIUSD</li>
            <li>• 🌐 Your positions are on a different network</li>
          </ul>
        </div>
        <div className="space-y-2">
          <p className="text-sm text-gray-600">
            You can still use your AIUSD for:
          </p>
          <div className="flex justify-center space-x-2">
            <button
              onClick={() => (window.location.hash = '#bridge')}
              className="bg-blue-600 text-white px-4 py-2 rounded-lg font-medium hover:bg-blue-700 transition-colors text-sm"
            >
              🌉 Bridge to Other Chains
            </button>
            <button
              onClick={() => (window.location.hash = '#deposit')}
              className="bg-green-600 text-white px-4 py-2 rounded-lg font-medium hover:bg-green-700 transition-colors text-sm"
            >
              💰 Create New Position
            </button>
          </div>
        </div>
        <div className="mt-4 text-xs text-gray-500">
          Connected:{' '}
          {address ? `${address.slice(0, 6)}...${address.slice(-4)}` : 'None'}
        </div>
      </div>
    );
  }

  // If error loading data
  if (!positionSummary && summaryError) {
    return (
      <div className="text-center py-8">
        <div className="w-16 h-16 bg-red-100 rounded-full flex items-center justify-center mx-auto mb-4">
          <span className="text-2xl">⚠️</span>
        </div>
        <h4 className="text-lg font-medium text-red-900 mb-2">
          Error Loading Position
        </h4>
        <p className="text-red-600 text-sm mb-4">
          Failed to load position data. This could be a temporary network issue.
        </p>
        {summaryError && (
          <div className="text-xs text-red-500 mb-2 font-mono">
            Summary Error: {String(summaryError)}
          </div>
        )}
        <div className="space-y-2">
          <button
            onClick={refreshData}
            className="bg-blue-600 text-white px-4 py-2 rounded-lg font-medium hover:bg-blue-700 transition-colors mr-2"
          >
            Retry Loading
          </button>
          <button
            onClick={() => window.location.reload()}
            className="bg-red-600 text-white px-4 py-2 rounded-lg font-medium hover:bg-red-700 transition-colors"
          >
            Refresh Page
          </button>
        </div>
        {hasAIUSD && (
          <div className="mt-4 p-3 bg-blue-50 border border-blue-200 rounded-lg">
            <p className="text-sm text-blue-700">
              💡 You have {formatTokenAmount(aiusdBalance!, 18, 4)} AIUSD, so
              you should have positions. Try refreshing or check if you&apos;re
              on the correct network (Sepolia).
            </p>
          </div>
        )}
      </div>
    );
  }

  // Main UI when user has positions
  return (
    <div className="space-y-6">
      {/* Warning if user has more positions than we can display */}
      {totalPositionCount > 30 && (
        <div className="bg-amber-50 border border-amber-200 rounded-lg p-4">
          <div className="flex items-center space-x-2 mb-2">
            <span className="text-amber-600">⚠️</span>
            <span className="font-medium text-amber-800">
              Position Limit Notice
            </span>
          </div>
          <p className="text-sm text-amber-700">
            You have {totalPositionCount} positions, but we can only display the
            first 30. The remaining {totalPositionCount - 30} positions are not
            shown in this interface.
          </p>
        </div>
      )}

      {/* Position Selector */}
      {userPositions.length > 1 && (
        <div className="border rounded-lg p-4 bg-gradient-to-r from-gray-50 to-blue-50">
          <label className="font-semibold text-gray-800 mb-3 block">
            📊 Position Selection
          </label>
          <div className="flex items-center space-x-3">
            <select
              value={selectedPositionIndex}
              onChange={(e) => setSelectedPositionIndex(Number(e.target.value))}
              className="px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500 bg-white"
            >
              {userPositions.map((position, i) => (
                <option key={i} value={i}>
                  Contract Position #{position.index} (UI: {i + 1})
                </option>
              ))}
            </select>
            <span className="text-sm text-gray-600">
              Total positions:{' '}
              <span className="font-bold">{userPositions.length}</span>
            </span>
          </div>
        </div>
      )}

      {/* Position Summary */}
      <div className="bg-gradient-to-r from-green-50 to-blue-50 rounded-lg p-4">
        <div className="flex justify-between items-center mb-2">
          <h4 className="font-medium text-gray-900">
            {userPositions.length > 0 && currentPosition
              ? `Contract Position #${currentPosition.index}${
                  userPositions.length > 1
                    ? ` (${selectedPositionIndex + 1} of ${
                        userPositions.length
                      })`
                    : ''
                }`
              : 'Position Summary'}
          </h4>
          {calculateAverageRatio && Number(calculateAverageRatio) > 0 && (
            <span
              className={`text-sm font-bold ${getPositionHealthColor(
                calculateAverageRatio
              )}`}
            >
              {formatCollateralRatio(calculateAverageRatio)}% Ratio
            </span>
          )}
        </div>
        <div className="grid grid-cols-2 gap-4">
          <div>
            <div className="text-sm text-gray-600">
              {userPositions.length > 0 && currentPosition
                ? 'Position Value'
                : 'Total Collateral'}
            </div>
            <div className="text-2xl font-bold text-gray-900">
              $
              {userPositions.length > 0 && currentPosition
                ? formatTokenAmount(currentPosition.totalValueUSD, 18, 2)
                : positionSummary
                ? formatTokenAmount(positionSummary[2], 18, 2)
                : '0'}
            </div>
          </div>
          <div>
            <div className="text-sm text-gray-600">
              {userPositions.length > 0 && currentPosition
                ? 'AIUSD from Position'
                : 'Total AIUSD Minted'}
            </div>
            <div className="text-2xl font-bold text-blue-600">
              {userPositions.length > 0 && currentPosition
                ? formatTokenAmount(currentPosition.aiusdMinted, 18, 4)
                : positionSummary
                ? formatTokenAmount(positionSummary[3], 18, 4)
                : '0'}{' '}
              AIUSD
            </div>
          </div>
        </div>
      </div>

      {/* Position Status */}
      {currentPosition?.hasPendingRequest ? (
        <div className="space-y-4">
          <div className="bg-yellow-50 border border-yellow-200 rounded-lg p-4">
            <div className="flex items-center space-x-2 mb-2">
              <div className="w-3 h-3 bg-yellow-400 rounded-full animate-pulse"></div>
              <span className="font-medium text-yellow-800">AI Processing</span>
            </div>
            <p className="text-sm text-yellow-700">
              Request ID: {currentPosition.requestId.toString()}
            </p>
            <p className="text-sm text-yellow-700">
              AI is analyzing your collateral to determine optimal minting
              ratio...
            </p>
          </div>
          <ManualProcessing
            requestId={currentPosition.requestId}
            onSuccess={refreshData}
          />
        </div>
      ) : (
        <div className="bg-green-50 border border-green-200 rounded-lg p-4">
          <div className="flex items-center space-x-2 mb-2">
            <div className="w-3 h-3 bg-green-400 rounded-full"></div>
            <span className="font-medium text-green-800">Position Active</span>
          </div>
          <div className="flex justify-between items-center">
            <p className="text-sm text-green-700">
              {(() => {
                // Debug: Log the key data we need
                console.log('=== RATIO DISPLAY DEBUG ===');
                console.log('currentPosition exists:', !!currentPosition);
                if (currentPosition) {
                  console.log(
                    'currentPosition.collateralRatio:',
                    currentPosition.collateralRatio.toString()
                  );
                  console.log(
                    'currentPosition.aiusdMinted:',
                    formatTokenAmount(currentPosition.aiusdMinted, 18, 4)
                  );
                }
                console.log(
                  'calculateAverageRatio:',
                  calculateAverageRatio.toString()
                );
                console.log('userPositions.length:', userPositions.length);
                console.log('userDepositInfo exists:', !!currentPosition);
                if (currentPosition) {
                  console.log(
                    'currentPosition.collateralRatio:',
                    currentPosition.collateralRatio.toString()
                  );
                  console.log(
                    'currentPosition.aiusdMinted:',
                    formatTokenAmount(currentPosition.aiusdMinted, 18, 4)
                  );
                }
                console.log('=== END RATIO DEBUG ===');

                // Priority 1: Current position has a valid ratio
                if (currentPosition && currentPosition.collateralRatio > 0) {
                  return `Collateral Ratio: ${formatCollateralRatio(
                    currentPosition.collateralRatio
                  )}%`;
                }

                // Priority 2: Use calculated average ratio if available
                if (
                  calculateAverageRatio &&
                  Number(calculateAverageRatio) > 0
                ) {
                  return `Average Ratio: ${formatCollateralRatio(
                    calculateAverageRatio
                  )}%`;
                }

                // Priority 3: Find any position with a valid ratio
                const positionWithRatio = userPositions.find(
                  (p) => p.collateralRatio > 0
                );
                if (positionWithRatio) {
                  return `Collateral Ratio: ${formatCollateralRatio(
                    positionWithRatio.collateralRatio
                  )}%`;
                }

                // Priority 4: Check if positions are pending
                if (userPositions.some((p) => p.hasPendingRequest)) {
                  return 'AI is calculating optimal ratio...';
                }

                // Priority 5: Check if positions exist but no ratio yet
                if (userPositions.length > 0) {
                  const processedPositions = userPositions.filter(
                    (p) => p.aiusdMinted > 0
                  );
                  if (processedPositions.length > 0) {
                    return 'Position processed, ratio updating...';
                  }
                  return 'Positions pending AI processing';
                }

                // Fallback
                return 'No position data available';
              })()}
            </p>
            <span className="text-xs text-gray-500">
              {userPositions.length > 0 &&
              Number(userPositions[0].collateralRatio) / 10000 <= 1.35
                ? '🎯 Excellent diversification'
                : userPositions.length > 0 &&
                  Number(userPositions[0].collateralRatio) / 10000 <= 1.6
                ? '⚡ Good efficiency'
                : '⚠️ Consider diversifying'}
            </span>
          </div>
        </div>
      )}

      {/* Collateral Details */}
      {userPositions.length > 0 && currentPosition && (
        <div className="border rounded-lg p-4">
          <h5 className="font-medium text-gray-900 mb-3">
            🪙 Collateral Composition
          </h5>
          <div className="space-y-2">
            {currentPosition.tokens.map((tokenAddress: string, i: number) => {
              const tokenInfo = getTokenInfo(tokenAddress);
              return (
                <div
                  key={i}
                  className="flex justify-between items-center py-2 border-b border-gray-100 last:border-b-0"
                >
                  <span className="text-sm font-medium text-gray-700">
                    {tokenInfo.symbol}
                  </span>
                  <span className="text-sm text-gray-600">
                    {formatTokenAmount(
                      currentPosition.amounts[i],
                      tokenInfo.decimals,
                      4
                    )}
                  </span>
                </div>
              );
            })}
          </div>
        </div>
      )}

      {/* Action Buttons */}
      <div className="flex space-x-3">
        <button
          onClick={() => setShowWithdraw(!showWithdraw)}
          className="flex-1 bg-orange-600 text-white py-2 px-4 rounded-lg font-medium hover:bg-orange-700 transition-colors"
        >
          {showWithdraw ? 'Hide' : 'Withdraw'} Collateral
        </button>
        <button
          onClick={refreshData}
          className="bg-gray-600 text-white py-2 px-4 rounded-lg font-medium hover:bg-gray-700 transition-colors"
        >
          🔄 Refresh
        </button>
      </div>

      {/* Withdraw Form */}
      {showWithdraw && currentPosition && (
        <div className="space-y-4">
          <div className="bg-blue-50 border border-blue-200 rounded-lg p-3">
            <p className="text-sm text-blue-700">
              <strong>Withdrawing from:</strong> Contract Position #
              {currentPosition.index}
              {userPositions.length > 1 &&
                ` (${selectedPositionIndex + 1} of ${userPositions.length})`}
            </p>
          </div>
          <WithdrawForm
            positionIndex={currentPosition.index}
            aiusdMinted={currentPosition.aiusdMinted}
            aiusdBalance={aiusdBalance || BigInt(0)}
            onSuccess={() => {
              setShowWithdraw(false);
              refreshData();
            }}
          />
        </div>
      )}
    </div>
  );
}
