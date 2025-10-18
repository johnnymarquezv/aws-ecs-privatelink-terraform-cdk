import 'source-map-support/register';
import * as cdk from 'aws-cdk-lib';
import { ProviderStack } from '../lib/provider-stack';
import { SsmParameterStore } from '../lib/ssm-parameter-store';

// Set AWS profile for this CDK app
process.env.AWS_PROFILE = 'provider-account'; // Replace with your actual profile name

// Configuration that can be overridden by environment variables or AWS profiles
const CONFIG = {
  // Account configuration - can be overridden by AWS_PROFILE or AWS_ACCOUNT_ID
  PROVIDER_ACCOUNT_ID: process.env.AWS_ACCOUNT_ID || '222222222222',
  REGION: process.env.AWS_REGION || 'us-east-1',
  
  // Service configuration
  API_SERVICE: {
    name: 'api-service',
    port: 8080,
    image: 'microservice', // Will be replaced with ECR URL
    description: 'API Service Provider'
  },
  
  // Environment-specific configuration
  ENVIRONMENTS: {
    dev: {
      memoryLimitMiB: 512,
      cpu: 256,
      desiredCount: 1,
      minCapacity: 1,
      maxCapacity: 3
    },
    staging: {
      memoryLimitMiB: 1024,
      cpu: 512,
      desiredCount: 2,
      minCapacity: 2,
      maxCapacity: 5
    },
    prod: {
      memoryLimitMiB: 2048,
      cpu: 1024,
      desiredCount: 3,
      minCapacity: 3,
      maxCapacity: 10
    }
  }
} as const;

const app = new cdk.App();

// Define environments only (single service)
const environments = ['dev', 'staging', 'prod'] as const;

// Create stacks for each environment (single service)
for (const environment of environments) {
  // Use API service as the single service
  const serviceConfig = CONFIG.API_SERVICE;
  const serviceType = 'api-service';
  
  // Create the provider stack
  new ProviderStack(app, `api-service-${environment}-stack`, {
    // Use default AWS credential chain (most Terraform-like approach)
    // CDK will automatically detect account/region from current credentials
    // Fallback to hardcoded values for synthesis when credentials are not available
    env: {
      account: process.env.AWS_ACCOUNT_ID || CONFIG.PROVIDER_ACCOUNT_ID,
      region: process.env.AWS_REGION || CONFIG.REGION,
    },
    environment,
    serviceType,
    description: `API Service in ${environment} environment`,
    tags: {
      Project: 'Multi-Account-Microservices',
      Service: 'api-service',
      Environment: environment,
      AccountType: 'Provider',
      ManagedBy: 'CDK',
    },
  });
}

// Add CDK metadata
cdk.Tags.of(app).add('Project', 'Multi-Account-Microservices');
cdk.Tags.of(app).add('ManagedBy', 'AWS-CDK');
