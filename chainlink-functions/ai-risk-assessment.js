// AI-Powered Collateral Risk Assessment for Stablecoin System
// Supports crypto assets + Real World Assets (RWAs) - Focus on OUSG institutional collateral

// Mock current prices for testing (in production, these come from Chainlink feeds)
const MOCK_PRICES = {
  DAI: 1.0,
  ETH: 2500,
  WETH: 2500, // Same as ETH - wrapped version
  BTC: 100000,
  WBTC: 100000, // Same as BTC - wrapped version
  LINK: 12.5,
  USDC: 1.0, // Stable (correct)

  // === REAL WORLD ASSETS (RWAs) ===
  // OUSG: Current NAV per token (appreciates daily with Treasury yields)
  // Note: Real OUSG NAV updated daily by Ondo Finance
  // For hackathon demo: Using simplified $100 price for easy calculations
  OUSG: 100.0, // Simplified price: $100 (started at $95, appreciating with Treasury yields)
  // Real implementation would fetch from Ondo's price oracle
};

// === ENHANCED AI RISK PROFILES ===
// Traditional crypto assets + RWA-specific profiles
const RISK_PROFILES = {
  // Crypto assets
  DAI: { volatility: 0.02, liquidity: 0.88, stability: 0.95 },
  ETH: { volatility: 0.75, liquidity: 0.95, stability: 0.65 },
  WETH: { volatility: 0.72, liquidity: 0.92, stability: 0.68 },
  WBTC: { volatility: 0.82, liquidity: 0.82, stability: 0.72 },
  BTC: { volatility: 0.8, liquidity: 0.85, stability: 0.7 },
  LINK: { volatility: 0.88, liquidity: 0.75, stability: 0.6 },
  USDC: { volatility: 0.03, liquidity: 0.92, stability: 0.96 },

  // === RWA RISK PROFILES ===
  OUSG: {
    volatility: 0.01, // Ultra-low volatility (Treasury-backed)
    liquidity: 0.75, // Good but not DEX-level liquidity
    stability: 0.98, // Extremely stable (government bonds)
    isRWA: true,
    backing: 'US_TREASURIES',
    yieldBearing: true,
    appreciating: true, // Key advantage over stablecoins
    institution: 'ONDO_FINANCE',
    tvl: 692000000, // $692M TVL - institutional scale
  },
  // USDY removed - business case analysis showed weak value proposition
};

// === RWA-ENHANCED AI FUNCTIONS ===

/**
 * Enhanced portfolio analysis that considers RWA characteristics
 */
function analyzePortfolioWithRWA(tokens, amounts, prices) {
  let totalValue = 0;
  let weightedVolatility = 0;
  let weightedLiquidity = 0;
  let weightedStability = 0;
  let rwaExposure = 0;
  let appreciatingAssetValue = 0;
  let treasuryBackedValue = 0;

  // Calculate portfolio metrics
  for (let i = 0; i < tokens.length; i++) {
    const token = tokens[i];
    const amount = amounts[i];
    const price = prices[token] || MOCK_PRICES[token] || 1;
    const value = amount * price;
    totalValue += value;

    const profile = RISK_PROFILES[token];
    if (profile) {
      const weight = value / totalValue;
      weightedVolatility += profile.volatility * weight;
      weightedLiquidity += profile.liquidity * weight;
      weightedStability += profile.stability * weight;

      // Track RWA exposure
      if (profile.isRWA) {
        rwaExposure += value;
      }

      // Track appreciating assets (key for OUSG business case)
      if (profile.appreciating) {
        appreciatingAssetValue += value;
      }

      // Track Treasury-backed assets
      if (profile.backing && profile.backing.includes('US_TREASURIES')) {
        treasuryBackedValue += value;
      }
    }
  }

  return {
    totalValue,
    weightedVolatility,
    weightedLiquidity,
    weightedStability,
    rwaExposure,
    rwaPercentage: (rwaExposure / totalValue) * 100,
    appreciatingPercentage: (appreciatingAssetValue / totalValue) * 100,
    treasuryPercentage: (treasuryBackedValue / totalValue) * 100,
    diversificationScore: calculateDiversificationScore(tokens),
  };
}

/**
 * RWA-aware collateral ratio calculation - optimized for OUSG institutional use case
 */
function calculateRWAEnhancedRatio(portfolioAnalysis, tokens) {
  let baseRatio = 150; // Conservative default

  // === OUSG INSTITUTIONAL BONUSES ===
  // Treasury-backed appreciating assets get significant advantages
  if (portfolioAnalysis.treasuryPercentage > 0) {
    // Major bonus for government backing
    const treasuryBonus = Math.min(
      portfolioAnalysis.treasuryPercentage * 0.4,
      25
    ); // Up to 25% bonus
    baseRatio -= treasuryBonus;

    // Additional bonus for large institutional exposure
    if (portfolioAnalysis.treasuryPercentage > 50) {
      baseRatio -= 5; // Extra bonus for institutional-scale positions
    }
  }

  // === APPRECIATING ASSET BONUS ===
  // OUSG appreciates, making it safer over time
  if (portfolioAnalysis.appreciatingPercentage > 0) {
    const appreciationBonus = Math.min(
      portfolioAnalysis.appreciatingPercentage * 0.2,
      10
    );
    baseRatio -= appreciationBonus;
  }

  // === TRADITIONAL RISK ADJUSTMENTS ===
  // Volatility penalty (minimal for Treasury assets)
  const volatilityPenalty = portfolioAnalysis.weightedVolatility * 30;
  const institutionalDiscount = portfolioAnalysis.treasuryPercentage * 0.7; // Institutions reduce volatility impact
  baseRatio += Math.max(0, volatilityPenalty - institutionalDiscount);

  // Liquidity adjustment
  const liquidityBonus = (portfolioAnalysis.weightedLiquidity - 0.5) * 20;
  baseRatio -= liquidityBonus;

  // Stability bonus (huge for Treasury assets)
  const stabilityBonus = (portfolioAnalysis.weightedStability - 0.7) * 20;
  baseRatio -= stabilityBonus;

  // Diversification bonus
  const diversificationBonus =
    (portfolioAnalysis.diversificationScore - 0.5) * 10;
  baseRatio -= diversificationBonus;

  // Ensure reasonable bounds (lower minimum for institutional assets)
  return Math.max(105, Math.min(200, Math.round(baseRatio)));
}

/**
 * Generate RWA-aware confidence score
 */
function calculateRWAConfidence(portfolioAnalysis, ratio, tokens) {
  let confidence = 85; // Base confidence

  // === INSTITUTIONAL CONFIDENCE BOOSTS ===
  if (portfolioAnalysis.treasuryPercentage > 0) {
    // Treasury backing massively increases confidence
    confidence += Math.min(portfolioAnalysis.treasuryPercentage * 0.2, 10);

    // ONDO institutional backing
    const ondoTokens = tokens.filter((token) => {
      const profile = RISK_PROFILES[token];
      return profile && profile.institution === 'ONDO_FINANCE';
    });

    if (ondoTokens.length > 0) {
      confidence += 8; // Institutional backing increases confidence
    }
  }

  // === TRADITIONAL FACTORS ===
  // High stability increases confidence
  confidence += (portfolioAnalysis.weightedStability - 0.7) * 25;

  // Good liquidity increases confidence
  confidence += (portfolioAnalysis.weightedLiquidity - 0.6) * 15;

  // Lower volatility increases confidence
  confidence += (0.5 - portfolioAnalysis.weightedVolatility) * 15;

  // Diversification increases confidence
  confidence += portfolioAnalysis.diversificationScore * 10;

  // Conservative ratios increase confidence
  if (ratio < 120) confidence += 8; // Very conservative for institutions
  if (ratio > 160) confidence -= 5;

  return Math.max(75, Math.min(99, Math.round(confidence)));
}

// === MAIN AI PROCESSING FUNCTION ===
async function processCollateralAssessment(basketData) {
  try {
    console.log('🤖 AI analyzing collateral with institutional RWA support...');
    console.log('📊 Input data:', basketData);

    // Parse the basket
    const tokens = [];
    const amounts = [];

    if (basketData && typeof basketData === 'string') {
      const pairs = basketData.split(',');
      for (const pair of pairs) {
        const [symbol, amount] = pair.split(':');
        if (symbol && amount) {
          tokens.push(symbol.trim());
          amounts.push(parseFloat(amount));
        }
      }
    }

    if (tokens.length === 0) {
      throw new Error('No valid tokens found in basket data');
    }

    console.log('🔍 Parsed tokens:', tokens);
    console.log('💰 Amounts:', amounts);

    // Enhanced portfolio analysis with RWA support
    const portfolioAnalysis = analyzePortfolioWithRWA(
      tokens,
      amounts,
      MOCK_PRICES
    );
    console.log('📈 Portfolio analysis:', portfolioAnalysis);

    // Calculate RWA-enhanced collateral ratio
    const ratio = calculateRWAEnhancedRatio(portfolioAnalysis, tokens);

    // Calculate RWA-aware confidence
    const confidence = calculateRWAConfidence(portfolioAnalysis, ratio, tokens);

    // Determine AI source
    let source = 'ALGORITHMIC_AI';
    if (portfolioAnalysis.treasuryPercentage > 30) {
      source = 'INSTITUTIONAL_RWA_AI';
    } else if (portfolioAnalysis.rwaPercentage > 0) {
      source = 'RWA_ENHANCED_AI';
    }

    const result = `RATIO:${ratio} CONFIDENCE:${confidence} SOURCE:${source}`;

    console.log('✅ AI Result:', result);
    console.log(
      '🏛️ Treasury Exposure:',
      portfolioAnalysis.treasuryPercentage.toFixed(1) + '%'
    );
    console.log(
      '📈 Appreciating Assets:',
      portfolioAnalysis.appreciatingPercentage.toFixed(1) + '%'
    );

    return result;
  } catch (error) {
    console.error('❌ AI processing error:', error);

    // Conservative fallback
    return 'RATIO:150 CONFIDENCE:75 SOURCE:FALLBACK_AI';
  }
}

// Helper function for diversification score
function calculateDiversificationScore(tokens) {
  if (tokens.length <= 1) return 0.2;
  if (tokens.length === 2) return 0.6;
  if (tokens.length === 3) return 0.8;
  return 0.9;
}

// === CHAINLINK FUNCTIONS ENTRY POINT ===
const result = await processCollateralAssessment(args[0]);

// Convert string result to bytes as required by Chainlink Functions
return Functions.encodeString(result);
