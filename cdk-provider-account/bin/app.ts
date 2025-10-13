import 'source-map-support/register';
import * as cdk from 'aws-cdk-lib';
import { ProviderStack } from '../lib/provider-stack';
import { SsmParameterStore } from '../lib/ssm-parameter-store';

// Hardcoded configuration constants
const CONFIG = {
  // Account configuration
  PROVIDER_ACCOUNT_ID: '222222222222',
  REGION: 'us-east-1',
  
  // Service configuration
  API_SERVICE: {
    name: 'api-service',
    port: 8080,
    image: 'nginx:alpine',
    description: 'API Service Provider'
  },
  USER_SERVICE: {
    name: 'user-service',
    port: 3000,
    image: 'nginx:alpine',
    description: 'User Service Provider'
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
const services = ['api-service', 'user-service'] as const;
const environments = ['dev', 'staging', 'prod'] as const;

// Create all possible stacks
for (const serviceType of services) {
  for (const environment of environments) {
    // Get service configuration based on service type
    const serviceConfig = serviceType === 'api-service' ? CONFIG.API_SERVICE : CONFIG.USER_SERVICE;
    
    // Create the provider stack
    new ProviderStack(app, `${serviceConfig.name}-${environment}-provider-stack`, {
      env: {
        account: CONFIG.PROVIDER_ACCOUNT_ID,
        region: CONFIG.REGION,
      },
      environment,
      serviceType,
      description: `${serviceConfig.description} in ${environment} environment`,
      tags: {
        Project: 'Multi-Account-Microservices',
        Service: serviceConfig.name,
        Environment: environment,
        AccountId: CONFIG.PROVIDER_ACCOUNT_ID,
        AccountType: 'Provider',
        ManagedBy: 'CDK',
      },
    });
  }
}

// Add CDK metadata
cdk.Tags.of(app).add('Project', 'Multi-Account-Microservices');
cdk.Tags.of(app).add('ManagedBy', 'AWS-CDK');
