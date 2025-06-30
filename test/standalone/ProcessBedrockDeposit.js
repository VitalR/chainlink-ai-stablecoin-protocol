#!/usr/bin/env node

// Load environment variables from .env file
require('dotenv').config({ path: '../../.env' });

/**
 * Integrated Bedrock AI Processor for Real Deposits
 *
 * This script processes actual deposit data from script/bedrock/ExecuteDepositWithBedrock.s.sol
 * and generates AI responses for the script/execute/ProcessManualRequest.s.sol script.
 *
 * Part of the complete Bedrock AI workflow - see docs/bedrock-ai-workflow-guide.md
 *
 * Usage:
 * node ProcessBedrockDeposit.js --requestId 123 --tokens "DAI,WETH" --amounts "1000,0.5" --totalValue 2500
 *
 * Or use environment variables:
 * export REQUEST_ID=123
 * export TOKENS="DAI,WETH"
 * export AMOUNTS="1000,0.5"
 * export TOTAL_VALUE=2500
 * node ProcessBedrockDeposit.js
 *
 * Complete workflow:
 * 1. forge script script/bedrock/ExecuteDepositWithBedrock.s.sol (create deposit)
 * 2. forge script script/bedrock/GetDepositData.s.sol (get this command)
 * 3. node ProcessBedrockDeposit.js (this script - AI analysis)
 * 4. forge script script/execute/ProcessManualRequest.s.sol (process response)
 */

const AWS = require('aws-sdk');

// Configuration
const CONFIG = {
  // AWS Configuration (loaded from .env)
  AWS_REGION: process.env.AWS_REGION || 'us-east-1',
  AWS_ACCESS_KEY_ID: process.env.AWS_ACCESS_KEY_ID,
  AWS_SECRET_ACCESS_KEY: process.env.AWS_SECRET_ACCESS_KEY,

  // Bedrock Configuration
  MODEL_ID: 'anthropic.claude-3-sonnet-20240229-v1:0',
  MAX_TOKENS: 1000,
  TEMPERATURE: 0.3,

  // Input data (from command line or environment)
  REQUEST_ID: process.env.REQUEST_ID,
  TOKENS: process.env.TOKENS,
  AMOUNTS: process.env.AMOUNTS,
  TOTAL_VALUE: process.env.TOTAL_VALUE,
};

// Configure AWS SDK
AWS.config.update({
  accessKeyId: CONFIG.AWS_ACCESS_KEY_ID,
  secretAccessKey: CONFIG.AWS_SECRET_ACCESS_KEY,
  region: CONFIG.AWS_REGION,
});

// Enhanced AI Risk Assessment for Real Deposits
class BedrockDepositProcessor {
  constructor() {
    this.bedrock = new AWS.BedrockRuntime();
  }

  parseInputData(args) {
    // Parse command line arguments
    const requestId = args.requestId || CONFIG.REQUEST_ID;
    const tokensStr = args.tokens || CONFIG.TOKENS;
    const amountsStr = args.amounts || CONFIG.AMOUNTS;
    const totalValue = parseFloat(args.totalValue || CONFIG.TOTAL_VALUE);

    if (!requestId || !tokensStr || !amountsStr || !totalValue) {
      throw new Error(
        'Missing required parameters: requestId, tokens, amounts, totalValue'
      );
    }

    const tokens = tokensStr.split(',').map((t) => t.trim());
    const amounts = amountsStr.split(',').map((a) => parseFloat(a.trim()));

    if (tokens.length !== amounts.length) {
      throw new Error('Tokens and amounts arrays must have the same length');
    }

    // Calculate estimated USD values for each token (using approximate prices)
    const tokenPrices = {
      DAI: 1.0,
      USDC: 1.0,
      WETH: 2500,
      WBTC: 52000,
      LINK: 12,
    };

    const values = tokens.map((token, i) => {
      const price = tokenPrices[token] || 1000; // Default price for unknown tokens
      return amounts[i] * price;
    });

    return {
      requestId: parseInt(requestId),
      portfolio: {
        tokens,
        amounts,
        values,
        totalValue,
      },
    };
  }

  createPrompt(portfolio) {
    const { tokens, amounts, values, totalValue } = portfolio;

    return `You are an expert DeFi risk analyst for an AI-powered stablecoin protocol. Analyze this REAL USER DEPOSIT and determine the optimal collateral ratio.

REAL DEPOSIT ANALYSIS:
${tokens
  .map(
    (token, i) =>
      `- ${token}: ${amounts[i]} tokens ($${values[i].toFixed(2)} USD, ${(
        (values[i] / totalValue) *
        100
      ).toFixed(1)}%)`
  )
  .join('\n')}

Total Portfolio Value: $${totalValue.toFixed(2)} USD

COMPREHENSIVE RISK ASSESSMENT:

1. DIVERSIFICATION ANALYSIS
   - Portfolio concentration risk (HHI calculation)
   - Single-asset exposure assessment (>50% = high risk)
   - Asset correlation during market stress events
   - Diversification benefits vs. complexity costs

2. VOLATILITY & LIQUIDITY EVALUATION  
   - Historical volatility patterns for each asset class
   - Market depth and emergency liquidation scenarios
   - Slippage risk in stressed market conditions
   - Time-to-liquidate estimates

3. MARKET CONDITIONS & RISK FACTORS
   - Current DeFi market sentiment and regulatory landscape
   - Asset-specific risks (depeg, oracle manipulation, smart contract)
   - Yield farming and staking risks
   - Cross-chain bridge risks (if applicable)

4. CAPITAL EFFICIENCY OPTIMIZATION
   - Competitive analysis vs. other lending protocols
   - User retention through optimal ratios
   - Risk-adjusted return maximization

COLLATERAL RATIO FRAMEWORK:
- Ultra-Aggressive (125-135%): Pure stablecoins, excellent liquidity, minimal risk
- Aggressive (135-145%): Diversified blue-chip assets, good liquidity
- Balanced (145-160%): Mixed portfolio, moderate diversification
- Conservative (160-175%): Concentrated positions or volatile assets  
- Ultra-Conservative (175-200%): Single volatile asset or extreme market conditions

CRITICAL: Balance capital efficiency with protocol safety. Users choose protocols based on competitive ratios while maintaining adequate safety margins.

Provide detailed analysis and conclude with EXACTLY this format:
RATIO:XXX CONFIDENCE:YY SOURCE:BEDROCK_AI

Where XXX = recommended ratio (125-200) and YY = confidence level (30-95).`;
  }

  async callBedrock(prompt) {
    if (!CONFIG.AWS_ACCESS_KEY_ID || !CONFIG.AWS_SECRET_ACCESS_KEY) {
      throw new Error(
        'AWS credentials not available. Please set AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY'
      );
    }

    const params = {
      modelId: CONFIG.MODEL_ID,
      contentType: 'application/json',
      accept: 'application/json',
      body: JSON.stringify({
        anthropic_version: 'bedrock-2023-05-31',
        max_tokens: CONFIG.MAX_TOKENS,
        temperature: CONFIG.TEMPERATURE,
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

  parseAIResponse(response) {
    try {
      const content = response.content?.[0]?.text || '';

      // Enhanced regex patterns for robust parsing
      const ratioPatterns = [
        /RATIO:?\s*(\d+)/i,
        /COLLATERAL[_\s]RATIO:?\s*(\d+)/i,
        /RECOMMENDED[_\s]RATIO:?\s*(\d+)/i,
        /(\d+)%?\s*collateral\s*ratio/i,
      ];

      const confidencePatterns = [
        /CONFIDENCE:?\s*(\d+)/i,
        /CONFIDENCE[_\s]LEVEL:?\s*(\d+)/i,
        /(\d+)%?\s*confidence/i,
      ];

      // Extract ratio
      let ratio = 150; // Conservative default
      for (const pattern of ratioPatterns) {
        const match = content.match(pattern);
        if (match) {
          ratio = parseInt(match[1]);
          break;
        }
      }

      // Extract confidence
      let confidence = 70; // Moderate default
      for (const pattern of confidencePatterns) {
        const match = content.match(pattern);
        if (match) {
          confidence = parseInt(match[1]);
          break;
        }
      }

      // Validate ranges
      ratio = Math.max(125, Math.min(200, ratio));
      confidence = Math.max(30, Math.min(95, confidence));

      return {
        ratio,
        confidence,
        source: 'BEDROCK_AI',
        rawResponse: content,
        formattedResponse: `RATIO:${ratio} CONFIDENCE:${confidence} SOURCE:BEDROCK_AI`,
      };
    } catch (error) {
      console.error('Error parsing AI response:', error);
      return {
        ratio: 150,
        confidence: 50,
        source: 'BEDROCK_AI',
        rawResponse: 'Error parsing response',
        formattedResponse: 'RATIO:150 CONFIDENCE:50 SOURCE:BEDROCK_AI',
      };
    }
  }

  async processDeposit(inputData) {
    const { requestId, portfolio } = inputData;

    console.log('🧠 BEDROCK AI PROCESSING');
    console.log('========================');
    console.log(`Request ID: ${requestId}`);
    console.log(`Portfolio Value: $${portfolio.totalValue.toFixed(2)}`);
    console.log('');

    // Show portfolio composition
    console.log('📊 PORTFOLIO COMPOSITION:');
    portfolio.tokens.forEach((token, i) => {
      const percentage = (
        (portfolio.values[i] / portfolio.totalValue) *
        100
      ).toFixed(1);
      console.log(
        `   ${token}: ${portfolio.amounts[i]} tokens ($${portfolio.values[
          i
        ].toFixed(2)}, ${percentage}%)`
      );
    });
    console.log('');

    try {
      // Create AI prompt
      const prompt = this.createPrompt(portfolio);

      // Call Bedrock AI
      console.log('🤖 Calling Amazon Bedrock (Claude 3 Sonnet)...');
      const response = await this.callBedrock(prompt);

      // Parse response
      const result = this.parseAIResponse(response);

      console.log('✅ AI ANALYSIS COMPLETE');
      console.log('========================');
      console.log(`Recommended Ratio: ${result.ratio}%`);
      console.log(`Confidence Level: ${result.confidence}%`);
      console.log(
        `Capital Efficiency: ${((100 / result.ratio) * 100).toFixed(1)}%`
      );
      console.log(
        `Mintable AIUSD: $${(
          (portfolio.totalValue * 100) /
          result.ratio
        ).toFixed(2)}`
      );
      console.log('');

      console.log('📝 AI REASONING:');
      console.log(result.rawResponse.substring(0, 400) + '...');
      console.log('');

      console.log('🎯 FORMATTED RESPONSE FOR PROCESSING:');
      console.log(`"${result.formattedResponse}"`);
      console.log('');

      console.log('📋 NEXT COMMAND:');
      console.log(
        'source .env && forge script script/execute/ProcessManualRequest.s.sol \\'
      );
      console.log(`--sig "processWithAIResponse(uint256,string)" \\`);
      console.log(`${requestId} "${result.formattedResponse}" \\`);
      console.log(
        '--rpc-url $SEPOLIA_RPC_URL --broadcast --private-key $DEPLOYER_PRIVATE_KEY -vv'
      );

      return result;
    } catch (error) {
      console.error('❌ AI PROCESSING ERROR:', error.message);

      // Fallback to algorithmic assessment
      console.log('🔄 Falling back to algorithmic assessment...');
      const fallbackResult = this.algorithmicFallback(portfolio);

      console.log('⚠️  FALLBACK RESULT:');
      console.log(`Ratio: ${fallbackResult.ratio}% (Conservative)`);
      console.log(`Response: "${fallbackResult.formattedResponse}"`);

      return fallbackResult;
    }
  }

  algorithmicFallback(portfolio) {
    // Simple algorithmic fallback
    const diversification = this.calculateDiversification(portfolio);
    const volatilityScore = this.calculateVolatility(portfolio);

    // Conservative ratio based on risk factors
    let ratio = 140; // Base ratio

    // Adjust for diversification (lower = more risk)
    if (diversification < 0.3) ratio += 20; // Poor diversification
    else if (diversification < 0.5) ratio += 10; // Moderate diversification

    // Adjust for volatility
    if (volatilityScore > 0.7) ratio += 15; // High volatility
    else if (volatilityScore > 0.5) ratio += 10; // Moderate volatility

    ratio = Math.min(180, ratio); // Cap at 180%

    return {
      ratio,
      confidence: 60,
      source: 'ALGORITHMIC_FALLBACK',
      rawResponse:
        'Fallback algorithmic assessment used due to AI processing error',
      formattedResponse: `RATIO:${ratio} CONFIDENCE:60 SOURCE:ALGORITHMIC_FALLBACK`,
    };
  }

  calculateDiversification(portfolio) {
    // Calculate Herfindahl-Hirschman Index (HHI)
    const weights = portfolio.values.map((v) => v / portfolio.totalValue);
    const hhi = weights.reduce((sum, w) => sum + w * w, 0);
    return 1 - hhi; // Higher = more diversified
  }

  calculateVolatility(portfolio) {
    // Simple volatility scoring based on asset types
    const volatilityScores = {
      DAI: 0.1,
      USDC: 0.1, // Stablecoins
      WETH: 0.6,
      WBTC: 0.7, // Major crypto
      LINK: 0.8, // Altcoins
    };

    const weights = portfolio.values.map((v) => v / portfolio.totalValue);
    return portfolio.tokens.reduce((sum, token, i) => {
      const score = volatilityScores[token] || 0.8; // Default high volatility
      return sum + weights[i] * score;
    }, 0);
  }
}

// Command line argument parsing
function parseArgs() {
  const args = {};
  const argv = process.argv.slice(2);

  for (let i = 0; i < argv.length; i += 2) {
    const key = argv[i].replace('--', '');
    const value = argv[i + 1];
    args[key] = value;
  }

  return args;
}

// Main execution
async function main() {
  try {
    console.log('🚀 BEDROCK DEPOSIT PROCESSOR');
    console.log('============================');
    console.log('Processing real deposit data with AWS Bedrock AI');
    console.log('');

    const args = parseArgs();
    const processor = new BedrockDepositProcessor();

    // Parse input data
    const inputData = processor.parseInputData(args);

    // Process with Bedrock AI
    await processor.processDeposit(inputData);
  } catch (error) {
    console.error('❌ PROCESSING FAILED:', error.message);
    console.log('');
    console.log('💡 USAGE:');
    console.log(
      'node ProcessBedrockDeposit.js --requestId 123 --tokens "DAI,WETH" --amounts "1000,0.5" --totalValue 2500'
    );
    console.log('');
    console.log('Or set environment variables:');
    console.log('export REQUEST_ID=123');
    console.log('export TOKENS="DAI,WETH"');
    console.log('export AMOUNTS="1000,0.5"');
    console.log('export TOTAL_VALUE=2500');
    console.log('node ProcessBedrockDeposit.js');
    process.exit(1);
  }
}

// Run if called directly
if (require.main === module) {
  main().catch(console.error);
}

module.exports = { BedrockDepositProcessor };
