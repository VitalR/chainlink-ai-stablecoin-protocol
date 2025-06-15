import { getDefaultConfig } from '@rainbow-me/rainbowkit';
import { sepolia } from 'wagmi/chains';

// Contract addresses from deployment
export const CONTRACTS = {
  AI_STABLECOIN: '0xb4036672FE9f82ff0B9149beBD6721538e085ffa' as `0x${string}`,
  AI_CONTROLLER: '0xdE56263d5d478E0926da56375CD9927d5EE3af72' as `0x${string}`,
  AI_VAULT: '0x3b8Fd1cB957B96e9082c270938B1C1C083e3fb94' as `0x${string}`,
  MOCK_DAI: '0xF19061331751efd44eCd2E9f49903b7D68651368' as `0x${string}`,
  MOCK_WETH: '0x7f4eb26422b35D3AA5a72D7711aD12905bb69F59' as `0x${string}`,
  MOCK_WBTC: '0x4a098CaCd639aE0CC70F6f03d4A01608286b155d' as `0x${string}`,
} as const;

// Token configurations
export const TOKENS = {
  DAI: { address: CONTRACTS.MOCK_DAI, symbol: 'DAI', decimals: 18, price: 1 },
  WETH: {
    address: CONTRACTS.MOCK_WETH,
    symbol: 'WETH',
    decimals: 18,
    price: 2000,
  },
  WBTC: {
    address: CONTRACTS.MOCK_WBTC,
    symbol: 'WBTC',
    decimals: 18,
    price: 50000,
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
export const AI_CONTROLLER_ABI = [
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

export const AI_VAULT_ABI = [
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
