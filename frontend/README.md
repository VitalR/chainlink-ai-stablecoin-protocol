# AI Stablecoin Frontend

A beautiful, modern React frontend for the AI Stablecoin system built with Next.js, TypeScript, and Tailwind CSS.

## Features

🤖 **AI-Powered**: Connect to ORA Oracle for intelligent collateral ratio determination
🔗 **Web3 Integration**: Full wallet connectivity with RainbowKit
📊 **Real-time Data**: Live position tracking and system statistics
💎 **Multi-token Support**: Deposit DAI, WETH, and WBTC as collateral
🎨 **Modern UI**: Beautiful, responsive design with Tailwind CSS

## Quick Start

```bash
# Install dependencies
npm install

# Start development server
npm run dev
```

Open [http://localhost:3000](http://localhost:3000) to view the app.

## Smart Contract Integration

The frontend connects to deployed contracts on Sepolia testnet:

- **AI Stablecoin**: `0xb4036672FE9f82ff0B9149beBD6721538e085ffa`
- **AI Controller**: `0x0C8516a5B5465547746DFB0cA80897E456Cc68C8`
- **Collateral Vault**: `0x0d8a34dCD87b50291c4F7b0706Bfde71Abd1aFf2`

## How It Works

1. **Connect Wallet**: Connect your MetaMask or other Web3 wallet
2. **Deposit Collateral**: Choose tokens (DAI, WETH, WBTC) and amounts
3. **AI Processing**: ORA Oracle analyzes your collateral basket
4. **Mint AIUSD**: Receive stablecoins based on AI-determined ratios
5. **Manage Position**: Monitor and withdraw your collateral

## Tech Stack

- **Next.js 15** - React framework
- **TypeScript** - Type safety
- **Tailwind CSS** - Styling
- **Wagmi** - Ethereum interactions
- **RainbowKit** - Wallet connectivity
- **Viem** - Ethereum utilities

## Development

```bash
# Install dependencies
npm install

# Start dev server
npm run dev

# Build for production
npm run build

# Start production server
npm start
```

## Environment Variables

Create a `.env.local` file:

```env
NEXT_PUBLIC_WALLET_CONNECT_PROJECT_ID=your_project_id
```

## Contract ABIs

The frontend includes simplified ABIs for:

- AI Controller (fee estimation, request info)
- Collateral Vault (deposits, position tracking)
- ERC20 tokens (balances, approvals)
- AI Stablecoin (balance, total supply)

## Features

### Deposit Form

- Multi-token selection
- Real-time USD value calculation
- Balance checking
- Transaction handling

### User Position

- Collateral breakdown
- AI request status
- AIUSD balance
- Withdrawal options

### System Stats

- Total AIUSD supply
- Network information
- Oracle status

Built with ❤️ for the AI Stablecoin hackathon project.

## Learn More

To learn more about Next.js, take a look at the following resources:

- [Next.js Documentation](https://nextjs.org/docs) - learn about Next.js features and API.
- [Learn Next.js](https://nextjs.org/learn) - an interactive Next.js tutorial.

You can check out [the Next.js GitHub repository](https://github.com/vercel/next.js) - your feedback and contributions are welcome!

## Deploy on Vercel

The easiest way to deploy your Next.js app is to use the [Vercel Platform](https://vercel.com/new?utm_medium=default-template&filter=next.js&utm_source=create-next-app&utm_campaign=create-next-app-readme) from the creators of Next.js.

Check out our [Next.js deployment documentation](https://nextjs.org/docs/app/building-your-application/deploying) for more details.
