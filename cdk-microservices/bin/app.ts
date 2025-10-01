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

// Microservice configuration
const microserviceName = app.node.tryGetContext('microserviceName') || 'microservice';
const microservicePort = parseInt(app.node.tryGetContext('microservicePort') || '80'); // nginx default port
const microserviceImage = app.node.tryGetContext('microserviceImage') || 'nginx:alpine'; // Public image suitable for testing

// Consumer endpoint services configuration (for consuming other microservices)
const consumerEndpointServices = app.node.tryGetContext('consumerEndpointServices') || [];

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

// Create the microservices stack
new MicroservicesStack(app, `${microserviceName}-stack`, {
  env: {
    account: process.env.CDK_DEFAULT_ACCOUNT,
    region: process.env.CDK_DEFAULT_REGION,
  },
  vpcId,
  publicSubnetIds,
  privateSubnetIds,
  microserviceName,
  microservicePort,
  microserviceImage,
  consumerEndpointServices,
  description: `Microservices stack for ${microserviceName} with ECS, NLB, and VPC Endpoint Services`,
  tags: {
    Project: 'Multi-Account-Microservices',
    Service: microserviceName,
    Environment: 'production',
  },
});

// Add CDK metadata
cdk.Tags.of(app).add('Project', 'Multi-Account-Microservices');
cdk.Tags.of(app).add('ManagedBy', 'AWS-CDK');


