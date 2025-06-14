import { getDefaultConfig } from '@rainbow-me/rainbowkit';
import { sepolia } from 'wagmi/chains';

// Contract addresses from deployment
export const CONTRACTS = {
  AI_STABLECOIN: '0xb4036672FE9f82ff0B9149beBD6721538e085ffa',
  AI_CONTROLLER: '0x0C8516a5B5465547746DFB0cA80897E456Cc68C8',
  AI_VAULT: '0x0d8a34dCD87b50291c4F7b0706Bfde71Abd1aFf2',
  MOCK_DAI: '0x68194a729C2450ad26072b3D33ADaCbcef39D574',
  MOCK_WETH: '0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14',
  MOCK_WBTC: '0x29f2D40B0605204364af54EC677bD022dA425d03',
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
  'function estimateTotalFee() external view returns (uint256)',
  'function getRequestInfo(uint256 requestId) external view returns (tuple(address user, address vault, bytes basketData, uint256 collateralValue, uint256 timestamp, bool processed))',
] as const;

export const AI_VAULT_ABI = [
  'function depositBasket(address[] calldata tokens, uint256[] calldata amounts) external payable',
  'function getPosition(address user) external view returns (tuple(address[] tokens, uint256[] amounts, uint256 totalValue, uint256 aiusdMinted, uint256 collateralRatio, uint256 requestId, bool hasPendingRequest))',
] as const;

export const ERC20_ABI = [
  'function balanceOf(address owner) external view returns (uint256)',
  'function approve(address spender, uint256 amount) external returns (bool)',
  'function allowance(address owner, address spender) external view returns (uint256)',
  'function symbol() external view returns (string)',
] as const;

export const AI_STABLECOIN_ABI = [
  'function balanceOf(address owner) external view returns (uint256)',
  'function totalSupply() external view returns (uint256)',
] as const;

// Utility functions
export function formatTokenAmount(
  amount: bigint,
  decimals: number = 18
): string {
  const divisor = BigInt(10 ** decimals);
  const quotient = amount / divisor;
  const remainder = amount % divisor;

  if (remainder === 0n) return quotient.toString();

  const remainderStr = remainder.toString().padStart(decimals, '0');
  const trimmed = remainderStr.replace(/0+$/, '');
  return trimmed ? `${quotient}.${trimmed}` : quotient.toString();
}

export function parseTokenAmount(
  amount: string,
  decimals: number = 18
): bigint {
  const [whole, fraction = ''] = amount.split('.');
  const paddedFraction = fraction.padEnd(decimals, '0').slice(0, decimals);
  return BigInt(whole + paddedFraction);
}
