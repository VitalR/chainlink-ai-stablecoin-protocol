import { getDefaultConfig } from '@rainbow-me/rainbowkit';
import { sepolia, avalancheFuji } from 'wagmi/chains';

// Contract addresses from current deployment (SepoliaConfig.sol)
export const CONTRACTS = {
  // Sepolia Testnet
  SEPOLIA: {
    AIUSD: '0xf0072115e6b861682e73a858fBEE36D512960c6f' as `0x${string}`,
    COLLATERAL_VAULT:
      '0x1EeFd496e33ACE44e8918b08bAB9E392b46e1563' as `0x${string}`,
    RISK_ORACLE_CONTROLLER:
      '0xB4F6B67C9Cd82bbBB5F97e2f40ebf972600980e4' as `0x${string}`,
    CCIP_BRIDGE: '0xB76cD1A5c6d63042D316AabB2f40a5887dD4B1D4' as `0x${string}`,
    // Test Tokens
    MOCK_DAI: '0xDE27C8D88E8F949A7ad02116F4D8BAca459af5D4' as `0x${string}`,
    MOCK_WETH: '0xe1cb3cFbf87E27c52192d90A49DB6B331C522846' as `0x${string}`,
    MOCK_WBTC: '0x4b62e33297A6D7eBe7CBFb92A0Bf175209467022' as `0x${string}`,
    MOCK_USDC: '0x3bf2384010dCb178B8c19AE30a817F9ea1BB2c94' as `0x${string}`,
    // RWA Tokens
    MOCK_OUSG: '0x27675B132A8a872Fdc50A19b854A9398c62b8905' as `0x${string}`,
    // Official Tokens
    LINK_TOKEN: '0x779877A7B0D9E8603169DdbD7836e478b4624789' as `0x${string}`,
  },
  // Avalanche Fuji
  FUJI: {
    AIUSD: '0x26D0f5BD1DAb1c02D1Fc198Fe6ECa2b22Ab276d7' as `0x${string}`,
    CCIP_BRIDGE: '0xd6cE29223350252e3dD632f0bb1438e827da12b6' as `0x${string}`,
    LINK_TOKEN: '0x0b9d5D9136855f6FEc3c0993feE6E9CE8a297846' as `0x${string}`,
    WAVAX: '0xd00ae08403B9bbb9124bB305C09058E32C39A48c' as `0x${string}`,
  },
} as const;

// Chain selectors for CCIP
export const CHAIN_SELECTORS = {
  SEPOLIA: BigInt('16015286601757825753'),
  FUJI: BigInt('14767482510784806043'),
} as const;

// Token configurations with updated pricing and RWA support
export const TOKENS = {
  // Stablecoins first
  DAI: {
    address: CONTRACTS.SEPOLIA.MOCK_DAI,
    symbol: 'DAI',
    decimals: 18,
    price: 1 as number,
    category: 'stablecoin',
  },
  USDC: {
    address: CONTRACTS.SEPOLIA.MOCK_USDC,
    symbol: 'USDC',
    decimals: 6,
    price: 1 as number,
    category: 'stablecoin',
  },
  // Crypto assets
  WETH: {
    address: CONTRACTS.SEPOLIA.MOCK_WETH,
    symbol: 'WETH',
    decimals: 18,
    price: 2000 as number,
    category: 'crypto',
  },
  WBTC: {
    address: CONTRACTS.SEPOLIA.MOCK_WBTC,
    symbol: 'WBTC',
    decimals: 8,
    price: 50000 as number,
    category: 'crypto',
  },
  LINK: {
    address: CONTRACTS.SEPOLIA.LINK_TOKEN,
    symbol: 'LINK',
    decimals: 18,
    price: 15 as number,
    category: 'crypto',
  },
  // Real World Assets last
  OUSG: {
    address: CONTRACTS.SEPOLIA.MOCK_OUSG,
    symbol: 'OUSG',
    decimals: 18,
    price: 100 as number,
    category: 'rwa',
  },
} as const;

// Optimized Wagmi config to prevent multiple WalletConnect initializations
let _config: ReturnType<typeof getDefaultConfig> | null = null;

function createConfig() {
  if (_config) return _config;

  _config = getDefaultConfig({
    appName: 'AI Stablecoin',
    projectId: process.env.NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID || 'demo',
    chains: [sepolia, avalancheFuji],
    ssr: true,
  });

  return _config;
}

export const config = createConfig();

// Updated Contract ABIs
export const RISK_ORACLE_CONTROLLER_ABI = [
  {
    inputs: [],
    name: 'estimateTotalFee',
    outputs: [{ internalType: 'uint256', name: '', type: 'uint256' }],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [{ internalType: 'uint256', name: 'requestId', type: 'uint256' }],
    name: 'getRequestInfo',
    outputs: [
      {
        components: [
          { internalType: 'address', name: 'user', type: 'address' },
          { internalType: 'address', name: 'vault', type: 'address' },
          { internalType: 'bytes', name: 'basketData', type: 'bytes' },
          { internalType: 'uint256', name: 'collateralValue', type: 'uint256' },
          { internalType: 'uint256', name: 'timestamp', type: 'uint256' },
          { internalType: 'bool', name: 'processed', type: 'bool' },
        ],
        internalType: 'struct RequestInfo',
        name: '',
        type: 'tuple',
      },
    ],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [{ internalType: 'string', name: 'token', type: 'string' }],
    name: 'getLatestPrice',
    outputs: [{ internalType: 'int256', name: '', type: 'int256' }],
    stateMutability: 'view',
    type: 'function',
  },
] as const;

export const COLLATERAL_VAULT_ABI = [
  {
    inputs: [
      { internalType: 'address[]', name: 'tokens', type: 'address[]' },
      { internalType: 'uint256[]', name: 'amounts', type: 'uint256[]' },
    ],
    name: 'depositBasket',
    outputs: [],
    stateMutability: 'payable',
    type: 'function',
  },
  {
    inputs: [
      { internalType: 'address[]', name: 'tokens', type: 'address[]' },
      { internalType: 'uint256[]', name: 'amounts', type: 'uint256[]' },
      { internalType: 'uint8', name: 'engine', type: 'uint8' },
    ],
    name: 'depositBasket',
    outputs: [],
    stateMutability: 'payable',
    type: 'function',
  },
  {
    inputs: [{ internalType: 'address', name: 'user', type: 'address' }],
    name: 'userPositionCount',
    outputs: [{ internalType: 'uint256', name: '', type: 'uint256' }],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [
      { internalType: 'uint256', name: 'positionIndex', type: 'uint256' },
      { internalType: 'uint256', name: 'amount', type: 'uint256' },
    ],
    name: 'withdrawFromPosition',
    outputs: [],
    stateMutability: 'nonpayable',
    type: 'function',
  },
  // Correct function signatures based on actual contract
  {
    inputs: [],
    name: 'getDepositPositions',
    outputs: [
      {
        components: [
          { internalType: 'address[]', name: 'tokens', type: 'address[]' },
          { internalType: 'uint256[]', name: 'amounts', type: 'uint256[]' },
          { internalType: 'uint256', name: 'totalValueUSD', type: 'uint256' },
          { internalType: 'uint256', name: 'aiusdMinted', type: 'uint256' },
          { internalType: 'uint256', name: 'collateralRatio', type: 'uint256' },
          { internalType: 'uint256', name: 'requestId', type: 'uint256' },
          { internalType: 'bool', name: 'hasPendingRequest', type: 'bool' },
          { internalType: 'uint256', name: 'timestamp', type: 'uint256' },
          { internalType: 'uint16', name: 'index', type: 'uint16' },
        ],
        internalType: 'struct Position[]',
        name: 'activePositions',
        type: 'tuple[]',
      },
    ],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [{ internalType: 'address', name: 'user', type: 'address' }],
    name: 'getPositionSummary',
    outputs: [
      { internalType: 'uint256', name: 'totalPositions', type: 'uint256' },
      { internalType: 'uint256', name: 'activePositions', type: 'uint256' },
      { internalType: 'uint256', name: 'totalValueUSD', type: 'uint256' },
      { internalType: 'uint256', name: 'totalAIUSDMinted', type: 'uint256' },
    ],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [
      { internalType: 'address', name: '_user', type: 'address' },
      { internalType: 'uint256', name: '_index', type: 'uint256' },
    ],
    name: 'getUserDepositInfo',
    outputs: [
      {
        components: [
          { internalType: 'address[]', name: 'tokens', type: 'address[]' },
          { internalType: 'uint256[]', name: 'amounts', type: 'uint256[]' },
          { internalType: 'uint256', name: 'totalValueUSD', type: 'uint256' },
          { internalType: 'uint256', name: 'aiusdMinted', type: 'uint256' },
          { internalType: 'uint256', name: 'collateralRatio', type: 'uint256' },
          { internalType: 'uint256', name: 'requestId', type: 'uint256' },
          { internalType: 'bool', name: 'hasPendingRequest', type: 'bool' },
          { internalType: 'uint256', name: 'timestamp', type: 'uint256' },
          { internalType: 'uint16', name: 'index', type: 'uint16' },
        ],
        internalType: 'struct Position',
        name: 'position',
        type: 'tuple',
      },
    ],
    stateMutability: 'view',
    type: 'function',
  },
] as const;

// CCIP Bridge ABI
export const CCIP_BRIDGE_ABI = [
  {
    inputs: [
      {
        internalType: 'uint64',
        name: '_destinationChainSelector',
        type: 'uint64',
      },
      { internalType: 'address', name: '_recipient', type: 'address' },
      { internalType: 'uint256', name: '_amount', type: 'uint256' },
      { internalType: 'uint8', name: '_payFeesIn', type: 'uint8' },
    ],
    name: 'bridgeTokens',
    outputs: [{ internalType: 'bytes32', name: 'messageId', type: 'bytes32' }],
    stateMutability: 'payable',
    type: 'function',
  },
  {
    inputs: [
      {
        internalType: 'uint64',
        name: '_destinationChainSelector',
        type: 'uint64',
      },
      {
        components: [
          { internalType: 'bytes', name: 'receiver', type: 'bytes' },
          { internalType: 'bytes', name: 'data', type: 'bytes' },
          {
            components: [
              { internalType: 'address', name: 'token', type: 'address' },
              { internalType: 'uint256', name: 'amount', type: 'uint256' },
            ],
            internalType: 'struct Client.EVMTokenAmount[]',
            name: 'tokenAmounts',
            type: 'tuple[]',
          },
          { internalType: 'address', name: 'feeToken', type: 'address' },
          { internalType: 'bytes', name: 'extraArgs', type: 'bytes' },
        ],
        internalType: 'struct Client.EVM2AnyMessage',
        name: '_message',
        type: 'tuple',
      },
    ],
    name: 'getFee',
    outputs: [{ internalType: 'uint256', name: 'fee', type: 'uint256' }],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [
      {
        internalType: 'uint64',
        name: '_destinationChainSelector',
        type: 'uint64',
      },
      { internalType: 'uint256', name: '_amount', type: 'uint256' },
      { internalType: 'uint8', name: '_payFeesIn', type: 'uint8' },
    ],
    name: 'calculateBridgeFees',
    outputs: [{ internalType: 'uint256', name: 'fees', type: 'uint256' }],
    stateMutability: 'view',
    type: 'function',
  },
] as const;

export const ERC20_ABI = [
  {
    inputs: [{ internalType: 'address', name: 'owner', type: 'address' }],
    name: 'balanceOf',
    outputs: [{ internalType: 'uint256', name: '', type: 'uint256' }],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [
      { internalType: 'address', name: 'spender', type: 'address' },
      { internalType: 'uint256', name: 'amount', type: 'uint256' },
    ],
    name: 'approve',
    outputs: [{ internalType: 'bool', name: '', type: 'bool' }],
    stateMutability: 'nonpayable',
    type: 'function',
  },
  {
    inputs: [
      { internalType: 'address', name: 'owner', type: 'address' },
      { internalType: 'address', name: 'spender', type: 'address' },
    ],
    name: 'allowance',
    outputs: [{ internalType: 'uint256', name: '', type: 'uint256' }],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [],
    name: 'symbol',
    outputs: [{ internalType: 'string', name: '', type: 'string' }],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [
      { internalType: 'address', name: 'from', type: 'address' },
      { internalType: 'uint256', name: 'amount', type: 'uint256' },
    ],
    name: 'burnFrom',
    outputs: [],
    stateMutability: 'nonpayable',
    type: 'function',
  },
] as const;

export const AI_STABLECOIN_ABI = [
  {
    inputs: [{ internalType: 'address', name: 'owner', type: 'address' }],
    name: 'balanceOf',
    outputs: [{ internalType: 'uint256', name: '', type: 'uint256' }],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [],
    name: 'totalSupply',
    outputs: [{ internalType: 'uint256', name: '', type: 'uint256' }],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [
      { internalType: 'address', name: 'spender', type: 'address' },
      { internalType: 'uint256', name: 'amount', type: 'uint256' },
    ],
    name: 'approve',
    outputs: [{ internalType: 'bool', name: '', type: 'bool' }],
    stateMutability: 'nonpayable',
    type: 'function',
  },
  {
    inputs: [
      { internalType: 'address', name: 'from', type: 'address' },
      { internalType: 'uint256', name: 'amount', type: 'uint256' },
    ],
    name: 'burnFrom',
    outputs: [],
    stateMutability: 'nonpayable',
    type: 'function',
  },
  {
    inputs: [],
    name: 'symbol',
    outputs: [{ internalType: 'string', name: '', type: 'string' }],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [],
    name: 'decimals',
    outputs: [{ internalType: 'uint8', name: '', type: 'uint8' }],
    stateMutability: 'view',
    type: 'function',
  },
] as const;

// AI Engine types - aligned with smart contract Engine enum
export enum AIEngine {
  ALGORITHMIC = 0, // Maps to Engine.ALGO (default, fast)
  BEDROCK = 1, // Maps to Engine.BEDROCK (enterprise AI)
  MANUAL = 2, // Maps to Engine.TEST_TIMEOUT (manual/fallback)
}

// CCIP Fee payment types
export enum PayFeesIn {
  Native = 0,
  LINK = 1,
}

// Utility functions
export function formatTokenAmount(
  amount: bigint,
  decimals: number = 18,
  maxDecimals: number = 4
): string {
  const divisor = BigInt(10 ** decimals);
  const quotient = amount / divisor;
  const remainder = amount % divisor;

  if (remainder === BigInt(0)) return quotient.toString();

  const remainderStr = remainder.toString().padStart(decimals, '0');
  const trimmed = remainderStr.replace(/0+$/, '');

  if (!trimmed) return quotient.toString();

  // Limit decimal places for display
  const limitedDecimals =
    trimmed.length > maxDecimals ? trimmed.slice(0, maxDecimals) : trimmed;
  return `${quotient.toString()}.${limitedDecimals}`;
}

export function parseTokenAmount(
  amount: string,
  decimals: number = 18
): bigint {
  const [whole, fraction = ''] = amount.split('.');
  const paddedFraction = fraction.padEnd(decimals, '0').slice(0, decimals);
  return BigInt(whole + paddedFraction);
}

// Chain utilities
export function getChainContracts(chainId: number) {
  switch (chainId) {
    case 11155111: // Sepolia
      return CONTRACTS.SEPOLIA;
    case 43113: // Fuji
      return CONTRACTS.FUJI;
    default:
      return CONTRACTS.SEPOLIA;
  }
}

export function getChainName(chainId: number): string {
  switch (chainId) {
    case 11155111:
      return 'Sepolia';
    case 43113:
      return 'Avalanche Fuji';
    default:
      return 'Unknown';
  }
}

export function getChainSelector(chainId: number): bigint {
  if (chainId === 11155111) return CHAIN_SELECTORS.SEPOLIA;
  if (chainId === 43113) return CHAIN_SELECTORS.FUJI;
  throw new Error(`Unsupported chain ID: ${chainId}`);
}

// Custom hook to fetch real-time prices from Chainlink Data Feeds
import { useReadContract } from 'wagmi';
import { useMemo } from 'react';

export function useRealTimePrices(chainId: number) {
  const contracts = getChainContracts(chainId);
  const isRiskControllerAvailable =
    'RISK_ORACLE_CONTROLLER' in contracts &&
    contracts.RISK_ORACLE_CONTROLLER &&
    contracts.RISK_ORACLE_CONTROLLER !== '0x';

  // Fetch prices for all supported tokens from Chainlink Data Feeds
  const { data: ethPrice } = useReadContract({
    address: isRiskControllerAvailable
      ? (contracts as { RISK_ORACLE_CONTROLLER: `0x${string}` })
          .RISK_ORACLE_CONTROLLER
      : undefined,
    abi: RISK_ORACLE_CONTROLLER_ABI,
    functionName: 'getLatestPrice',
    args: ['ETH'],
    query: {
      enabled: isRiskControllerAvailable,
      staleTime: 30 * 1000, // 30 seconds cache
    },
  });

  const { data: btcPrice } = useReadContract({
    address: isRiskControllerAvailable
      ? (contracts as { RISK_ORACLE_CONTROLLER: `0x${string}` })
          .RISK_ORACLE_CONTROLLER
      : undefined,
    abi: RISK_ORACLE_CONTROLLER_ABI,
    functionName: 'getLatestPrice',
    args: ['BTC'],
    query: {
      enabled: isRiskControllerAvailable,
      staleTime: 30 * 1000,
    },
  });

  const { data: linkPrice } = useReadContract({
    address: isRiskControllerAvailable
      ? (contracts as { RISK_ORACLE_CONTROLLER: `0x${string}` })
          .RISK_ORACLE_CONTROLLER
      : undefined,
    abi: RISK_ORACLE_CONTROLLER_ABI,
    functionName: 'getLatestPrice',
    args: ['LINK'],
    query: {
      enabled: isRiskControllerAvailable,
      staleTime: 30 * 1000,
    },
  });

  const { data: daiPrice } = useReadContract({
    address: isRiskControllerAvailable
      ? (contracts as { RISK_ORACLE_CONTROLLER: `0x${string}` })
          .RISK_ORACLE_CONTROLLER
      : undefined,
    abi: RISK_ORACLE_CONTROLLER_ABI,
    functionName: 'getLatestPrice',
    args: ['DAI'],
    query: {
      enabled: isRiskControllerAvailable,
      staleTime: 30 * 1000,
    },
  });

  const { data: usdcPrice } = useReadContract({
    address: isRiskControllerAvailable
      ? (contracts as { RISK_ORACLE_CONTROLLER: `0x${string}` })
          .RISK_ORACLE_CONTROLLER
      : undefined,
    abi: RISK_ORACLE_CONTROLLER_ABI,
    functionName: 'getLatestPrice',
    args: ['USDC'],
    query: {
      enabled: isRiskControllerAvailable,
      staleTime: 30 * 1000,
    },
  });

  const { data: ousgPrice } = useReadContract({
    address: isRiskControllerAvailable
      ? (contracts as { RISK_ORACLE_CONTROLLER: `0x${string}` })
          .RISK_ORACLE_CONTROLLER
      : undefined,
    abi: RISK_ORACLE_CONTROLLER_ABI,
    functionName: 'getLatestPrice',
    args: ['OUSG'],
    query: {
      enabled: isRiskControllerAvailable,
      staleTime: 30 * 1000,
    },
  });

  // Create updated tokens configuration with real-time prices
  const tokensWithRealPrices = useMemo(() => {
    const updatedTokens = { ...TOKENS };

    // Update prices if we have real-time data (prices come in 8 decimals, convert to whole numbers)
    if (ethPrice && Number(ethPrice) > 0) {
      updatedTokens.WETH = {
        ...updatedTokens.WETH,
        price: Number(ethPrice) / 1e8,
      };
    }
    if (btcPrice && Number(btcPrice) > 0) {
      updatedTokens.WBTC = {
        ...updatedTokens.WBTC,
        price: Number(btcPrice) / 1e8,
      };
    }
    if (linkPrice && Number(linkPrice) > 0) {
      updatedTokens.LINK = {
        ...updatedTokens.LINK,
        price: Number(linkPrice) / 1e8,
      };
    }
    if (daiPrice && Number(daiPrice) > 0) {
      updatedTokens.DAI = {
        ...updatedTokens.DAI,
        price: Number(daiPrice) / 1e8,
      };
    }
    if (usdcPrice && Number(usdcPrice) > 0) {
      updatedTokens.USDC = {
        ...updatedTokens.USDC,
        price: Number(usdcPrice) / 1e8,
      };
    }
    if (ousgPrice && Number(ousgPrice) > 0) {
      updatedTokens.OUSG = {
        ...updatedTokens.OUSG,
        price: Number(ousgPrice) / 1e8,
      };
    }

    return updatedTokens;
  }, [ethPrice, btcPrice, linkPrice, daiPrice, usdcPrice, ousgPrice]);

  const priceUpdateStatus = {
    isLoading:
      !isRiskControllerAvailable || (!ethPrice && !btcPrice && !linkPrice),
    hasRealPrices:
      isRiskControllerAvailable && (ethPrice || btcPrice || linkPrice),
    lastUpdate: Date.now(),
  };

  return {
    tokens: tokensWithRealPrices,
    priceStatus: priceUpdateStatus,
    rawPrices: {
      ETH: ethPrice ? Number(ethPrice) / 1e8 : null,
      BTC: btcPrice ? Number(btcPrice) / 1e8 : null,
      LINK: linkPrice ? Number(linkPrice) / 1e8 : null,
      DAI: daiPrice ? Number(daiPrice) / 1e8 : null,
      USDC: usdcPrice ? Number(usdcPrice) / 1e8 : null,
      OUSG: ousgPrice ? Number(ousgPrice) / 1e8 : null,
    },
  };
}
