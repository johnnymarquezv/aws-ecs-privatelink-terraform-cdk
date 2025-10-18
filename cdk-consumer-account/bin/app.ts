import 'source-map-support/register';
import * as cdk from 'aws-cdk-lib';
import { ConsumerStack } from '../lib/consumer-stack';
import { getAccountConfig, getServiceConfig } from '../lib/config';

// Set AWS profile for this CDK app
process.env.AWS_PROFILE = 'consumer-account'; // Replace with your actual profile name

const app = new cdk.App();

// Define environments only (single service)
const environments = ['dev', 'staging', 'prod'] as const;

// Create stacks for each environment (single service)
for (const environment of environments) {
  // Get configuration from centralized config
  const accountConfig = getAccountConfig(app, 'consumer');
  const serviceConfig = getServiceConfig('api-consumer');
  const serviceType = 'api-consumer';
  
  // Create the consumer stack
  new ConsumerStack(app, `api-consumer-${environment}-stack`, {
    // Use default AWS credential chain (most Terraform-like approach)
    // CDK will automatically detect account/region from current credentials
    // Fallback to hardcoded values for synthesis when credentials are not available
    env: {
      account: accountConfig.accountId,
      region: accountConfig.region,
    },
    environment,
    serviceType,
    description: `API Consumer in ${environment} environment`,
    tags: {
      Project: 'Multi-Account-Microservices',
      Service: serviceConfig.name,
      Environment: environment,
      AccountType: 'Consumer',
      ManagedBy: 'CDK',
    },
  });
}

// Add CDK metadata
cdk.Tags.of(app).add('Project', 'Multi-Account-Microservices');
cdk.Tags.of(app).add('ManagedBy', 'AWS-CDK');