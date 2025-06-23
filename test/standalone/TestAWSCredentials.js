#!/usr/bin/env node

// Load environment variables from .env file
require('dotenv').config({ path: '../../.env' });

console.log('🔍 Testing AWS Credentials and Bedrock Access');
console.log('==============================================\n');

// Check credentials
console.log('📋 Credential Check:');
console.log(
  `   AWS_ACCESS_KEY_ID: ${
    process.env.AWS_ACCESS_KEY_ID
      ? process.env.AWS_ACCESS_KEY_ID.substring(0, 8) + '...'
      : 'NOT SET'
  }`
);
console.log(
  `   AWS_SECRET_ACCESS_KEY: ${
    process.env.AWS_SECRET_ACCESS_KEY
      ? process.env.AWS_SECRET_ACCESS_KEY.substring(0, 8) + '...'
      : 'NOT SET'
  }`
);
console.log(
  `   AWS_REGION: ${process.env.AWS_REGION || 'us-east-1 (default)'}\n`
);

// Test using AWS SDK if available
try {
  // Try to use AWS SDK if installed
  const AWS = require('aws-sdk');

  console.log('✅ AWS SDK found - testing with official SDK\n');

  // Configure AWS
  AWS.config.update({
    accessKeyId: process.env.AWS_ACCESS_KEY_ID,
    secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY,
    region: process.env.AWS_REGION || 'us-east-1',
  });

  const bedrock = new AWS.BedrockRuntime();

  // Simple test payload
  const params = {
    modelId: 'anthropic.claude-3-sonnet-20240229-v1:0',
    contentType: 'application/json',
    accept: 'application/json',
    body: JSON.stringify({
      anthropic_version: 'bedrock-2023-05-31',
      max_tokens: 100,
      temperature: 0.3,
      messages: [
        {
          role: 'user',
          content: "Say 'Hello from Bedrock!' and nothing else.",
        },
      ],
    }),
  };

  console.log('🌐 Testing Bedrock API call with AWS SDK...');

  bedrock.invokeModel(params, (err, data) => {
    if (err) {
      console.log('❌ Bedrock call failed:');
      console.log(`   Error Code: ${err.code}`);
      console.log(`   Error Message: ${err.message}\n`);

      if (err.code === 'AccessDeniedException') {
        console.log('💡 Possible solutions:');
        console.log('   1. Enable model access in AWS Bedrock console');
        console.log('   2. Check IAM permissions for Bedrock');
        console.log('   3. Verify you have access to Claude 3 Sonnet');
      } else if (
        err.code === 'UnauthorizedOperation' ||
        err.code === 'SignatureDoesNotMatch'
      ) {
        console.log('💡 Possible solutions:');
        console.log('   1. Verify AWS credentials are correct');
        console.log('   2. Check if credentials have expired');
        console.log('   3. Ensure region is correct');
      }
    } else {
      console.log('✅ Bedrock call successful!');
      const response = JSON.parse(data.body);
      console.log(
        '🤖 AI Response:',
        response.content?.[0]?.text || 'No content'
      );
    }
  });
} catch (error) {
  console.log('⚠️  AWS SDK not found - using manual credential test\n');

  // Manual validation
  if (!process.env.AWS_ACCESS_KEY_ID || !process.env.AWS_SECRET_ACCESS_KEY) {
    console.log('❌ AWS credentials missing');
    console.log('💡 Make sure your .env file contains:');
    console.log("   AWS_ACCESS_KEY_ID='your-access-key'");
    console.log("   AWS_SECRET_ACCESS_KEY='your-secret-key'");
    console.log("   AWS_REGION='us-east-1'  # optional");
  } else {
    console.log('✅ AWS credentials found in .env file');
    console.log('💡 To test Bedrock access, install AWS SDK:');
    console.log('   npm install aws-sdk');
    console.log('   Then run this test again');
  }
}

console.log('\n🎯 Next Steps:');
console.log('   1. If credentials work → Your standalone test should work');
console.log('   2. If credentials fail → Check AWS console and permissions');
console.log(
  '   3. If no AWS access → The algorithmic fallback is still impressive!'
);
