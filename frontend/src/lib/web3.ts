import { getDefaultConfig } from '@rainbow-me/rainbowkit';
import { sepolia } from 'wagmi/chains';

// Contract addresses from deployment
export const CONTRACTS = {
  AIUSD: '0x5FbDB2315678afecb367f032d93F642f64180aa3' as `0x${string}`,
  COLLATERAL_VAULT:
    '0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512' as `0x${string}`,
  RISK_ORACLE_CONTROLLER:
    '0xdE56263d5d478E0926da56375CD9927d5EE3af72' as `0x${string}`,
  WETH: '0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0' as `0x${string}`,
  DAI: '0xCf7Ed3AccA5a467e9e704C703E8D87F634fB0Fc9' as `0x${string}`,
  USDC: '0xDc64a140Aa3E981100a9becA4E685f962f0cF6C9' as `0x${string}`,
  WBTC: '0x4a098CaCd639aE0CC70F6f03d4A01608286b155d' as `0x${string}`,
} as const;

// Token configurations
export const TOKENS = {
  DAI: { address: CONTRACTS.DAI, symbol: 'DAI', decimals: 18, price: 1 },
  WETH: {
    address: CONTRACTS.WETH,
    symbol: 'WETH',
    decimals: 18,
    price: 2000,
  },
  WBTC: {
    address: CONTRACTS.WBTC,
    symbol: 'WBTC',
    decimals: 8,
    price: 50000,
  },
  USDC: {
    address: CONTRACTS.USDC,
    symbol: 'USDC',
    decimals: 6,
    price: 1,
  },
} as const;

// Wagmi config
export const config = getDefaultConfig({
  appName: 'AI Stablecoin',
  projectId: 'demo',
  chains: [sepolia],
  ssr: true,
});

// Contract ABIs
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
    name: 'getPosition',
    outputs: [
      { internalType: 'address[]', name: 'tokens', type: 'address[]' },
      { internalType: 'uint256[]', name: 'amounts', type: 'uint256[]' },
      { internalType: 'uint256', name: 'totalValueUSD', type: 'uint256' },
      { internalType: 'uint256', name: 'aiusdMinted', type: 'uint256' },
      { internalType: 'uint256', name: 'collateralRatio', type: 'uint256' },
      { internalType: 'uint256', name: 'requestId', type: 'uint256' },
      { internalType: 'bool', name: 'hasPendingRequest', type: 'bool' },
    ],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [{ internalType: 'uint256', name: 'amount', type: 'uint256' }],
    name: 'withdrawCollateral',
    outputs: [],
    stateMutability: 'nonpayable',
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
      { internalType: 'address', name: 'owner', type: 'address' },
      { internalType: 'address', name: 'spender', type: 'address' },
    ],
    name: 'allowance',
    outputs: [{ internalType: 'uint256', name: '', type: 'uint256' }],
    stateMutability: 'view',
    type: 'function',
  },
] as const;

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
  return `${quotient}.${limitedDecimals}`;
}

export function parseTokenAmount(
  amount: string,
  decimals: number = 18
): bigint {
  const [whole, fraction = ''] = amount.split('.');
  const paddedFraction = fraction.padEnd(decimals, '0').slice(0, decimals);
  return BigInt(whole + paddedFraction);
}
