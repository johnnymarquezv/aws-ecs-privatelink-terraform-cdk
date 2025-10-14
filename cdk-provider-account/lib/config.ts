import * as cdk from 'aws-cdk-lib';

// Environment detection and configuration
export interface AccountConfig {
  accountId: string;
  region: string;
  profile?: string;
}

export interface ServiceConfig {
  name: string;
  port: number;
  image: string;
  description: string;
}

export interface EnvironmentConfig {
  memoryLimitMiB: number;
  cpu: number;
  desiredCount: number;
  minCapacity: number;
  maxCapacity: number;
  vpcCidr: string;
  publicSubnetCidrs: string[];
  privateSubnetCidrs: string[];
  logRetentionDays: number;
}

// Service configurations
export const SERVICES: Record<string, ServiceConfig> = {
  'api-service': {
    name: 'api-service',
    port: 8080,
    image: 'microservice',
    description: 'API Service Provider'
  },
  'user-service': {
    name: 'user-service',
    port: 3000,
    image: 'microservice',
    description: 'User Service Provider'
  }
};

// Environment configurations
export const ENVIRONMENTS: Record<string, EnvironmentConfig> = {
  dev: {
    memoryLimitMiB: 512,
    cpu: 256,
    desiredCount: 1,
    minCapacity: 1,
    maxCapacity: 3,
    vpcCidr: '10.1.0.0/16',
    publicSubnetCidrs: ['10.1.1.0/24', '10.1.2.0/24'],
    privateSubnetCidrs: ['10.1.3.0/24', '10.1.4.0/24'],
    logRetentionDays: 7
  },
  staging: {
    memoryLimitMiB: 1024,
    cpu: 512,
    desiredCount: 2,
    minCapacity: 2,
    maxCapacity: 5,
    vpcCidr: '10.2.0.0/16',
    publicSubnetCidrs: ['10.2.1.0/24', '10.2.2.0/24'],
    privateSubnetCidrs: ['10.2.3.0/24', '10.2.4.0/24'],
    logRetentionDays: 14
  },
  prod: {
    memoryLimitMiB: 2048,
    cpu: 1024,
    desiredCount: 3,
    minCapacity: 3,
    maxCapacity: 10,
    vpcCidr: '10.3.0.0/16',
    publicSubnetCidrs: ['10.3.1.0/24', '10.3.2.0/24'],
    privateSubnetCidrs: ['10.3.3.0/24', '10.3.4.0/24'],
    logRetentionDays: 30
  }
};

// Account configurations - can be overridden by context or environment variables
export const ACCOUNTS: Record<string, AccountConfig> = {
  provider: {
    accountId: process.env.AWS_ACCOUNT_ID || '222222222222',
    region: process.env.AWS_REGION || 'us-east-1',
    profile: process.env.AWS_PROFILE
  },
  consumer: {
    accountId: process.env.CONSUMER_ACCOUNT_ID || '333333333333',
    region: process.env.AWS_REGION || 'us-east-1',
    profile: process.env.CONSUMER_AWS_PROFILE
  },
  networking: {
    accountId: process.env.NETWORKING_ACCOUNT_ID || '111111111111',
    region: process.env.AWS_REGION || 'us-east-1',
    profile: process.env.NETWORKING_AWS_PROFILE
  },
  shared: {
    accountId: process.env.SHARED_ACCOUNT_ID || '111111111111',
    region: process.env.AWS_REGION || 'us-east-1',
    profile: process.env.SHARED_AWS_PROFILE
  }
};

// Helper function to get account configuration with context override
export function getAccountConfig(app: cdk.App, accountType: keyof typeof ACCOUNTS): AccountConfig {
  const defaultConfig = ACCOUNTS[accountType];
  
  // Check for context overrides
  const contextAccountId = app.node.tryGetContext(`${accountType}AccountId`);
  const contextRegion = app.node.tryGetContext(`${accountType}Region`);
  const contextProfile = app.node.tryGetContext(`${accountType}Profile`);
  
  return {
    accountId: contextAccountId || defaultConfig.accountId,
    region: contextRegion || defaultConfig.region,
    profile: contextProfile || defaultConfig.profile
  };
}

// Helper function to get service configuration
export function getServiceConfig(serviceType: string): ServiceConfig {
  const service = SERVICES[serviceType];
  if (!service) {
    throw new Error(`Unknown service type: ${serviceType}`);
  }
  return service;
}

// Helper function to get environment configuration
export function getEnvironmentConfig(environment: string): EnvironmentConfig {
  const env = ENVIRONMENTS[environment];
  if (!env) {
    throw new Error(`Unknown environment: ${environment}`);
  }
  return env;
}

// Helper function to create CDK environment object
export function createCdkEnvironment(app: cdk.App, accountType: keyof typeof ACCOUNTS): cdk.Environment | undefined {
  // Always use default AWS credential chain (most Terraform-like approach)
  // CDK will automatically detect account/region from current credentials
  return undefined;
}
