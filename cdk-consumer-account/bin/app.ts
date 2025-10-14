import 'source-map-support/register';
import * as cdk from 'aws-cdk-lib';
import { ConsumerStack } from '../lib/consumer-stack';
import { SsmParameterStore } from '../lib/ssm-parameter-store';

// Set AWS profile for this CDK app
process.env.AWS_PROFILE = 'consumer-account'; // Replace with your actual profile name

// Configuration that can be overridden by environment variables or AWS profiles
const CONFIG = {
  // Account configuration - can be overridden by AWS_PROFILE or AWS_ACCOUNT_ID
  CONSUMER_ACCOUNT_ID: process.env.AWS_ACCOUNT_ID || '333333333333',
  REGION: process.env.AWS_REGION || 'us-east-1',
  
  // Service configuration
  API_CONSUMER: {
    name: 'api-consumer',
    port: 80,
    image: 'nginx:alpine',
    description: 'API Consumer Service'
  },
  USER_CONSUMER: {
    name: 'user-consumer',
    port: 80,
    image: 'nginx:alpine',
    description: 'User Consumer Service'
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

// Define all possible service and environment combinations
const services = ['api-consumer', 'user-consumer'] as const;
const environments = ['dev', 'staging', 'prod'] as const;

// Create all possible stacks
for (const serviceType of services) {
  for (const environment of environments) {
    // Get service configuration based on service type
    const serviceConfig = serviceType === 'api-consumer' ? CONFIG.API_CONSUMER : CONFIG.USER_CONSUMER;
    
    // Create the consumer stack
    new ConsumerStack(app, `${serviceConfig.name}-${environment}-consumer-stack`, {
      // Use default AWS credential chain (most Terraform-like approach)
      // CDK will automatically detect account/region from current credentials
      // Fallback to hardcoded values for synthesis when credentials are not available
      env: {
        account: process.env.AWS_ACCOUNT_ID || CONFIG.CONSUMER_ACCOUNT_ID,
        region: process.env.AWS_REGION || CONFIG.REGION,
      },
      environment,
      serviceType,
      description: `${serviceConfig.description} in ${environment} environment`,
      tags: {
        Project: 'Multi-Account-Microservices',
        Service: serviceConfig.name,
        Environment: environment,
        AccountType: 'Consumer',
        ManagedBy: 'CDK',
      },
    });
  }
}

// Add CDK metadata
cdk.Tags.of(app).add('Project', 'Multi-Account-Microservices');
cdk.Tags.of(app).add('ManagedBy', 'AWS-CDK');