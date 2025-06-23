#!/usr/bin/env node

// Load environment variables from .env file
require('dotenv').config({ path: '../../.env' });

/**
 * Standalone Bedrock AI Risk Assessment Test
 *
 * This script tests the Amazon Bedrock integration directly without Chainlink Functions.
 * It uses the same AI logic and prompts as the production system.
 * cd test/standalone && node TestBedrockDirect.js
 */

const AWS = require('aws-sdk');

// Test configuration
const TEST_CONFIG = {
  // AWS Configuration (loaded from .env)
  AWS_REGION: process.env.AWS_REGION || 'us-east-1',
  AWS_ACCESS_KEY_ID: process.env.AWS_ACCESS_KEY_ID,
  AWS_SECRET_ACCESS_KEY: process.env.AWS_SECRET_ACCESS_KEY,

  // Bedrock Configuration
  MODEL_ID: 'anthropic.claude-3-sonnet-20240229-v1:0',
  MAX_TOKENS: 1000,
  TEMPERATURE: 0.3,

  // Test portfolio data
  TEST_PORTFOLIO: {
    tokens: ['DAI', 'WETH', 'WBTC'],
    amounts: [1000, 0.5, 0.02],
    values: [1000, 1208, 2072], // USD values
    totalValue: 4280,
  },
};

// Configure AWS SDK
AWS.config.update({
  accessKeyId: TEST_CONFIG.AWS_ACCESS_KEY_ID,
  secretAccessKey: TEST_CONFIG.AWS_SECRET_ACCESS_KEY,
  region: TEST_CONFIG.AWS_REGION,
});

// AI Risk Assessment Logic (same as Chainlink Functions)
class AIRiskAssessment {
  constructor() {
    this.bedrock = new AWS.BedrockRuntime();
  }

  createPrompt(portfolio) {
    return `You are an expert DeFi risk analyst. Analyze this collateral portfolio and determine the optimal collateral ratio for an AI-powered stablecoin protocol.

PORTFOLIO COMPOSITION:
${portfolio.tokens
  .map(
    (token, i) =>
      `- ${token}: ${portfolio.amounts[i]} tokens ($${
        portfolio.values[i]
      } USD, ${((portfolio.values[i] / portfolio.totalValue) * 100).toFixed(
        1
      )}%)`
  )
  .join('\n')}

Total Portfolio Value: $${portfolio.totalValue} USD

ANALYSIS FRAMEWORK:
1. DIVERSIFICATION RISK
   - Calculate concentration risk (HHI)
   - Assess single-asset exposure (>50% = high risk)
   - Evaluate asset correlation during market stress

2. VOLATILITY & LIQUIDITY
   - Historical volatility patterns for each asset
   - Market depth and emergency liquidation feasibility
   - Slippage risk assessment

3. MARKET CONDITIONS
   - Current DeFi market sentiment and regulatory environment
   - Asset-specific risks (depeg, oracle manipulation, smart contract)

COLLATERAL RATIO GUIDELINES:
- Aggressive (125-140%): Diversified, stablecoin-heavy, excellent liquidity
- Balanced (140-160%): Mixed assets, good diversification, moderate risk
- Conservative (160-180%): Concentrated or volatile assets
- Ultra-Conservative (180-200%): Single asset or extreme volatility

IMPORTANT: Prioritize capital efficiency while maintaining safety. Users need competitive ratios to choose this protocol over alternatives.

Provide concise analysis and conclude with exactly:
RATIO:XXX CONFIDENCE:YY SOURCE:BEDROCK_AI

Where XXX = recommended ratio (125-200) and YY = confidence (30-95).`;
  }

  async callBedrock(prompt) {
    // Check if we have credentials first
    if (!TEST_CONFIG.AWS_ACCESS_KEY_ID || !TEST_CONFIG.AWS_SECRET_ACCESS_KEY) {
      throw new Error('AWS credentials not available');
    }

    const params = {
      modelId: TEST_CONFIG.MODEL_ID,
      contentType: 'application/json',
      accept: 'application/json',
      body: JSON.stringify({
        anthropic_version: 'bedrock-2023-05-31',
        max_tokens: TEST_CONFIG.MAX_TOKENS,
        temperature: TEST_CONFIG.TEMPERATURE,
        messages: [
          {
            role: 'user',
            content: prompt,
          },
        ],
      }),
    };

    return new Promise((resolve, reject) => {
      this.bedrock.invokeModel(params, (err, data) => {
        if (err) {
          reject(err);
        } else {
          try {
            const response = JSON.parse(data.body);
            resolve(response);
          } catch (error) {
            reject(new Error(`JSON parse error: ${error.message}`));
          }
        }
      });
    });
  }

  parseResponse(response) {
    try {
      const content = response.content?.[0]?.text || '';
      console.log('\n=== RAW AI RESPONSE ===');
      console.log(content);
      console.log('========================\n');

      // Enhanced regex patterns to handle multiple formats
      const ratioPatterns = [
        /RATIO:?\s*(\d+)/i, // RATIO:145 or RATIO: 145
        /COLLATERAL[_\s]RATIO:?\s*(\d+)/i, // COLLATERAL_RATIO:145
        /RECOMMENDED[_\s]RATIO:?\s*(\d+)/i, // RECOMMENDED_RATIO:145
        /(\d+)%?\s*collateral\s*ratio/i, // 145% collateral ratio
        /ratio[:\s]*(\d+)/i, // ratio: 145
      ];

      const confidencePatterns = [
        /CONFIDENCE:?\s*(\d+)/i, // CONFIDENCE:75 or CONFIDENCE: 75
        /CONFIDENCE[_\s]LEVEL:?\s*(\d+)/i, // CONFIDENCE_LEVEL:75
        /(\d+)%?\s*confidence/i, // 75% confidence
        /confidence[:\s]*(\d+)/i, // confidence: 75
      ];

      const sourcePatterns = [
        /SOURCE:?\s*([A-Z_]+)/i, // SOURCE:BEDROCK_AI
        /BEDROCK[_\s]AI/i, // BEDROCK_AI anywhere
        /AI[_\s]ANALYSIS/i, // AI_ANALYSIS
      ];

      // Try to extract ratio using multiple patterns
      let ratio = 160; // Default conservative
      for (const pattern of ratioPatterns) {
        const match = content.match(pattern);
        if (match) {
          ratio = parseInt(match[1]);
          console.log(
            `✅ Ratio extracted using pattern: ${pattern.source} -> ${ratio}`
          );
          break;
        }
      }

      // Try to extract confidence using multiple patterns
      let confidence = 50; // Default moderate
      for (const pattern of confidencePatterns) {
        const match = content.match(pattern);
        if (match) {
          confidence = parseInt(match[1]);
          console.log(
            `✅ Confidence extracted using pattern: ${pattern.source} -> ${confidence}`
          );
          break;
        }
      }

      // Try to extract source using multiple patterns
      let source = 'BEDROCK_AI'; // Default
      for (const pattern of sourcePatterns) {
        const match = content.match(pattern);
        if (match) {
          source = match[1] || 'BEDROCK_AI';
          console.log(
            `✅ Source extracted using pattern: ${pattern.source} -> ${source}`
          );
          break;
        }
      }

      // Apply safety bounds
      const boundedRatio = Math.max(125, Math.min(200, ratio));
      const boundedConfidence = Math.max(30, Math.min(95, confidence));

      // Log if values were bounded
      if (boundedRatio !== ratio) {
        console.log(`⚠️  Ratio bounded: ${ratio} -> ${boundedRatio}`);
      }
      if (boundedConfidence !== confidence) {
        console.log(
          `⚠️  Confidence bounded: ${confidence} -> ${boundedConfidence}`
        );
      }

      return {
        ratio: boundedRatio,
        confidence: boundedConfidence,
        source: source,
        rawResponse: content,
        extractionSuccess: true,
      };
    } catch (error) {
      console.error('Response parsing error:', error);
      return {
        ratio: 160,
        confidence: 50,
        source: 'ERROR',
        rawResponse: 'Parse error',
        extractionSuccess: false,
      };
    }
  }

  async assessRisk(portfolio) {
    console.log('🤖 Starting AI Risk Assessment...');
    console.log('📊 Portfolio:', portfolio);

    try {
      const prompt = this.createPrompt(portfolio);
      console.log('\n=== AI PROMPT ===');
      console.log(prompt);
      console.log('==================\n');

      console.log('🌐 Calling Amazon Bedrock...');
      const response = await this.callBedrock(prompt);

      console.log('✅ Bedrock response received');
      const analysis = this.parseResponse(response);

      return analysis;
    } catch (error) {
      console.error('❌ Bedrock call failed:', error.message);

      // Fallback to algorithmic assessment
      console.log('🔄 Using algorithmic fallback...');
      return this.algorithmicFallback(portfolio);
    }
  }

  algorithmicFallback(portfolio) {
    // Simplified algorithmic assessment (same logic as Chainlink Functions)
    const diversificationScore = this.calculateDiversification(portfolio);
    const volatilityScore = this.calculateVolatility(portfolio);
    const liquidityScore = this.calculateLiquidity(portfolio);

    const avgScore =
      (diversificationScore + volatilityScore + liquidityScore) / 3;
    const ratio = Math.round(125 + 75 * (1 - avgScore));

    return {
      ratio: Math.max(125, Math.min(200, ratio)),
      confidence: 75,
      source: 'ALGORITHMIC_FALLBACK',
      rawResponse: `Algorithmic assessment based on diversification (${diversificationScore.toFixed(
        2
      )}), volatility (${volatilityScore.toFixed(
        2
      )}), and liquidity (${liquidityScore.toFixed(2)}) scores.`,
    };
  }

  calculateDiversification(portfolio) {
    // Herfindahl-Hirschman Index
    const totalValue = portfolio.totalValue;
    let hhi = 0;

    for (const value of portfolio.values) {
      const share = value / totalValue;
      hhi += share * share;
    }

    return 1 - hhi; // Higher = more diversified
  }

  calculateVolatility(portfolio) {
    // Asset-specific volatility mapping
    const volatilityMap = {
      DAI: 0.02, // Low volatility stablecoin
      USDC: 0.02, // Low volatility stablecoin
      WETH: 0.25, // Medium-high volatility
      WBTC: 0.3, // High volatility
      LINK: 0.35, // High volatility
    };

    let weightedVolatility = 0;
    const totalValue = portfolio.totalValue;

    for (let i = 0; i < portfolio.tokens.length; i++) {
      const weight = portfolio.values[i] / totalValue;
      const volatility = volatilityMap[portfolio.tokens[i]] || 0.4;
      weightedVolatility += weight * volatility;
    }

    return 1 - Math.min(weightedVolatility / 0.4, 1); // Normalize to 0-1
  }

  calculateLiquidity(portfolio) {
    // Liquidity scoring based on market depth
    const liquidityMap = {
      DAI: 0.95, // Excellent liquidity
      USDC: 0.95, // Excellent liquidity
      WETH: 0.9, // Very good liquidity
      WBTC: 0.85, // Good liquidity
      LINK: 0.75, // Moderate liquidity
    };

    let weightedLiquidity = 0;
    const totalValue = portfolio.totalValue;

    for (let i = 0; i < portfolio.tokens.length; i++) {
      const weight = portfolio.values[i] / totalValue;
      const liquidity = liquidityMap[portfolio.tokens[i]] || 0.6;
      weightedLiquidity += weight * liquidity;
    }

    return weightedLiquidity;
  }
}

// Test scenarios
const TEST_SCENARIOS = [
  {
    name: 'Conservative Portfolio (Stablecoins)',
    portfolio: {
      tokens: ['DAI', 'USDC'],
      amounts: [2000, 2000],
      values: [2000, 2000],
      totalValue: 4000,
    },
  },
  {
    name: 'Balanced Portfolio (Mixed Assets)',
    portfolio: {
      tokens: ['DAI', 'WETH', 'WBTC'],
      amounts: [1000, 0.5, 0.02],
      values: [1000, 1208, 2072],
      totalValue: 4280,
    },
  },
  {
    name: 'Aggressive Portfolio (High Volatility)',
    portfolio: {
      tokens: ['WETH', 'WBTC', 'LINK'],
      amounts: [2, 0.05, 100],
      values: [4832, 2590, 1200],
      totalValue: 8622,
    },
  },
  {
    name: 'Single Asset Portfolio (High Risk)',
    portfolio: {
      tokens: ['WBTC'],
      amounts: [0.1],
      values: [10360],
      totalValue: 10360,
    },
  },
];

// Main test function
async function runTests() {
  console.log('🚀 Starting Amazon Bedrock Direct Testing');
  console.log('==========================================\n');

  // Check AWS credentials
  if (!TEST_CONFIG.AWS_ACCESS_KEY_ID || !TEST_CONFIG.AWS_SECRET_ACCESS_KEY) {
    console.log('⚠️  AWS credentials not found in environment variables');
    console.log(
      '   Set AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY to test Bedrock'
    );
    console.log('   Falling back to algorithmic assessment only...\n');
  } else {
    console.log('✅ AWS credentials found');
    console.log(`🌍 Region: ${TEST_CONFIG.AWS_REGION}`);
    console.log(`🤖 Model: ${TEST_CONFIG.MODEL_ID}\n`);
  }

  const assessor = new AIRiskAssessment();

  for (let i = 0; i < TEST_SCENARIOS.length; i++) {
    const scenario = TEST_SCENARIOS[i];
    console.log(`📋 Test ${i + 1}: ${scenario.name}`);
    console.log('─'.repeat(50));

    try {
      const result = await assessor.assessRisk(scenario.portfolio);

      console.log('📊 ASSESSMENT RESULTS:');
      console.log(`   Collateral Ratio: ${result.ratio}%`);
      console.log(`   Confidence Level: ${result.confidence}%`);
      console.log(`   Source: ${result.source}`);
      console.log(
        `   Capital Efficiency: ${((100 / result.ratio) * 100).toFixed(1)}%`
      );

      // Calculate mintable amount
      const mintableAmount =
        (scenario.portfolio.totalValue * 100) / result.ratio;
      console.log(`   Mintable AIUSD: $${mintableAmount.toFixed(2)}`);

      console.log('\n📝 AI Analysis Summary:');
      console.log(`   ${result.rawResponse.substring(0, 200)}...\n`);
    } catch (error) {
      console.error(`❌ Test failed: ${error.message}\n`);
    }

    if (i < TEST_SCENARIOS.length - 1) {
      console.log('⏳ Waiting 2 seconds before next test...\n');
      await new Promise((resolve) => setTimeout(resolve, 2000));
    }
  }

  console.log('✅ All tests completed!');
  console.log('==========================================');
}

// Run the tests
if (require.main === module) {
  runTests().catch(console.error);
}

module.exports = { AIRiskAssessment, TEST_SCENARIOS };
