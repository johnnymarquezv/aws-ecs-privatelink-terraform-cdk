import 'source-map-support/register';
import * as cdk from 'aws-cdk-lib';
import { ProviderStack } from '../lib/provider-stack';
import { getAccountConfig, getServiceConfig } from '../lib/config';

// Set AWS profile for this CDK app
process.env.AWS_PROFILE = 'provider-account'; // Replace with your actual profile name

const app = new cdk.App();

// Define environments only (single service)
const environments = ['dev', 'staging', 'prod'] as const;

// Create stacks for each environment (single service)
for (const environment of environments) {
  // Get configuration from centralized config
  const accountConfig = getAccountConfig(app, 'provider');
  const serviceConfig = getServiceConfig('api-service');
  const serviceType = 'api-service';
  
  // Create the provider stack
  new ProviderStack(app, `api-service-${environment}-stack`, {
    // Use default AWS credential chain (most Terraform-like approach)
    // CDK will automatically detect account/region from current credentials
    // Fallback to hardcoded values for synthesis when credentials are not available
    env: {
      account: accountConfig.accountId,
      region: accountConfig.region,
    },
    environment,
    serviceType,
    description: `API Service in ${environment} environment`,
    tags: {
      Project: 'Multi-Account-Microservices',
      Service: serviceConfig.name,
      Environment: environment,
      AccountType: 'Provider',
      ManagedBy: 'CDK',
    },
  });
}

// Add CDK metadata
cdk.Tags.of(app).add('Project', 'Multi-Account-Microservices');
cdk.Tags.of(app).add('ManagedBy', 'AWS-CDK');
