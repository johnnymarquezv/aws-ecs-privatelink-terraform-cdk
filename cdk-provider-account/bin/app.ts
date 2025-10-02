#!/usr/bin/env node
import 'source-map-support/register';
import * as cdk from 'aws-cdk-lib';
import { MicroservicesStack } from '../lib/microservices-stack';

const app = new cdk.App();

// Get context values from command line or environment
const vpcId = app.node.tryGetContext('vpcId') || process.env.VPC_ID;
const publicSubnetIds = JSON.parse(
  app.node.tryGetContext('publicSubnetIds') || process.env.PUBLIC_SUBNETS || '[]'
);
const privateSubnetIds = JSON.parse(
  app.node.tryGetContext('privateSubnetIds') || process.env.PRIVATE_SUBNETS || '[]'
);

// Multi-account configuration
const environment = app.node.tryGetContext('environment') || process.env.ENVIRONMENT || 'dev';
const accountId = app.node.tryGetContext('accountId') || process.env.CDK_DEFAULT_ACCOUNT;
const allowedAccounts = app.node.tryGetContext('allowedAccounts') || process.env.ALLOWED_ACCOUNTS || '[]';
const crossAccountExternalId = app.node.tryGetContext('crossAccountExternalId') || process.env.CROSS_ACCOUNT_EXTERNAL_ID;

// Terraform-managed resources
const baseDefaultSecurityGroupId = app.node.tryGetContext('baseDefaultSecurityGroupId') || process.env.BASE_DEFAULT_SECURITY_GROUP_ID;
const basePrivateSecurityGroupId = app.node.tryGetContext('basePrivateSecurityGroupId') || process.env.BASE_PRIVATE_SECURITY_GROUP_ID;
const ecsTaskExecutionRoleArn = app.node.tryGetContext('ecsTaskExecutionRoleArn') || process.env.ECS_TASK_EXECUTION_ROLE_ARN;
const ecsTaskRoleArn = app.node.tryGetContext('ecsTaskRoleArn') || process.env.ECS_TASK_ROLE_ARN;
const ecsApplicationLogGroupName = app.node.tryGetContext('ecsApplicationLogGroupName') || process.env.ECS_APPLICATION_LOG_GROUP_NAME;

// Microservice configuration
const microserviceName = app.node.tryGetContext('microserviceName') || 'microservice';
const microservicePort = parseInt(app.node.tryGetContext('microservicePort') || '80'); // nginx default port
const microserviceImage = app.node.tryGetContext('microserviceImage') || 'nginx:alpine'; // Public image suitable for testing

// Provider-specific configuration
const serviceDescription = app.node.tryGetContext('serviceDescription') || `Microservice ${microserviceName} provider`;

// Environment-specific configuration
const environmentConfig = {
  dev: {
    minCapacity: 1,
    maxCapacity: 3,
    instanceType: 't3.micro',
    allowedAccounts: ['123456789012', '234567890123']
  },
  staging: {
    minCapacity: 2,
    maxCapacity: 5,
    instanceType: 't3.small',
    allowedAccounts: ['123456789012', '234567890123', '345678901234']
  },
  prod: {
    minCapacity: 3,
    maxCapacity: 10,
    instanceType: 't3.medium',
    allowedAccounts: ['123456789012', '234567890123', '345678901234', '456789012345']
  }
};

const config = environmentConfig[environment] || environmentConfig.dev;

// Validate required context
if (!vpcId) {
  throw new Error('vpcId context is required. Use -c vpcId=<vpc-id> or set VPC_ID environment variable.');
}

if (publicSubnetIds.length === 0) {
  throw new Error('publicSubnetIds context is required. Use -c publicSubnetIds=<json-array> or set PUBLIC_SUBNETS environment variable.');
}

if (privateSubnetIds.length === 0) {
  throw new Error('privateSubnetIds context is required. Use -c privateSubnetIds=<json-array> or set PRIVATE_SUBNETS environment variable.');
}

// Validate multi-account configuration
if (!accountId) {
  throw new Error('accountId context is required. Use -c accountId=<account-id> or set CDK_DEFAULT_ACCOUNT environment variable.');
}

if (allowedAccounts.length === 0) {
  console.warn('Warning: No allowed accounts specified. VPC Endpoint Service will allow all accounts.');
}

// Validate Terraform-managed resources
if (!baseDefaultSecurityGroupId) {
  throw new Error('baseDefaultSecurityGroupId context is required. Use -c baseDefaultSecurityGroupId=<sg-id> or set BASE_DEFAULT_SECURITY_GROUP_ID environment variable.');
}

if (!basePrivateSecurityGroupId) {
  throw new Error('basePrivateSecurityGroupId context is required. Use -c basePrivateSecurityGroupId=<sg-id> or set BASE_PRIVATE_SECURITY_GROUP_ID environment variable.');
}

if (!ecsTaskExecutionRoleArn) {
  throw new Error('ecsTaskExecutionRoleArn context is required. Use -c ecsTaskExecutionRoleArn=<role-arn> or set ECS_TASK_EXECUTION_ROLE_ARN environment variable.');
}

if (!ecsTaskRoleArn) {
  throw new Error('ecsTaskRoleArn context is required. Use -c ecsTaskRoleArn=<role-arn> or set ECS_TASK_ROLE_ARN environment variable.');
}

if (!ecsApplicationLogGroupName) {
  throw new Error('ecsApplicationLogGroupName context is required. Use -c ecsApplicationLogGroupName=<log-group-name> or set ECS_APPLICATION_LOG_GROUP_NAME environment variable.');
}

// Create the provider microservices stack
new MicroservicesStack(app, `${microserviceName}-provider-stack`, {
  env: {
    account: accountId,
    region: process.env.CDK_DEFAULT_REGION,
  },
  vpcId,
  publicSubnetIds,
  privateSubnetIds,
  microserviceName,
  microservicePort,
  microserviceImage,
  baseDefaultSecurityGroupId,
  basePrivateSecurityGroupId,
  ecsTaskExecutionRoleArn,
  ecsTaskRoleArn,
  ecsApplicationLogGroupName,
  allowedAccounts: allowedAccounts.length > 0 ? allowedAccounts : config.allowedAccounts,
  environment,
  serviceDescription,
  description: `Provider stack for ${microserviceName} with ECS, NLB, and VPC Endpoint Services`,
  tags: {
    Project: 'Multi-Account-Microservices',
    Service: microserviceName,
    Environment: environment,
    AccountId: accountId,
    AccountType: 'Provider',
    ManagedBy: 'CDK',
  },
});

// Add CDK metadata
cdk.Tags.of(app).add('Project', 'Multi-Account-Microservices');
cdk.Tags.of(app).add('ManagedBy', 'AWS-CDK');


