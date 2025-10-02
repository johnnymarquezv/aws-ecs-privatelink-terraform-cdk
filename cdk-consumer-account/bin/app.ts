#!/usr/bin/env node
import 'source-map-support/register';
import * as cdk from 'aws-cdk-lib';
import { ConnectivityStack } from '../lib/connectivity-stack';

const app = new cdk.App();

// Get context values from command line or environment
const vpcId = app.node.tryGetContext('vpcId') || process.env.VPC_ID;
const privateSubnetIds = JSON.parse(
  app.node.tryGetContext('privateSubnetIds') || process.env.PRIVATE_SUBNETS || '[]'
);

// Multi-account configuration
const environment = app.node.tryGetContext('environment') || process.env.ENVIRONMENT || 'dev';
const accountId = app.node.tryGetContext('accountId') || process.env.CDK_DEFAULT_ACCOUNT;

// Terraform-managed resources
const basePrivateSecurityGroupId = app.node.tryGetContext('basePrivateSecurityGroupId') || process.env.BASE_PRIVATE_SECURITY_GROUP_ID;
const ecsTaskExecutionRoleArn = app.node.tryGetContext('ecsTaskExecutionRoleArn') || process.env.ECS_TASK_EXECUTION_ROLE_ARN;
const ecsTaskRoleArn = app.node.tryGetContext('ecsTaskRoleArn') || process.env.ECS_TASK_ROLE_ARN;
const ecsApplicationLogGroupName = app.node.tryGetContext('ecsApplicationLogGroupName') || process.env.ECS_APPLICATION_LOG_GROUP_NAME;

// Microservice configuration
const microserviceName = app.node.tryGetContext('microserviceName') || 'consumer';
const microservicePort = parseInt(app.node.tryGetContext('microservicePort') || '80');
const microserviceImage = app.node.tryGetContext('microserviceImage') || 'nginx:alpine';

// Consumer endpoint services configuration (for consuming other microservices)
const consumerEndpointServices = app.node.tryGetContext('consumerEndpointServices') || [];

// Environment-specific configuration
const environmentConfig = {
  dev: {
    minCapacity: 1,
    maxCapacity: 3,
    instanceType: 't3.micro'
  },
  staging: {
    minCapacity: 2,
    maxCapacity: 5,
    instanceType: 't3.small'
  },
  prod: {
    minCapacity: 3,
    maxCapacity: 10,
    instanceType: 't3.medium'
  }
};

const config = environmentConfig[environment] || environmentConfig.dev;

// Validate required context
if (!vpcId) {
  throw new Error('vpcId context is required. Use -c vpcId=<vpc-id> or set VPC_ID environment variable.');
}

if (privateSubnetIds.length === 0) {
  throw new Error('privateSubnetIds context is required. Use -c privateSubnetIds=<json-array> or set PRIVATE_SUBNETS environment variable.');
}

// Validate multi-account configuration
if (!accountId) {
  throw new Error('accountId context is required. Use -c accountId=<account-id> or set CDK_DEFAULT_ACCOUNT environment variable.');
}

if (consumerEndpointServices.length === 0) {
  console.warn('Warning: No consumer endpoint services specified. This consumer will not connect to any external services.');
}

// Validate Terraform-managed resources
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

// Create the consumer connectivity stack
new ConnectivityStack(app, `${microserviceName}-consumer-stack`, {
  env: {
    account: accountId,
    region: process.env.CDK_DEFAULT_REGION,
  },
  vpcId,
  privateSubnetIds,
  microserviceName,
  microservicePort,
  microserviceImage,
  basePrivateSecurityGroupId,
  ecsTaskExecutionRoleArn,
  ecsTaskRoleArn,
  ecsApplicationLogGroupName,
  environment,
  consumerEndpointServices,
  description: `Consumer stack for ${microserviceName} with cross-account VPC endpoints`,
  tags: {
    Project: 'Multi-Account-Microservices',
    Service: microserviceName,
    Environment: environment,
    AccountId: accountId,
    AccountType: 'Consumer',
    ManagedBy: 'CDK',
  },
});

// Add CDK metadata
cdk.Tags.of(app).add('Project', 'Multi-Account-Microservices');
cdk.Tags.of(app).add('ManagedBy', 'AWS-CDK');