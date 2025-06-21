// AI Risk Assessment with WORKING AWS Bedrock Authentication
// This version uses Web Crypto API functions available in Chainlink Functions

// Handle undefined args gracefully
const basketData = args[0] || '{"ETH": 0.6, "DAI": 0.4}';
const collateralValue = parseInt(args[1]) || 5000;
const currentPrices = args[2]
  ? JSON.parse(args[2])
  : {
      ETH: 2000,
      WETH: 2000,
      BTC: 45000,
      WBTC: 45000,
      DAI: 1,
      USDC: 1,
    };

// Parse the basket data
let basket;
try {
  basket = JSON.parse(basketData);
} catch (error) {
  console.error('Error parsing basket data:', error);
  return Functions.encodeString('RATIO:150 CONFIDENCE:0 SOURCE:ERROR');
}

// Helper functions for AWS Signature v4 using Web Crypto API
function toHex(buffer) {
  return Array.from(new Uint8Array(buffer))
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('');
}

function toUint8Array(str) {
  return new TextEncoder().encode(str);
}

async function sha256(data) {
  const buffer = typeof data === 'string' ? toUint8Array(data) : data;
  const hashBuffer = await crypto.subtle.digest('SHA-256', buffer);
  return toHex(hashBuffer);
}

async function hmacSha256(key, data) {
  const keyBuffer = typeof key === 'string' ? toUint8Array(key) : key;
  const dataBuffer = typeof data === 'string' ? toUint8Array(data) : data;

  const cryptoKey = await crypto.subtle.importKey(
    'raw',
    keyBuffer,
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign']
  );

  const signature = await crypto.subtle.sign('HMAC', cryptoKey, dataBuffer);
  return new Uint8Array(signature);
}

// AWS Signature v4 implementation using Web Crypto API
async function createAwsSignature(
  accessKey,
  secretKey,
  region,
  service,
  method,
  url,
  body,
  timestamp
) {
  const date = timestamp.substr(0, 8);
  const credentialScope = `${date}/${region}/${service}/aws4_request`;

  // Create canonical request
  const bodyHash = await sha256(body || '');
  const canonicalHeaders = `host:bedrock-runtime.${region}.amazonaws.com\nx-amz-date:${timestamp}\n`;
  const signedHeaders = 'host;x-amz-date';
  const canonicalRequest = `${method}\n/model/anthropic.claude-3-sonnet-20240229-v1:0/invoke\n\n${canonicalHeaders}\n${signedHeaders}\n${bodyHash}`;

  // Create string to sign
  const canonicalRequestHash = await sha256(canonicalRequest);
  const stringToSign = `AWS4-HMAC-SHA256\n${timestamp}\n${credentialScope}\n${canonicalRequestHash}`;

  // Calculate signature
  const kDate = await hmacSha256(`AWS4${secretKey}`, date);
  const kRegion = await hmacSha256(kDate, region);
  const kService = await hmacSha256(kRegion, service);
  const kSigning = await hmacSha256(kService, 'aws4_request');
  const signature = await hmacSha256(kSigning, stringToSign);

  return `AWS4-HMAC-SHA256 Credential=${accessKey}/${credentialScope}, SignedHeaders=${signedHeaders}, Signature=${toHex(
    signature
  )}`;
}

// Amazon Bedrock integration with proper authentication
async function callAmazonBedrock(portfolio, prices, totalValue) {
  try {
    if (!secrets.AWS_ACCESS_KEY_ID || !secrets.AWS_SECRET_ACCESS_KEY) {
      console.log('AWS credentials not available, using algorithmic fallback');
      return null;
    }

    console.log('Attempting Bedrock integration with proper authentication...');

    const region = secrets.AWS_REGION || 'us-east-1';
    const timestamp = new Date().toISOString().replace(/[:\-]|\.\d{3}/g, '');

    const body = JSON.stringify({
      anthropic_version: 'bedrock-2023-05-31',
      max_tokens: 200,
      messages: [
        {
          role: 'user',
          content: `As a DeFi risk analyst, analyze this portfolio for optimal collateral ratio:

Portfolio: ${JSON.stringify(portfolio)}
Prices: ${JSON.stringify(prices)}
Value: $${totalValue}

Provide EXACT format:
RATIO:[125-200] CONFIDENCE:[50-95]

Consider diversification, volatility, liquidity. Be precise.`,
        },
      ],
    });

    const authorization = await createAwsSignature(
      secrets.AWS_ACCESS_KEY_ID,
      secrets.AWS_SECRET_ACCESS_KEY,
      region,
      'bedrock',
      'POST',
      `https://bedrock-runtime.${region}.amazonaws.com/model/anthropic.claude-3-sonnet-20240229-v1:0/invoke`,
      body,
      timestamp
    );

    const bedrockRequest = await Functions.makeHttpRequest({
      url: `https://bedrock-runtime.${region}.amazonaws.com/model/anthropic.claude-3-sonnet-20240229-v1:0/invoke`,
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-Amz-Date': timestamp,
        Authorization: authorization,
      },
      data: body,
      timeout: 9000,
    });

    if (bedrockRequest.error) {
      console.log(
        `Bedrock error: ${bedrockRequest.error}, using algorithmic fallback`
      );
      return null;
    }

    console.log('Bedrock response received successfully!');
    const response = bedrockRequest.data;
    const content = response.content[0].text;

    const ratioMatch = content.match(/RATIO:(\d+)/);
    const confidenceMatch = content.match(/CONFIDENCE:(\d+)/);

    if (ratioMatch && confidenceMatch) {
      return {
        ratio: parseInt(ratioMatch[1]),
        confidence: parseInt(confidenceMatch[1]),
        source: 'BEDROCK_AI',
      };
    }

    console.log('Could not parse Bedrock response, using algorithmic fallback');
    return null;
  } catch (error) {
    console.log(
      `Bedrock integration failed: ${error.message}, using algorithmic fallback`
    );
    return null;
  }
}

// Sophisticated Algorithmic AI Risk Assessment
function performAdvancedRiskAssessment(basket, collateralValue, prices) {
  console.log('Starting advanced algorithmic risk assessment...');

  // Calculate portfolio metrics
  const portfolioMetrics = calculatePortfolioMetrics(basket, prices);
  const diversificationScore = calculateDiversificationScore(basket);
  const volatilityScore = calculateVolatilityScore(basket, prices);
  const liquidityScore = calculateLiquidityScore(basket);
  const correlationRisk = calculateCorrelationRisk(basket);

  // Advanced risk scoring with multiple factors
  const riskFactors = {
    diversification: diversificationScore,
    volatility: volatilityScore,
    liquidity: liquidityScore,
    correlation: correlationRisk,
    marketConditions: assessMarketConditions(prices),
    concentrationRisk: calculateConcentrationRisk(basket),
  };

  console.log('Risk factors calculated:', riskFactors);

  // Determine optimal collateral ratio using advanced algorithm
  const baseRatio = 150; // Base 150% ratio
  let adjustment = 0;

  // Diversification adjustment (-15% to +20%)
  if (diversificationScore > 0.8) adjustment -= 15;
  else if (diversificationScore > 0.6) adjustment -= 10;
  else if (diversificationScore < 0.3) adjustment += 20;
  else if (diversificationScore < 0.5) adjustment += 10;

  // Volatility adjustment (-10% to +25%)
  if (volatilityScore < 0.3) adjustment -= 10;
  else if (volatilityScore > 0.7) adjustment += 25;
  else if (volatilityScore > 0.5) adjustment += 15;

  // Liquidity adjustment (-5% to +15%)
  if (liquidityScore > 0.8) adjustment -= 5;
  else if (liquidityScore < 0.4) adjustment += 15;
  else if (liquidityScore < 0.6) adjustment += 8;

  // Correlation risk adjustment (0% to +20%)
  if (correlationRisk > 0.7) adjustment += 20;
  else if (correlationRisk > 0.5) adjustment += 12;

  // Market conditions adjustment (-5% to +15%)
  const marketRisk = riskFactors.marketConditions;
  if (marketRisk < 0.3) adjustment -= 5;
  else if (marketRisk > 0.7) adjustment += 15;
  else if (marketRisk > 0.5) adjustment += 8;

  // Concentration risk adjustment (0% to +25%)
  if (riskFactors.concentrationRisk > 0.8) adjustment += 25;
  else if (riskFactors.concentrationRisk > 0.6) adjustment += 15;
  else if (riskFactors.concentrationRisk > 0.4) adjustment += 8;

  // Calculate final ratio with bounds
  const finalRatio = Math.max(125, Math.min(200, baseRatio + adjustment));

  // Calculate confidence based on data quality and risk factor consistency
  const confidence = calculateConfidence(riskFactors, portfolioMetrics);

  console.log(
    `Final assessment: Ratio=${finalRatio}%, Confidence=${confidence}%, Adjustment=${adjustment}%`
  );

  return {
    ratio: finalRatio,
    confidence: confidence,
    source: 'ALGORITHMIC_AI',
    riskFactors: riskFactors,
  };
}

function calculatePortfolioMetrics(basket, prices) {
  let totalValue = 0;
  const assetValues = {};

  for (const [asset, weight] of Object.entries(basket)) {
    const price = prices[asset] || prices[asset.toUpperCase()] || 1;
    const value = weight * price;
    assetValues[asset] = value;
    totalValue += value;
  }

  return {
    totalValue,
    assetValues,
    assetCount: Object.keys(basket).length,
  };
}

function calculateDiversificationScore(basket) {
  const weights = Object.values(basket);
  const numAssets = weights.length;

  if (numAssets <= 1) return 0.1;

  // Calculate Herfindahl-Hirschman Index for concentration
  const hhi = weights.reduce((sum, weight) => sum + weight * weight, 0);

  // Normalize to 0-1 scale (lower HHI = better diversification)
  const maxHHI = 1.0; // All in one asset
  const minHHI = 1.0 / numAssets; // Perfectly diversified

  const normalizedHHI = (maxHHI - hhi) / (maxHHI - minHHI);

  // Bonus for having more assets
  const assetBonus = Math.min(0.2, (numAssets - 1) * 0.05);

  return Math.max(0, Math.min(1, normalizedHHI + assetBonus));
}

function calculateVolatilityScore(basket, prices) {
  // Simplified volatility assessment based on asset types
  const volatilityMap = {
    BTC: 0.8,
    WBTC: 0.8,
    ETH: 0.7,
    WETH: 0.7,
    DAI: 0.1,
    USDC: 0.1,
    USDT: 0.1,
    LINK: 0.6,
    UNI: 0.7,
    AAVE: 0.7,
  };

  let weightedVolatility = 0;
  let totalWeight = 0;

  for (const [asset, weight] of Object.entries(basket)) {
    const volatility = volatilityMap[asset.toUpperCase()] || 0.5; // Default medium volatility
    weightedVolatility += weight * volatility;
    totalWeight += weight;
  }

  return totalWeight > 0 ? weightedVolatility / totalWeight : 0.5;
}

function calculateLiquidityScore(basket) {
  // Simplified liquidity assessment
  const liquidityMap = {
    BTC: 0.9,
    WBTC: 0.85,
    ETH: 0.9,
    WETH: 0.85,
    DAI: 0.8,
    USDC: 0.85,
    USDT: 0.8,
    LINK: 0.7,
    UNI: 0.6,
    AAVE: 0.6,
  };

  let weightedLiquidity = 0;
  let totalWeight = 0;

  for (const [asset, weight] of Object.entries(basket)) {
    const liquidity = liquidityMap[asset.toUpperCase()] || 0.4; // Default lower liquidity
    weightedLiquidity += weight * liquidity;
    totalWeight += weight;
  }

  return totalWeight > 0 ? weightedLiquidity / totalWeight : 0.4;
}

function calculateCorrelationRisk(basket) {
  // Simplified correlation assessment
  const cryptoAssets = ['BTC', 'WBTC', 'ETH', 'WETH', 'LINK', 'UNI', 'AAVE'];
  const stableAssets = ['DAI', 'USDC', 'USDT'];

  let cryptoWeight = 0;
  let stableWeight = 0;

  for (const [asset, weight] of Object.entries(basket)) {
    if (cryptoAssets.includes(asset.toUpperCase())) {
      cryptoWeight += weight;
    } else if (stableAssets.includes(asset.toUpperCase())) {
      stableWeight += weight;
    }
  }

  // High correlation risk if heavily concentrated in crypto or stables
  const maxConcentration = Math.max(cryptoWeight, stableWeight);
  return maxConcentration;
}

function assessMarketConditions(prices) {
  // Simplified market condition assessment based on ETH/BTC prices
  const ethPrice = prices.ETH || prices.WETH || 2000;
  const btcPrice = prices.BTC || prices.WBTC || 45000;

  // Simple heuristic: if prices are "normal", market is stable
  const ethNormal = ethPrice > 1500 && ethPrice < 4000;
  const btcNormal = btcPrice > 30000 && btcPrice < 70000;

  if (ethNormal && btcNormal) return 0.3; // Low risk
  if (ethPrice < 1000 || btcPrice < 20000) return 0.8; // High risk
  return 0.5; // Medium risk
}

function calculateConcentrationRisk(basket) {
  const weights = Object.values(basket);
  const maxWeight = Math.max(...weights);

  // High concentration risk if any single asset > 60%
  if (maxWeight > 0.6) return 0.9;
  if (maxWeight > 0.4) return 0.6;
  if (maxWeight > 0.3) return 0.4;
  return 0.2;
}

function calculateConfidence(riskFactors, portfolioMetrics) {
  // Base confidence
  let confidence = 70;

  // Increase confidence for better diversification
  confidence += riskFactors.diversification * 20;

  // Decrease confidence for high volatility
  confidence -= riskFactors.volatility * 15;

  // Increase confidence for good liquidity
  confidence += riskFactors.liquidity * 10;

  // Decrease confidence for high correlation
  confidence -= riskFactors.correlation * 10;

  // Adjust for portfolio size
  if (portfolioMetrics.assetCount >= 4) confidence += 5;
  if (portfolioMetrics.assetCount <= 2) confidence -= 10;

  return Math.max(50, Math.min(95, Math.round(confidence)));
}

// Main execution
async function main() {
  console.log('=== AI Risk Assessment Starting ===');
  console.log('Basket:', basketData);
  console.log('Collateral Value:', collateralValue);
  console.log('Current Prices:', currentPrices);

  // Try Bedrock first with proper authentication
  const bedrockResult = await callAmazonBedrock(
    basket,
    currentPrices,
    collateralValue
  );

  if (bedrockResult && bedrockResult.source === 'BEDROCK_AI') {
    console.log('Using Bedrock AI result');
    return `RATIO:${bedrockResult.ratio} CONFIDENCE:${bedrockResult.confidence} SOURCE:${bedrockResult.source}`;
  }

  // Fall back to sophisticated algorithmic assessment
  console.log('Using algorithmic AI fallback');
  const result = performAdvancedRiskAssessment(
    basket,
    collateralValue,
    currentPrices
  );

  return `RATIO:${result.ratio} CONFIDENCE:${result.confidence} SOURCE:${result.source}`;
}

// Execute and return result
const result = await main();
console.log('Final result:', result);
return Functions.encodeString(result);
