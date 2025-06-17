// AI Risk Assessment for Chainlink Functions
// This code runs on Chainlink's decentralized oracle network

// The main function that Chainlink Functions will execute
const basketData = args[0]; // Encoded collateral basket data
const collateralValue = parseInt(args[1]); // Total collateral value in USD
const currentPrices = JSON.parse(args[2]); // Current token prices

// Parse basket data to understand collateral composition
function parseBasketData(data) {
  try {
    // Assuming basketData is JSON string with token composition
    const basket = JSON.parse(data);
    return basket;
  } catch (error) {
    // Fallback parsing or default basket
    return {
      ETH: 0.5, // 50% ETH
      WBTC: 0.3, // 30% WBTC
      DAI: 0.2, // 20% DAI
    };
  }
}

// AI-powered risk assessment algorithm
function assessRisk(basket, totalValue, prices) {
  let riskScore = 0;
  let diversificationBonus = 0;
  let volatilityPenalty = 0;
  let liquidityScore = 0;

  // Token-specific risk factors
  const tokenRiskProfiles = {
    ETH: { volatility: 0.8, liquidity: 0.9, stability: 0.6 },
    WETH: { volatility: 0.8, liquidity: 0.9, stability: 0.6 },
    WBTC: { volatility: 0.9, liquidity: 0.8, stability: 0.7 },
    BTC: { volatility: 0.9, liquidity: 0.8, stability: 0.7 },
    DAI: { volatility: 0.1, liquidity: 0.9, stability: 0.95 },
    USDC: { volatility: 0.1, liquidity: 0.95, stability: 0.95 },
    USDT: { volatility: 0.15, liquidity: 0.9, stability: 0.9 },
  };

  const tokens = Object.keys(basket);
  const weights = Object.values(basket);

  // 1. Diversification Analysis
  if (tokens.length >= 3) {
    diversificationBonus = 15; // 15% bonus for 3+ tokens
  } else if (tokens.length === 2) {
    diversificationBonus = 8; // 8% bonus for 2 tokens
  }

  // Check if basket has stablecoin component
  const stablecoins = ['DAI', 'USDC', 'USDT'];
  const hasStablecoin = tokens.some((token) => stablecoins.includes(token));
  if (hasStablecoin) {
    diversificationBonus += 10; // Additional 10% for stablecoin inclusion
  }

  // 2. Weighted Risk Calculation
  let weightedVolatility = 0;
  let weightedLiquidity = 0;
  let weightedStability = 0;

  for (let i = 0; i < tokens.length; i++) {
    const token = tokens[i];
    const weight = weights[i];
    const profile = tokenRiskProfiles[token] || {
      volatility: 0.5,
      liquidity: 0.5,
      stability: 0.5,
    };

    weightedVolatility += profile.volatility * weight;
    weightedLiquidity += profile.liquidity * weight;
    weightedStability += profile.stability * weight;
  }

  // 3. Position Size Analysis
  let positionSizeRisk = 0;
  if (totalValue > 100000) {
    // > $100k
    positionSizeRisk = 5; // 5% penalty for large positions
  } else if (totalValue > 50000) {
    // > $50k
    positionSizeRisk = 2; // 2% penalty for medium positions
  }

  // 4. Market Sentiment Simulation (simplified)
  const marketSentiment = Math.random() * 0.4 + 0.6; // Random between 0.6-1.0
  const sentimentAdjustment = (1 - marketSentiment) * 10; // Up to 4% adjustment

  // 5. Calculate Final Risk Score
  const baseRisk = weightedVolatility * 100; // Convert to percentage
  const liquidityBonus = weightedLiquidity * 5; // Up to 5% bonus
  const stabilityBonus = weightedStability * 10; // Up to 10% bonus

  riskScore =
    baseRisk -
    diversificationBonus -
    liquidityBonus -
    stabilityBonus +
    positionSizeRisk +
    sentimentAdjustment;

  // Ensure risk score is within reasonable bounds
  riskScore = Math.max(20, Math.min(80, riskScore)); // Between 20-80%

  return {
    riskScore: riskScore,
    diversificationBonus: diversificationBonus,
    weightedVolatility: weightedVolatility,
    weightedLiquidity: weightedLiquidity,
    marketSentiment: marketSentiment,
    tokens: tokens.length,
  };
}

// Convert risk score to collateral ratio
function calculateOptimalRatio(riskAnalysis) {
  const { riskScore, diversificationBonus, tokens } = riskAnalysis;

  // Base ratio calculation
  // Lower risk = lower collateral requirement
  // Higher risk = higher collateral requirement

  let baseRatio = 130; // Start with 130%

  // Risk adjustment (higher risk = higher ratio)
  const riskAdjustment = riskScore * 0.5; // 0.5% per risk point

  // Diversification bonus (more diversification = lower ratio)
  const diversificationDiscount = diversificationBonus * 0.3; // 0.3% per bonus point

  // Token count bonus
  const tokenCountBonus = Math.min(tokens * 2, 8); // Up to 8% bonus for multiple tokens

  // Calculate final ratio
  let finalRatio =
    baseRatio + riskAdjustment - diversificationDiscount - tokenCountBonus;

  // Apply bounds (125% to 200%)
  finalRatio = Math.max(125, Math.min(200, finalRatio));

  return Math.round(finalRatio);
}

// Calculate confidence score
function calculateConfidence(riskAnalysis) {
  const { weightedLiquidity, tokens, diversificationBonus } = riskAnalysis;

  let confidence = 50; // Base confidence

  // Liquidity confidence
  confidence += weightedLiquidity * 20; // Up to 20 points for liquidity

  // Diversification confidence
  confidence += Math.min(diversificationBonus, 15); // Up to 15 points for diversification

  // Token count confidence
  confidence += Math.min(tokens * 5, 15); // Up to 15 points for token diversity

  // Ensure confidence is within bounds
  confidence = Math.max(30, Math.min(95, confidence));

  return Math.round(confidence);
}

// Main execution
try {
  // Parse the collateral basket
  const basket = parseBasketData(basketData);

  // Perform AI risk assessment
  const riskAnalysis = assessRisk(basket, collateralValue, currentPrices);

  // Calculate optimal collateral ratio
  const optimalRatio = calculateOptimalRatio(riskAnalysis);

  // Calculate confidence score
  const confidence = calculateConfidence(riskAnalysis);

  // Format response for the smart contract
  const response = `RATIO:${optimalRatio} CONFIDENCE:${confidence}`;

  // Return the response (this is what gets sent back to the smart contract)
  return Functions.encodeString(response);
} catch (error) {
  // Fallback response in case of error
  const fallbackResponse = 'RATIO:150 CONFIDENCE:50';
  return Functions.encodeString(fallbackResponse);
}
